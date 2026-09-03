/**
 * CPMExecutionController.m — see CPMExecutionController.h for the safety model.
 *
 * Everything runs on the main queue: the touch injector delivers its phases there
 * anyway, and the whole point of the state machine is that it can be interrupted
 * between steps. Nothing here blocks.
 */
#import "CPMExecutionController.h"
#import "CPMVinylShape.h"
#import "CPMTouchInjector.h"
#import "CPMUICalibration.h"
#import "CPMIl2CppBridge.h"
#import "OverlayCommon.h"

#import <UIKit/UIKit.h>

NSString *CPMAutomationStepName(CPMAutomationStep step) {
    switch (step) {
        case CPMAutomationStepNone: return @"idle";
        case CPMAutomationStepLoadingImage: return @"loading image";
        case CPMAutomationStepDecomposingImage: return @"decomposing";
        case CPMAutomationStepPlacingLayers: return @"placing layers";
        case CPMAutomationStepPaused: return @"paused";
        case CPMAutomationStepCompleted: return @"completed";
        case CPMAutomationStepStopped: return @"stopped";
        case CPMAutomationStepFailed: return @"failed";
        case CPMAutomationStepVerifying: return @"verifying";
    }
    return @"?";
}

static NSErrorDomain const CPMExecutionControllerErrorDomain = @"CPMExecutionControllerErrorDomain";

@interface CPMExecutionStep : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) void (^body)(void (^done)(void));
+ (instancetype)step:(NSString *)label body:(void (^)(void (^done)(void)))body;
@end

@implementation CPMExecutionStep
+ (instancetype)step:(NSString *)label body:(void (^)(void (^done)(void)))body {
    CPMExecutionStep *s = [[CPMExecutionStep alloc] init];
    s.label = label;
    s.body = body;
    return s;
}
@end

@interface CPMExecutionController ()
@property (nonatomic, assign, readwrite) CPMAutomationStep currentState;
@property (nonatomic, assign, readwrite) CGFloat progress;
@property (nonatomic, assign, readwrite) NSUInteger layersPlaced;
@property (nonatomic, assign, readwrite) NSUInteger totalLayers;
@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, assign, readwrite) BOOL isPaused;
@property (nonatomic, assign, readwrite) BOOL emergencyStopActive;
@property (nonatomic, copy, readwrite) NSString *currentActivity;
@property (nonatomic, copy, readwrite) NSArray<CPMVinylShape *> *plan;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *stepLog;
@property (nonatomic, strong, readwrite) CPMShapeDecompositionResult *lastDecomposition;

@property (nonatomic, strong) NSMutableArray<NSString *> *logBuffer;
@property (nonatomic, assign) NSUInteger cursor;
@property (nonatomic, assign) CGSize workingImageSize;
@property (nonatomic, assign) CPMShapeType lastKind;
@property (nonatomic, assign) BOOL lastKindValid;
@property (nonatomic, assign) uint32_t lastPackedColor;
@property (nonatomic, assign) BOOL lastPackedColorValid;
@property (nonatomic, assign) NSInteger plannedLayerCount;
@end

@implementation CPMExecutionController

- (instancetype)init {
    self = [super init];
    if (self) {
        _maxLayers = 250;
        _touchDelayMs = 15.0;
        _respectLayerLimit = YES;
        _dryRun = NO;
        _autoSaveVinyl = YES;
        _alwaysSelectShapeType = NO;
        _layerSafetyMargin = 1;
        _requiresVerifiedCalibration = YES;
        _colorInputMode = CPMColorInputModeRGB;
        _logBuffer = [NSMutableArray array];
        _plan = @[];
        _stepLog = @[];
        _currentActivity = @"idle";
        _lastKind = (CPMShapeType)-1;
    }
    return self;
}

#pragma mark dependencies

- (CPMShapeDecomposer *)decomposer {
    if (!_decomposer) _decomposer = [CPMShapeDecomposer sharedDecomposer];
    return _decomposer;
}

- (CPMTouchInjector *)injector {
    if (!_injector) _injector = [CPMTouchInjector sharedInjector];
    return _injector;
}

- (CPMUICalibration *)calibration {
    if (!_calibration) {
        _calibration = [CPMUICalibration loadFromUserDefaults] ?: [CPMUICalibration defaultCalibration];
    }
    return _calibration;
}

- (CPMIl2CppBridge *)bridge {
    if (!_bridge) _bridge = [CPMIl2CppBridge sharedBridge];
    return _bridge;
}

#pragma mark logging / notifications

- (void)log:(NSString *)line {
    if (!line.length) return;
    [self.logBuffer addObject:line];
    if (self.logBuffer.count > 400) [self.logBuffer removeObjectsInRange:NSMakeRange(0, self.logBuffer.count - 400)];
    self.stepLog = [self.logBuffer copy];
    CPM_LOG(@"[exec] %@", line);
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controller:didLogStep:)]) {
        [delegate controller:self didLogStep:line];
    }
}

- (void)setState:(CPMAutomationStep)state activity:(NSString *)activity {
    self.currentState = state;
    self.currentActivity = activity ?: CPMAutomationStepName(state);
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controller:didChangeState:)]) {
        [delegate controller:self didChangeState:state];
    }
    if (self.stateHandler) self.stateHandler(state);
}

- (void)notifyProgress {
    NSUInteger total = MAX((NSUInteger)1, self.totalLayers);
    self.progress = (CGFloat)MIN(1.0, (double)self.layersPlaced / (double)total);
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controller:didUpdateProgress:)]) {
        [delegate controller:self didUpdateProgress:self.progress];
    }
    if (self.progressHandler) self.progressHandler(self.progress, self.layersPlaced, total);
}

- (void)fail:(NSString *)message {
    [self log:[@"ABORT: " stringByAppendingString:message]];
    self.isRunning = NO;
    self.isPaused = NO;
    [self setState:CPMAutomationStepFailed activity:message];
    NSError *error = [NSError errorWithDomain:CPMExecutionControllerErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controller:didEncounterError:)]) {
        [delegate controller:self didEncounterError:error];
    }
}

#pragma mark caps

- (NSInteger)gameLayerLimit {
    CPMEditorReadout *readout = self.bridge.lastReadout;
    if (readout && readout.bridgeAvailable && readout.maxLayers > 0) return readout.maxLayers;
    return 0;
}

- (NSInteger)gameLayerCount {
    CPMEditorReadout *readout = self.bridge.lastReadout;
    if (readout && readout.bridgeAvailable && readout.layerCount >= 0) return readout.layerCount;
    return -1;
}

- (NSInteger)effectiveLayerCap {
    NSInteger cap = MAX(1, self.maxLayers);
    if (self.respectLayerLimit) {
        NSInteger gameCap = [self gameLayerLimit];
        if (gameCap > 0) cap = MIN(cap, MAX(1, gameCap - MAX(0, self.layerSafetyMargin)));
    }
    return cap;
}

- (void)setMaxLayers:(NSInteger)limit {
    self.maxLayers = MAX(1, limit);
}

- (void)setTouchDelay:(NSTimeInterval)ms {
    self.touchDelayMs = CPMClamp(ms, 0, 500);
}

#pragma mark start / stop

- (void)startAutomationWithImage:(UIImage *)image roiRect:(CGRect)roiRect {
    NSAssert(NSThread.isMainThread, @"start the automation from the main queue");
    if (self.isRunning) {
        [self log:@"already running — ignoring the start request"];
        return;
    }
    if (!image) { [self fail:@"görsel seçilmedi"]; return; }

    self.referenceImage = image;
    self.referenceROIRect = roiRect;
    [self resetStateKeepingPlan:NO];
    self.isRunning = YES;
    [self.bridge refresh];

    if (self.requiresVerifiedCalibration && !self.calibration.isUsableForCurrentScreen) {
        self.isRunning = NO;
        [self fail:[NSString stringWithFormat:@"kalibrasyon bu ekran için güvenilmez — %@",
                    [self.calibration.validationReport stringByReplacingOccurrencesOfString:@"\n" withString:@"; "]]];
        return;
    }
    if (!self.dryRun && !self.injector.canInjectTouches) {
        [self log:[NSString stringWithFormat:@"touch injection unavailable (%@) — running as a preview",
                   self.injector.backendDescription]];
        self.dryRun = YES;
        /* A run that injects nothing is not a failure of the plan, but it is definitely not a
         * run either — report it instead of letting the progress bar lie. */
        [self notifyProgress];
    }

    NSInteger cap = [self effectiveLayerCap];
    NSInteger used = [self gameLayerCount];
    if (used >= 0) cap = MAX(0, cap - used);
    if (cap <= 0) {
        self.isRunning = NO;
        [self fail:[NSString stringWithFormat:@"boş katman yok (oyun %ld katman diyor)", (long)used]];
        return;
    }

    CPMShapeDecompositionConfig *cfg = [CPMShapeDecompositionConfig configForDetailedLogoWithMaxLayers:cap];
    cfg.roiRect = roiRect;
    [self log:[NSString stringWithFormat:@"decomposing %@ → up to %ld stickers",
               NSStringFromCGSize(image.size), (long)cap]];
    [self setState:CPMAutomationStepDecomposingImage activity:@"decomposing"];

    __weak CPMExecutionController *weakSelf = self;
    self.decomposer.progressHandler = ^(CGFloat progress, NSString *stage) {
        CPMExecutionController *s = weakSelf;
        if (!s.isRunning) return;
        s.progress = progress * 0.35;
        s.currentActivity = [NSString stringWithFormat:@"decomposing: %@", stage];
    };
    [self.decomposer decomposeImage:image withConfig:cfg completion:^(CPMShapeDecompositionResult *result, NSError *error) {
        CPMExecutionController *s = weakSelf;
        s.decomposer.progressHandler = nil;
        if (!s.isRunning) return;
        if (error || !result) {
            [s fail:[NSString stringWithFormat:@"ayrıştırma başarısız: %@",
                        error.localizedDescription ?: @"bilinmeyen hata"]];
            return;
        }
        s.lastDecomposition = result;
        [s log:result.summaryString];
        for (NSString *warning in result.warnings) [s log:[@"note: " stringByAppendingString:warning]];
        [s startWithPlan:result.shapes imageSize:result.workingSize];
    }];
}

- (void)startWithPlan:(NSArray<CPMVinylShape *> *)plan imageSize:(CGSize)imageSize {
    NSAssert(NSThread.isMainThread, @"start the automation from the main queue");
    if (plan.count == 0) { [self fail:@"plan boş — görselden şekil çıkarılamadı"]; return; }
    if (!self.isRunning) {
        self.isRunning = YES;
        [self resetStateKeepingPlan:NO];
        [self.bridge refresh];
        if (self.requiresVerifiedCalibration && !self.calibration.isUsableForCurrentScreen) {
            self.isRunning = NO;
            [self fail:@"kalibrasyon bu ekran için güvenilmez — boya alanını yeniden onaylayın"];
            return;
        }
    }
    NSInteger cap = [self effectiveLayerCap];
    NSInteger used = [self gameLayerCount];
    if (used >= 0) cap = MAX(0, cap - used);

    NSArray *sorted = [plan sortedArrayUsingComparator:^NSComparisonResult(CPMVinylShape *a, CPMVinylShape *b) {
        if (a.areaPixels > b.areaPixels) return NSOrderedAscending;
        if (a.areaPixels < b.areaPixels) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<CPMVinylShape *> *queue = [NSMutableArray array];
    [sorted enumerateObjectsUsingBlock:^(CPMVinylShape *obj, NSUInteger idx, BOOL *stop) {
        if ((NSInteger)queue.count >= cap) { *stop = YES; return; }
        [queue addObject:[obj shapeWithOrder:(NSInteger)queue.count]];
    }];
    if (queue.count == 0) { [self fail:@"tüm şekiller katman bütçesinin dışında kaldı"]; return; }

    self.plan = queue;
    self.workingImageSize = imageSize.width > 1 && imageSize.height > 1 ? imageSize : CGSizeMake(512, 512);
    self.totalLayers = queue.count;
    self.plannedLayerCount = (NSInteger)queue.count;
    self.cursor = 0;
    self.layersPlaced = 0;
    [self notifyProgress];
    [self log:[NSString stringWithFormat:@"placed will be %ld stickers on a %ld-layer budget (%0.0f×%0.0f px canvas)",
               (long)queue.count, (long)cap, self.workingImageSize.width, self.workingImageSize.height]];
    [self setState:CPMAutomationStepPlacingLayers activity:@"placing layers"];
    [self runNextShape];
}

- (void)resetStateKeepingPlan:(BOOL)keepPlan {
    self.layersPlaced = 0;
    self.totalLayers = 0;
    self.cursor = 0;
    self.progress = 0;
    self.isPaused = NO;
    self.emergencyStopActive = NO;
    self.lastKindValid = NO;
    self.lastKind = (CPMShapeType)-1;
    self.lastPackedColorValid = NO;
    self.currentActivity = @"idle";
    if (!keepPlan) {
        self.plan = @[];
        self.logBuffer = [NSMutableArray array];
        self.stepLog = @[];
    }
}

- (void)pauseAutomation {
    if (!self.isRunning) return;
    self.isPaused = YES;
    [self log:@"paused"];
    [self setState:CPMAutomationStepPaused activity:@"paused"];
}

- (void)resumeAutomation {
    if (!self.isRunning || !self.isPaused) return;
    self.isPaused = NO;
    [self log:@"resumed"];
    [self setState:CPMAutomationStepPlacingLayers activity:@"placing layers"];
    [self runNextShape];
}

- (void)stopAutomation {
    if (!self.isRunning) { [self resetStateKeepingPlan:YES]; return; }
    self.isRunning = NO;
    self.isPaused = NO;
    [self.decomposer cancelDecomposition];
    [self.injector cancelCurrentInjection];
    [self log:[NSString stringWithFormat:@"stopped after %lu of %lu layers",
               (unsigned long)self.layersPlaced, (unsigned long)self.totalLayers]];
    [self setState:CPMAutomationStepStopped activity:@"stopped"];
}

- (void)emergencyStop {
    self.emergencyStopActive = YES;
    [self.injector emergencyStop];
    [self.decomposer cancelDecomposition];
    self.isRunning = NO;
    self.isPaused = NO;
    [self log:[NSString stringWithFormat:@"EMERGENCY STOP after %lu layers", (unsigned long)self.layersPlaced]];
    [self setState:CPMAutomationStepStopped activity:@"emergency stop"];
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controllerDidRequestEmergencyStop:)]) {
        [delegate controllerDidRequestEmergencyStop:self];
    }
}

- (void)refreshFromGame {
    CPMEditorReadout *readout = [self.bridge refresh];
    if (!readout) { [self log:@"game readout unavailable"]; return; }
    if (readout.maxLayers > 0 && readout.maxLayers < self.maxLayers) {
        [self log:[NSString stringWithFormat:@"game cap is %ld layers — lowering the limit from %ld",
                   (long)readout.maxLayers, (long)self.maxLayers]];
        self.maxLayers = MAX(1, readout.maxLayers - MAX(0, self.layerSafetyMargin));
    }
    if (readout.layoutDriftCount > 0) {
        [self log:[NSString stringWithFormat:@"%ld field offset(s) corrected from the running binary",
                   (long)readout.layoutDriftCount]];
    }
    if (readout.layoutStale) {
        [self log:@"layout drift is large — re-dump the game before trusting the readout"];
    }
}

- (void)reset {
    [self resetStateKeepingPlan:NO];
    self.lastDecomposition = nil;
    [self setState:CPMAutomationStepNone activity:@"idle"];
}

#pragma mark the loop

- (void)runNextShape {
    if (self.emergencyStopActive) return;
    if (!self.isRunning) return;
    if (self.isPaused) {
        __weak CPMExecutionController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [weakSelf runNextShape]; });
        return;
    }
    NSArray<CPMVinylShape *> *plan = self.plan;
    if (self.cursor >= plan.count) { [self finishRun]; return; }

    CPMVinylShape *shape = plan[self.cursor];
    NSUInteger index = self.cursor;
    NSArray<CPMExecutionStep *> *steps = [self stepsForShape:shape index:index];
    [self log:[NSString stringWithFormat:@"layer %lu/%lu — %@ %@", (unsigned long)(index + 1),
               (unsigned long)plan.count, CPMShapeTypeName(shape.shapeType),
               [self descriptionForShape:shape]]];
    __weak CPMExecutionController *weakSelf = self;
    [self runSteps:steps completion:^{
        CPMExecutionController *s = weakSelf;
        if (!s || s.emergencyStopActive) return;
        s.cursor = index + 1;
        s.layersPlaced = MIN(s.totalLayers, s.layersPlaced + 1);
        [s notifyProgress];
        id<CPMExecutionControllerDelegate> delegate = s.delegate;
        if ([delegate respondsToSelector:@selector(controller:didPlaceLayer:total:)]) {
            [delegate controller:s didPlaceLayer:index total:s.totalLayers];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [s runNextShape]; });
    }];
}

- (void)finishRun {
    if (!self.autoSaveVinyl) {
        [self completeWithActivity:@"done (no save tap)"];
        return;
    }
    CPMUIElementAnchor *confirm = [self.calibration anchorForType:CPMUIElementTypeConfirmButton];
    if (!confirm || !confirm.isValid) {
        [self log:@"no Confirm anchor — leaving the vinyl open for the player"];
        [self completeWithActivity:@"done (not saved)"];
        return;
    }
    [self log:@"tapping Confirm"];
    __weak CPMExecutionController *weakSelf = self;
    [self tapAt:[self screenPointForAnchor:confirm] completion:^{
        [weakSelf completeWithActivity:@"done"];
    }];
}

- (void)completeWithActivity:(NSString *)activity {
    self.isRunning = NO;
    self.progress = 1.0;
    self.currentActivity = activity ?: @"completed";
    [self setState:CPMAutomationStepCompleted activity:activity];
    id<CPMExecutionControllerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(controllerDidFinish:)]) {
        [delegate controllerDidFinish:self];
    }
}

#pragma mark step construction

- (NSString *)descriptionForShape:(CPMVinylShape *)shape {
    return [NSString stringWithFormat:@"(%0.0f,%0.0f) %0.0f×%0.0f rot %0.0f° rgb(%0.0f,%0.0f,%0.0f)",
            shape.position.x, shape.position.y, shape.scale.width, shape.scale.height,
            shape.rotationDegrees, shape.redComponent * 255.0, shape.greenComponent * 255.0,
            shape.blueComponent * 255.0];
}

- (NSArray<CPMExecutionStep *> *)stepsForShape:(CPMVinylShape *)shape index:(NSUInteger)index {
    NSMutableArray<CPMExecutionStep *> *steps = [NSMutableArray array];
    CPMUICalibration *cal = self.calibration;

    /* 1. shape kind, when it differs from the one the editor is on */
    BOOL needKind = self.alwaysSelectShapeType || !self.lastKindValid || self.lastKind != shape.shapeType;
    if (needKind) {
        CPMUIElementAnchor *selector = [cal anchorForType:CPMUIElementTypeShapeSelector];
        if (selector && selector.isValid) {
            CGPoint row = [self shapeSelectorPointForKind:shape.shapeType anchor:selector];
            __weak CPMExecutionController *weakSelf = self;
            [steps addObject:[CPMExecutionStep step:[NSString stringWithFormat:@"select %@",
                    CPMShapeTypeName(shape.shapeType)]
                                               body:^(void (^done)(void)) {
                [weakSelf tapAt:[weakSelf screenPointForReferencePoint:row] completion:^{
                    weakSelf.lastKind = shape.shapeType;
                    weakSelf.lastKindValid = YES;
                    done();
                }];
            }]];
        } else {
            [self log:@"no Shape Selector anchor — the sticker keeps whatever shape the editor has"];
        }
    }

    /* 2. create the sticker */
    CPMUIElementAnchor *addShape = [cal anchorForType:CPMUIElementTypeAddShape];
    if (addShape && addShape.isValid) {
        __weak CPMExecutionController *weakSelf = self;
        [steps addObject:[CPMExecutionStep step:@"create sticker" body:^(void (^done)(void)) {
            [weakSelf tapAt:[weakSelf screenPointForAnchor:addShape] completion:^{ done(); }];
        }]];
    }

    /* 3. put it where the picture says */
    CGPoint target = [cal mappedPositionFromImagePosition:shape.position imageSize:self.workingImageSize];
    {
        __weak CPMExecutionController *weakSelf = self;
        [steps addObject:[CPMExecutionStep step:[NSString stringWithFormat:@"place at (%0.0f,%0.0f)",
                                                 target.x, target.y]
                                           body:^(void (^done)(void)) {
            [weakSelf tapAt:target completion:^{ done(); }];
        }]];
    }

    /* 4. paint it (only when the colour actually changes) */
    uint32_t packed = shape.packedColorRGBA & 0xFFFFFF00u;
    if (!self.lastPackedColorValid || self.lastPackedColor != packed) {
        NSArray *colorSteps = [self colorStepsForShape:shape];
        if (colorSteps) {
            __weak CPMExecutionController *weakSelf = self;
            [steps addObjectsFromArray:colorSteps];
            [steps addObject:[CPMExecutionStep step:@"remember colour" body:^(void (^done)(void)) {
                weakSelf.lastPackedColor = packed;
                weakSelf.lastPackedColorValid = YES;
                done();
            }]];
        }
    }

    /* 5. size, then rotation */
    [steps addObjectsFromArray:[self sizeAndRotationStepsForShape:shape]];

    /* 6. verify with the readout when the game is readable */
    {
        __weak CPMExecutionController *weakSelf = self;
        [steps addObject:[CPMExecutionStep step:@"verify" body:^(void (^done)(void)) {
            CPMExecutionController *s = weakSelf;
            if (!s) { done(); return; }
            CPMEditorReadout *readout = [s.bridge refresh];
            if (readout.bridgeAvailable && readout.editorLoaded && readout.layerCount >= 0) {
                NSInteger expected = (NSInteger)index + 1;
                if (readout.layerCount < expected) {
                    [s log:[NSString stringWithFormat:@"game has %ld layers, expected %ld — the tap may have missed",
                            (long)readout.layerCount, (long)expected]];
                }
                if (readout.layoutStale) {
                    [s fail:@"layout drift is large — re-dump/re-calibrate before continuing"];
                }
            }
            done();
        }]];
    }
    return steps;
}

/// The colour picker's three sliders. `value 0` is tapped as a "home" position first so
/// the drag is deterministic even though we cannot read the slider's current value.
- (NSArray<CPMExecutionStep *> *)colorStepsForShape:(CPMVinylShape *)shape {
    CPMUICalibration *cal = self.calibration;
    CPMUIElementAnchor *picker = [cal anchorForType:CPMUIElementTypeColorPicker];
    CPMUIElementAnchor *red = [cal anchorForType:CPMUIElementTypeRedSlider];
    CPMUIElementAnchor *green = [cal anchorForType:CPMUIElementTypeGreenSlider];
    CPMUIElementAnchor *blue = [cal anchorForType:CPMUIElementTypeBlueSlider];
    if (!picker.isValid || !red.isValid || !green.isValid || !blue.isValid) return nil;

    CGFloat r = shape.redComponent, g = shape.greenComponent, b = shape.blueComponent;
    if (self.colorInputMode == CPMColorInputModeHSV) {
        CGFloat h = 0, s = 0, v = 0, a = 0;
        if ([shape.color getHue:&h saturation:&s brightness:&v alpha:&a]) {
            r = h; g = s; b = v;
        }
    }
    NSMutableArray<CPMExecutionStep *> *steps = [NSMutableArray array];
    __weak CPMExecutionController *weakSelf = self;
    [steps addObject:[CPMExecutionStep step:@"open colour picker" body:^(void (^done)(void)) {
        [weakSelf tapAt:[weakSelf screenPointForAnchor:picker] completion:^{ done(); }];
    }]];
    [steps addObject:[self sliderStepNamed:@"red" anchor:red value:r]];
    [steps addObject:[self sliderStepNamed:@"green" anchor:green value:g]];
    [steps addObject:[self sliderStepNamed:@"blue" anchor:blue value:b]];
    [steps addObject:[CPMExecutionStep step:@"close colour picker" body:^(void (^done)(void)) {
        [weakSelf tapAt:[weakSelf screenPointForAnchor:picker] completion:^{ done(); }];
    }]];
    return steps;
}

- (CPMExecutionStep *)sliderStepNamed:(NSString *)name anchor:(CPMUIElementAnchor *)anchor value:(CGFloat)value {
    __weak CPMExecutionController *weakSelf = self;
    CGFloat v = CPMClamp(value, 0, 1);
    return [CPMExecutionStep step:[NSString stringWithFormat:@"%@ → %0.0f%%", name, v * 100.0]
                             body:^(void (^done)(void)) {
        [weakSelf setSlider:anchor toValue:v completion:done];
    }];
}

- (NSArray<CPMExecutionStep *> *)sizeAndRotationStepsForShape:(CPMVinylShape *)shape {
    CPMUICalibration *cal = self.calibration;
    NSMutableArray<CPMExecutionStep *> *steps = [NSMutableArray array];

    CPMUIElementAnchor *scale = [cal anchorForType:CPMUIElementTypeScaleSlider];
    if (scale.isValid) {
        /* The slider is 0…1 of the sticker's own max size; map the canvas-relative
         * extent onto it so a sticker covering the canvas lands at ~1. */
        CGFloat canvasW = MAX(1.0, self.workingImageSize.width);
        CGFloat ratio = CPMClamp(MAX(shape.scale.width, shape.scale.height) / canvasW, 0.02, 1.0);
        [steps addObject:[self sliderStepNamed:@"scale" anchor:scale value:ratio]];
    }
    CPMUIElementAnchor *rotate = [cal anchorForType:CPMUIElementTypeRotateSlider];
    if (rotate.isValid && fabs(shape.rotationDegrees) > 3.0) {
        [steps addObject:[self sliderStepNamed:@"rotate" anchor:rotate value:CPMClamp(shape.rotationDegrees / 360.0, 0, 1)]];
    }
    return steps;
}

- (void)runSteps:(NSArray<CPMExecutionStep *> *)steps completion:(void (^)(void))completion {
    if (steps.count == 0) { if (completion) completion(); return; }
    __weak CPMExecutionController *weakSelf = self;
    void (^__block run)(NSUInteger) = nil;
    run = ^(NSUInteger i) {
        CPMExecutionController *s = weakSelf;
        if (!s || s.emergencyStopActive || !s.isRunning) { run = nil; return; }
        if (i >= steps.count) { run = nil; if (completion) completion(); return; }
        CPMExecutionStep *step = steps[i];
        if (s.dryRun) {
            [s log:[NSString stringWithFormat:@"  · %@ (preview)", step.label]];
            dispatch_async(dispatch_get_main_queue(), ^{ run(i + 1); });
            return;
        }
        s.currentActivity = step.label;
        NSTimeInterval settle = MAX(0.0, s.touchDelayMs / 1000.0);
        void (^done)(void) = ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(settle * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                CPMExecutionController *inner = weakSelf;
                if (!inner || inner.emergencyStopActive || !inner.isRunning) { run = nil; return; }
                run(i + 1);
            });
        };
        /* Watchdog: a step body that forgets to call done() used to freeze the whole run in
         * silence (the panel just stops moving). Ten seconds is longer than any legitimate
         * settle delay plus a touch, and shorter than "the user gave up". */
        __block BOOL settled = NO;
        void (^finish)(void) = ^{
            if (settled) return;
            settled = YES;
            done();
        };
        NSTimeInterval timeout = MAX(4.0, 2.0 + (MAX(0.0, s.touchDelayMs / 1000.0) * 4.0));
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (settled) return;
            settled = YES;
            [s log:[NSString stringWithFormat:@"step timed out after %0.0fs: %@ — moving on",
                        timeout, step.label]];
            if (i >= steps.count) { if (completion) completion(); return; }
            run(i + 1);
        });
        if (step.body) step.body(finish);
        else finish();
    };
    dispatch_async(dispatch_get_main_queue(), ^{ run(0); });
}

#pragma mark touch primitives

- (void)tapAt:(CGPoint)screenPoint completion:(void (^)(void))completion {
    if (self.dryRun) { if (completion) completion(); return; }
    [self.injector synthesizeTapAt:screenPoint completion:^(__unused BOOL ok) {
        if (completion) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0.0, self.touchDelayMs / 1000.0) * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), completion);
        }
    }];
}

/// Home at 0 first, then drag to the value: NGUI sliders follow the finger, so this is
/// deterministic without reading the current value back.
- (void)setSlider:(CPMUIElementAnchor *)anchor toValue:(CGFloat)value completion:(void (^)(void))completion {
    CPMUICalibration *cal = self.calibration;
    CGPoint home = [cal screenPointForReferencePoint:[anchor referencePointForValue:0]];
    CGPoint target = [cal screenPointForReferencePoint:[anchor referencePointForValue:value]];
    if (self.dryRun) {
        [self log:[NSString stringWithFormat:@"  · slider %@ home → %0.2f (preview)",
                   CPMUIElementTypeName(anchor.elementType), value]];
        if (completion) completion();
        return;
    }
    __weak CPMExecutionController *weakSelf = self;
    CPMTouchSequence *homeSeq = [CPMTouchSequence dragSequenceFrom:home to:home];
    [self.injector executeSequence:homeSeq completion:^(__unused BOOL first) {
        CPMTouchSequence *seq = [CPMTouchSequence dragSequenceFrom:home to:target];
        [weakSelf.injector executeSequence:seq completion:^(__unused BOOL ok) {
            if (completion) completion();
        }];
    }];
}

- (CGPoint)screenPointForAnchor:(CPMUIElementAnchor *)anchor {
    return [self screenPointForReferencePoint:anchor.center];
}

- (CGPoint)screenPointForReferencePoint:(CGPoint)p {
    return [self.calibration screenPointForReferencePoint:p];
}

/// The shape selector is a row of cells inside one widget; the game orders them
/// square / circle / triangle / text, so the index follows CPMShapeType.
- (CGPoint)shapeSelectorPointForKind:(CPMShapeType)kind anchor:(CPMUIElementAnchor *)anchor {
    CGRect frame = anchor.referenceFrame;
    NSInteger cells = 4;
    NSInteger idx = MIN((NSInteger)kind, cells - 1);
    if (frame.size.height > frame.size.width * 1.6) {   // vertical list
        CGFloat cell = frame.size.height / (CGFloat)cells;
        return CGPointMake(CGRectGetMidX(frame), CGRectGetMinY(frame) + cell * ((CGFloat)idx + 0.5));
    }
    CGFloat cell = frame.size.width / (CGFloat)cells;
    return CGPointMake(CGRectGetMinX(frame) + cell * ((CGFloat)idx + 0.5), CGRectGetMidY(frame));
}

#pragma mark previews / status

- (NSArray<NSString *> *)planPreviewForShapes:(NSArray<CPMVinylShape *> *)shapes imageSize:(CGSize)imageSize {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    CGSize size = imageSize.width > 1 ? imageSize : CGSizeMake(512, 512);
    NSInteger cap = [self effectiveLayerCap];
    NSUInteger i = 0;
    for (CPMVinylShape *shape in shapes) {
        if ((NSInteger)out.count >= cap) { [out addObject:@"… cut by the layer budget"]; break; }
        CGPoint p = [self.calibration mappedPositionFromImagePosition:shape.position imageSize:size];
        [out addObject:[NSString stringWithFormat:@"%02lu  %@ (%0.0f,%0.0f) → screen (%0.0f,%0.0f) %@",
                        (unsigned long)(i + 1), CPMShapeTypeName(shape.shapeType),
                        shape.position.x, shape.position.y, p.x, p.y,
                        [self descriptionForShape:shape]]];
        i++;
    }
    return out;
}

- (NSString *)statusDescription {
    CPMEditorReadout *readout = self.bridge.lastReadout;
    NSString *gameInfo = readout && readout.bridgeAvailable ? readout.summaryString : @"game readout unavailable";
    return [NSString stringWithFormat:@"%@ — %lu/%lu layers, cap %ld (%@)",
            self.currentActivity ?: CPMAutomationStepName(self.currentState),
            (unsigned long)self.layersPlaced, (unsigned long)self.totalLayers,
            (long)[self effectiveLayerCap], gameInfo];
}

@end
