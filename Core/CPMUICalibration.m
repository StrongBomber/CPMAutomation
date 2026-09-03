/**
 * CPMUICalibration.m — see CPMUICalibration.h.
 */
#import "CPMUICalibration.h"
#import "CPMAnchorsDefault.h"
#import "OverlayCommon.h"

NSString *CPMUIElementTypeName(CPMUIElementType type) {
    for (NSUInteger i = 0; i < CPM_ANCHOR_RECORD_COUNT; i++) {
        if (CPMUIAnchorRecords[i].type == (NSInteger)type) {
            return [NSString stringWithUTF8String:CPMUIAnchorRecords[i].name];
        }
    }
    switch (type) {
        case CPMUIElementTypeAddShape: return @"Add Shape";
        case CPMUIElementTypeShapeSelector: return @"Shape Selector";
        case CPMUIElementTypeColorPicker: return @"Color Picker";
        case CPMUIElementTypeRedSlider: return @"Red Slider";
        case CPMUIElementTypeGreenSlider: return @"Green Slider";
        case CPMUIElementTypeBlueSlider: return @"Blue Slider";
        case CPMUIElementTypeScaleSlider: return @"Scale Slider";
        case CPMUIElementTypeRotateSlider: return @"Rotate Slider";
        case CPMUIElementTypeMoveJoystick: return @"Move Joystick";
        case CPMUIElementTypeConfirmButton: return @"Confirm";
        case CPMUIElementTypeCancelButton: return @"Cancel";
        case CPMUIElementTypeLayerListView: return @"Layer List";
        case CPMUIElementTypeZoomControl: return @"Zoom";
        case CPMUIElementTypeCount: break;
    }
    return @"Unknown";
}

static BOOL CPMUITypeIsSlider(CPMUIElementType type) {
    return type == CPMUIElementTypeRedSlider || type == CPMUIElementTypeGreenSlider ||
           type == CPMUIElementTypeBlueSlider || type == CPMUIElementTypeScaleSlider ||
           type == CPMUIElementTypeRotateSlider || type == CPMUIElementTypeZoomControl;
}

#pragma mark - anchor

@implementation CPMUIElementAnchor

- (instancetype)initWithType:(CPMUIElementType)type center:(CGPoint)c size:(CGSize)s {
    self = [super init];
    if (self) {
        _elementType = type;
        _center = c;
        _size = s;
        _isValid = YES;
        if (CPMUITypeIsSlider(type)) {
            _sliderMinX = c.x - s.width * 0.5;
            _sliderMaxX = c.x + s.width * 0.5;
            _sliderMinY = c.y;
            _sliderMaxY = c.y;
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithType:CPMUIElementTypeAddShape center:CGPointZero size:CGSizeMake(44, 44)];
}

- (BOOL)isSlider { return CPMUITypeIsSlider(_elementType); }

- (CGRect)referenceFrame {
    return CGRectMake(_center.x - _size.width * 0.5, _center.y - _size.height * 0.5, _size.width, _size.height);
}

- (BOOL)containsReferencePoint:(CGPoint)point {
    return CGRectContainsPoint(self.referenceFrame, point);
}

- (CGPoint)referencePointForValue:(CGFloat)value {
    if (!self.isSlider) return _center;
    CGFloat t = CPMClamp(value, 0, 1);
    if (_inverted) t = 1.0 - t;
    return CGPointMake(_sliderMinX + (_sliderMaxX - _sliderMinX) * t,
                       _sliderMinY + (_sliderMaxY - _sliderMinY) * t);
}

- (CGFloat)valueForReferencePoint:(CGPoint)point {
    if (!self.isSlider) return 0;
    CGFloat along = (_sliderMaxX - _sliderMinX) ?: 1.0;
    CGFloat t = (point.x - _sliderMinX) / along;
    if (fabs(along) < 1.0) {                       /* vertical track */
        CGFloat alongY = (_sliderMaxY - _sliderMinY) ?: 1.0;
        t = (point.y - _sliderMinY) / alongY;
    }
    t = CPMClamp(t, 0, 1);
    return _inverted ? 1.0 - t : t;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    CPMUIElementAnchor *c = [[CPMUIElementAnchor alloc] initWithType:_elementType center:_center size:_size];
    c.sliderMinX = _sliderMinX; c.sliderMaxX = _sliderMaxX;
    c.sliderMinY = _sliderMinY; c.sliderMaxY = _sliderMaxY;
    c.inverted = _inverted;
    c.displayName = _displayName;
    c.isValid = _isValid;
    return c;
}

- (NSDictionary<NSString *, id> *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"type"] = @((NSInteger)self.elementType);
    d[@"center"] = @{@"x": @(_center.x), @"y": @(_center.y)};
    d[@"size"] = @{@"width": @(_size.width), @"height": @(_size.height)};
    if (_displayName.length) d[@"displayName"] = _displayName;
    d[@"isValid"] = @(_isValid);
    if (self.isSlider) {
        d[@"sliderMinX"] = @(_sliderMinX);
        d[@"sliderMaxX"] = @(_sliderMaxX);
        d[@"sliderMinY"] = @(_sliderMinY);
        d[@"sliderMaxY"] = @(_sliderMaxY);
        d[@"inverted"] = @(_inverted);
    }
    return d;
}

+ (instancetype)anchorFromDictionary:(NSDictionary<NSString *, id> *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    NSInteger type = [dict[@"type"] integerValue];
    if (type < CPMUIElementTypeAddShape || type >= CPMUIElementTypeCount) return nil;
    NSDictionary *c = dict[@"center"];
    NSDictionary *s = dict[@"size"];
    if (![c isKindOfClass:NSDictionary.class] || ![s isKindOfClass:NSDictionary.class]) return nil;
    CPMUIElementAnchor *anchor = [[self alloc] initWithType:(CPMUIElementType)type
                                                      center:CGPointMake([c[@"x"] doubleValue], [c[@"y"] doubleValue])
                                                        size:CGSizeMake([s[@"width"] doubleValue], [s[@"height"] doubleValue])];
    anchor.displayName = [dict[@"displayName"] isKindOfClass:NSString.class] ? dict[@"displayName"] : nil;
    NSNumber *v = dict[@"isValid"];
    if ([v isKindOfClass:NSNumber.class]) anchor.isValid = v.boolValue;
    v = dict[@"inverted"];
    if ([v isKindOfClass:NSNumber.class]) anchor.inverted = v.boolValue;
    v = dict[@"sliderMinX"]; if ([v isKindOfClass:NSNumber.class]) anchor.sliderMinX = v.doubleValue;
    v = dict[@"sliderMaxX"]; if ([v isKindOfClass:NSNumber.class]) anchor.sliderMaxX = v.doubleValue;
    v = dict[@"sliderMinY"]; if ([v isKindOfClass:NSNumber.class]) anchor.sliderMinY = v.doubleValue;
    v = dict[@"sliderMaxY"]; if ([v isKindOfClass:NSNumber.class]) anchor.sliderMaxY = v.doubleValue;
    return anchor;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ @(%0.0f,%0.0f) %0.0fx%0.0f%@",
            CPMUIElementTypeName(self.elementType), _center.x, _center.y, _size.width, _size.height,
            self.isSlider ? [NSString stringWithFormat:@" track %0.0f…%0.0f", _sliderMinX, _sliderMaxX] : @""];
}

@end

#pragma mark - calibration

@interface CPMUICalibration ()
- (void)rebuildDerivedValues;
- (void)loadCompiledAnchorsForLandscape:(BOOL)wantLandscape;
- (void)deriveDefaultCanvasRect;
- (CGRect)effectiveCanvasRect;
- (NSString *)_calibrationId_safe;
@property (nonatomic, copy, readwrite) NSString *calibrationID;
@property (nonatomic, assign, readwrite) CGSize referenceScreenSize;
@property (nonatomic, assign, readwrite) CGSize screenSize;
@property (nonatomic, assign, readwrite) CGFloat scaleFactor;
@property (nonatomic, assign, readwrite) BOOL isLandscape;
@property (nonatomic, assign, readwrite) BOOL referenceSpaceRotated;
@property (nonatomic, assign) CGFloat fitScaleX;
@property (nonatomic, assign) CGFloat fitScaleY;
@property (nonatomic, assign) CGFloat fitOffsetX;
@property (nonatomic, assign) CGFloat fitOffsetY;
- (void)ensureFit;
@property (nonatomic, assign) CGFloat fitMidScaleX;
@property (nonatomic, assign) CGFloat fitMidScaleY;
@property (nonatomic, assign) CGFloat fitMarginX;
@property (nonatomic, assign) CGFloat fitMarginY;
@property (nonatomic, copy, readwrite) NSArray<CPMUIElementAnchor *> *anchors;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, CPMUIElementAnchor *> *anchorsByType;
@end

@implementation CPMUICalibration

static NSString *const kCPMCalibrationDefaultsKey = @"cpm_ui_calibration_json";
static NSString *const kCPMCalibrationIDKey = @"cpm_ui_calibration_id";

+ (CGSize)currentScreenSize {
    /* UIScreen.mainScreen.bounds never rotates: on an iPhone it keeps reporting the
     * portrait frame even while a landscape game owns the screen. The window scene's
     * coordinate space is the number that actually describes what the user sees. */
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            CGSize size = ws.coordinateSpace.bounds.size;
            if (size.width > 1 && size.height > 1) return size;
        }
    }
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    CGSize size = window.bounds.size;
    if (size.width > 1 && size.height > 1) return size;
    return UIScreen.mainScreen.bounds.size;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _anchorsByType = [NSMutableDictionary dictionary];
        _mappingMode = CPMUIMappingModeAnchored;   /* see -ensureFit */
        _screenSize = [self.class currentScreenSize];
        _calibrationID = CPM_ANCHOR_CALIBRATION_ID;
        [self loadCompiledAnchorsForLandscape:(_screenSize.width > _screenSize.height)];
        [self rebuildDerivedValues];
    }
    return self;
}

/* The compiled-in table is measured on the game's landscape editor. Rotating the phone does
 * not rotate CPM's editor, so the only honest thing to do when the window's orientation
 * differs from the table's is to re-derive the reference space from the table (a 90° rotation
 * of every rect) — never to stretch a landscape layout over a portrait screen.
 *
 * Re-deriving (instead of mutating) keeps the operation idempotent: rotate twice and you are
 * back at the table, not at a 180° version of it. */
- (void)loadCompiledAnchorsForLandscape:(BOOL)wantLandscape {
    BOOL tableLandscape = CPM_ANCHOR_IS_LANDSCAPE != 0;
    BOOL rotate = (wantLandscape != tableLandscape);
    CGFloat refW = CPM_ANCHOR_REFERENCE_WIDTH, refH = CPM_ANCHOR_REFERENCE_HEIGHT;
    _referenceScreenSize = rotate ? CGSizeMake(refH, refW) : CGSizeMake(refW, refH);
    _isLandscape = wantLandscape;
    _referenceSpaceRotated = rotate;
    [_anchorsByType removeAllObjects];
    for (NSUInteger i = 0; i < CPM_ANCHOR_RECORD_COUNT; i++) {
        const CPMUIAnchorRecord *r = &CPMUIAnchorRecords[i];
        CGRect f = CGRectMake(r->centerX - r->width * 0.5, r->centerY - r->height * 0.5,
                              r->width, r->height);
        CGPoint lo = CGPointMake(r->sliderMinX, r->sliderMinY);
        CGPoint hi = CGPointMake(r->sliderMaxX, r->sliderMaxY);
        if (rotate) {
            /* (x, y) in a W×H landscape box -> (H - maxY, x) in the H×W portrait box. */
            CGRect t = CGRectMake(refH - CGRectGetMaxY(f), CGRectGetMinX(f), f.size.height, f.size.width);
            f = t;
            lo = CGPointMake(refH - lo.y, lo.x);
            hi = CGPointMake(refH - hi.y, hi.x);
        }
        CPMUIElementAnchor *a = [[CPMUIElementAnchor alloc] initWithType:(CPMUIElementType)r->type
                                                                  center:CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f))
                                                                    size:f.size];
        a.sliderMinX = lo.x; a.sliderMaxX = hi.x;
        a.sliderMinY = lo.y; a.sliderMaxY = hi.y;
        a.displayName = [NSString stringWithUTF8String:r->name];
        a.isValid = r->isValid;
        _anchorsByType[@(r->type)] = a;
    }
    [self deriveDefaultCanvasRect];
}

/* The painted surface, in reference space, mapped onto the current screen. Derived from the
 * same table as the anchors so a rotated profile still gets a sane starting canvas — the user
 * confirming the paint area only ever has to *adjust* it. */
- (void)deriveDefaultCanvasRect {
#if CPM_ANCHOR_HAS_CANVAS_RECT
    CGRect ref = CPM_ANCHOR_CANVAS_RECT;
    if (_referenceSpaceRotated) {
        CGFloat tableH = CPM_ANCHOR_REFERENCE_HEIGHT;
        ref = CGRectMake(tableH - CGRectGetMaxY(ref), CGRectGetMinX(ref),
                         ref.size.height, ref.size.width);
    }
    _canvasRect = [self screenRectForReferenceRect:ref];
#else
    _canvasRect = CGRectNull;
#endif
}

- (BOOL)refreshForWindowSize:(CGSize)size {
    if (size.width < 1 || size.height < 1) return NO;
    BOOL wantLandscape = size.width > size.height;
    BOOL changed = fabs(size.width - _screenSize.width) > 0.5 || fabs(size.height - _screenSize.height) > 0.5;
    if (wantLandscape != _isLandscape) {
        _screenSize = size;   /* the re-derived canvas has to land on the new geometry */
        if ([_calibrationID isEqualToString:CPM_ANCHOR_CALIBRATION_ID]) {
            [self loadCompiledAnchorsForLandscape:wantLandscape];
        } else {
            _isLandscape = wantLandscape;
            _canvasRect = CGRectNull;
            CPM_LOG(@"calibration '%@' is not the compiled-in table: orientation changed, "
                    @"anchors need recalibration", _calibrationID);
        }
        /* Whatever was verified belongs to the other orientation now. */
        _userVerified = NO;
        changed = YES;
    }
    if (!changed) return NO;
    _screenSize = size;
    [self rebuildDerivedValues];
    return YES;
}

- (void)rebuildDerivedValues {
    _referenceScreenSize = CGSizeMake(MAX(1.0, _referenceScreenSize.width), MAX(1.0, _referenceScreenSize.height));
    _scaleFactor = _screenSize.width > 0 && _screenSize.height > 0
        ? MAX(_referenceScreenSize.width / MAX(1.0, _screenSize.width),
              _referenceScreenSize.height / MAX(1.0, _screenSize.height))
        : 1.0;
    NSMutableArray *all = [NSMutableArray arrayWithCapacity:_anchorsByType.count];
    for (CPMUIElementType t = 0; t < CPMUIElementTypeCount; t++) {
        CPMUIElementAnchor *a = _anchorsByType[@((NSInteger)t)];
        if (a) [all addObject:a];
    }
    _anchors = [all copy];
}

+ (instancetype)defaultCalibration {
    return [self defaultCalibrationForScreenSize:[self currentScreenSize]];
}

+ (instancetype)defaultCalibrationForScreenSize:(CGSize)screenSize {
    CPMUICalibration *cal = [[CPMUICalibration alloc] init];
    cal.screenSize = screenSize.width > 0 && screenSize.height > 0
        ? screenSize : [self currentScreenSize];
    cal.calibrationID = CPM_ANCHOR_CALIBRATION_ID;
    [cal loadCompiledAnchorsForLandscape:(cal.screenSize.width > cal.screenSize.height)];
    [cal rebuildDerivedValues];
    return cal;
}

+ (instancetype)calibrationFromJSON:(NSDictionary<NSString *, id> *)json {
    CPMUICalibration *cal = [[CPMUICalibration alloc] init];
    if (![json isKindOfClass:NSDictionary.class]) return cal;
    NSDictionary *ref = json[@"referenceScreenSize"] ?: json[@"screenSize"];
    if ([ref isKindOfClass:NSDictionary.class]) {
        CGFloat w = [ref[@"width"] doubleValue], h = [ref[@"height"] doubleValue];
        if (w > 1 && h > 1) cal.referenceScreenSize = CGSizeMake(w, h);
    }
    NSString *ident = json[@"calibrationID"];
    if ([ident isKindOfClass:NSString.class] && ident.length) cal.calibrationID = ident;
    NSNumber *land = json[@"isLandscape"];
    if ([land isKindOfClass:NSNumber.class]) cal.isLandscape = land.boolValue;
    NSNumber *mode = json[@"mappingMode"];
    if ([mode isKindOfClass:NSNumber.class]) cal.mappingMode = (CPMUIMappingMode)mode.integerValue;
    NSNumber *rot = json[@"referenceSpaceRotated"];
    if ([rot isKindOfClass:NSNumber.class]) cal.referenceSpaceRotated = rot.boolValue;
    NSNumber *verified = json[@"userVerified"];
    cal.userVerified = [verified isKindOfClass:NSNumber.class] ? verified.boolValue : YES;
    NSArray *anchors = json[@"anchors"];
    if ([anchors isKindOfClass:NSArray.class]) {
        [cal.anchorsByType removeAllObjects];
        for (NSDictionary *d in anchors) {
            CPMUIElementAnchor *a = [CPMUIElementAnchor anchorFromDictionary:d];
            if (a) cal.anchorsByType[@((NSInteger)a.elementType)] = a;
        }
    }
    NSArray *canvas = json[@"canvasRect"];
    if ([canvas isKindOfClass:NSArray.class] && canvas.count == 4) {
        cal.canvasRect = CGRectMake([canvas[0] doubleValue], [canvas[1] doubleValue],
                                    [canvas[2] doubleValue], [canvas[3] doubleValue]);
    }
    [cal rebuildDerivedValues];
    return cal;
}

- (NSDictionary<NSString *, id> *)toJSON {
    NSMutableArray *anchors = [NSMutableArray arrayWithCapacity:self.anchors.count];
    for (CPMUIElementAnchor *a in self.anchors) [anchors addObject:[a toDictionary]];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"calibrationID"] = _calibrationID ?: @"unknown";
    d[@"referenceScreenSize"] = @{@"width": @(_referenceScreenSize.width), @"height": @(_referenceScreenSize.height)};
    d[@"screenSize"] = @{@"width": @(_screenSize.width), @"height": @(_screenSize.height)};
    d[@"isLandscape"] = @(_isLandscape);
    d[@"mappingMode"] = @(_mappingMode);
    d[@"referenceSpaceRotated"] = @(_referenceSpaceRotated);
    d[@"userVerified"] = @(_userVerified);
    d[@"anchors"] = anchors;
    d[@"anchorSource"] = [NSString stringWithFormat:@"%@ / %@", @"cpm_ui_anchors.json",
                                                    CPM_ANCHOR_SOURCE_SHA256];
    if (!CGRectIsNull(_canvasRect)) {
        d[@"canvasRect"] = @[@(_canvasRect.origin.x), @(_canvasRect.origin.y),
                             @(_canvasRect.size.width), @(_canvasRect.size.height)];
    }
    return d;
}

- (nullable CPMUIElementAnchor *)anchorForType:(CPMUIElementType)type {
    return _anchorsByType[@((NSInteger)type)];
}

- (void)setAnchor:(CPMUIElementAnchor *)anchor forType:(CPMUIElementType)type {
    if (!anchor) { [_anchorsByType removeObjectForKey:@((NSInteger)type)]; }
    else {
        anchor.elementType = type;
        _anchorsByType[@((NSInteger)type)] = anchor;
    }
    [self rebuildDerivedValues];
}

- (void)shiftAllAnchorsBy:(CGPoint)delta {
    for (CPMUIElementAnchor *a in _anchorsByType.allValues) {
        a.center = CGPointMake(a.center.x + delta.x, a.center.y + delta.y);
        if (a.isSlider) {
            a.sliderMinX += delta.x; a.sliderMaxX += delta.x;
            a.sliderMinY += delta.y; a.sliderMaxY += delta.y;
        }
    }
    [self rebuildDerivedValues];
}

- (void)shiftAnchorForType:(CPMUIElementType)type by:(CGPoint)delta {
    CPMUIElementAnchor *a = [self anchorForType:type];
    if (!a) return;
    a.center = CGPointMake(a.center.x + delta.x, a.center.y + delta.y);
    if (a.isSlider) {
        a.sliderMinX += delta.x; a.sliderMaxX += delta.x;
        a.sliderMinY += delta.y; a.sliderMaxY += delta.y;
    }
    [self rebuildDerivedValues];
}

static CGFloat CPMNineSliceMidScale(CGFloat screenExtent, CGFloat refExtent, CGFloat margin, CGFloat edgeScale);

#pragma mark reference → screen fit

/*
 * The compiled-in table is measured on one device; the game re-lays its UI out on another.
 * CPM's editor is edge-anchored (toolbars hug the edges, the paint surface floats in the
 * middle), so the default maps like a nine-slice: the edge bands keep one scale and the
 * middle band absorbs the difference.
 *
 *   germe (stretch)   one scale per axis — a 22 pt slider becomes 43 pt on a 4:3 iPad
 *   oranlı (uniform)  one scale, letterboxed — pushes the right-hand column off screen
 *   çapalı (anchored) nine-slice, continuous   ← default
 *
 * All three agree when the aspects match, which is the common case on phones.
 */
- (void)ensureFit {
    CGFloat refW = MAX(1.0, _referenceScreenSize.width);
    CGFloat refH = MAX(1.0, _referenceScreenSize.height);
    CGFloat sx = _screenSize.width > 1 ? _screenSize.width / refW : 1.0;
    CGFloat sy = _screenSize.height > 1 ? _screenSize.height / refH : 1.0;
    _fitMarginX = _fitMarginY = 0;
    _fitMidScaleX = _fitMidScaleY = 1.0;
    _fitOffsetX = _fitOffsetY = 0;
    switch (_mappingMode) {
        case CPMUIMappingModeStretch:
            _fitScaleX = sx; _fitScaleY = sy;
            _fitMidScaleX = sx; _fitMidScaleY = sy;
            break;
        case CPMUIMappingModeUniform: {
            CGFloat sc = sqrt(sx * sy);
            _fitScaleX = _fitScaleY = sc;
            _fitMidScaleX = _fitMidScaleY = sc;
            _fitOffsetX = (_screenSize.width - refW * sc) * 0.5;
            _fitOffsetY = (_screenSize.height - refH * sc) * 0.5;
            break;
        }
        case CPMUIMappingModeAnchored:
        default:
            _fitScaleX = _fitScaleY = sy;
            _fitMarginX = refW * 0.22;
            _fitMarginY = refH * 0.22;
            _fitMidScaleX = CPMNineSliceMidScale(_screenSize.width, refW, _fitMarginX, sy);
            _fitMidScaleY = CPMNineSliceMidScale(_screenSize.height, refH, _fitMarginY, sy);
            break;
    }
}

static CGFloat CPMNineSliceMidScale(CGFloat screenExtent, CGFloat refExtent, CGFloat margin, CGFloat edgeScale) {
    CGFloat middle = refExtent - 2.0 * margin;
    if (middle <= 1.0) return edgeScale;
    CGFloat remain = screenExtent - 2.0 * margin * edgeScale;
    return MAX(0.05, remain / middle);
}

static CGFloat CPMNineSliceMap(CGFloat value, CGFloat refExtent, CGFloat margin,
                               CGFloat edgeScale, CGFloat midScale) {
    if (value <= margin) return value * edgeScale;
    if (value >= refExtent - margin)
        return margin * edgeScale + (refExtent - 2.0 * margin) * midScale
             + (value - (refExtent - margin)) * edgeScale;
    return margin * edgeScale + (value - margin) * midScale;
}

static CGFloat CPMNineSliceUnmap(CGFloat mapped, CGFloat refExtent, CGFloat margin,
                                 CGFloat edgeScale, CGFloat midScale) {
    CGFloat lo = margin * edgeScale;
    CGFloat hi = lo + (refExtent - 2.0 * margin) * midScale;
    if (midScale <= 0) return mapped / (edgeScale > 0 ? edgeScale : 1.0);
    if (mapped <= lo) return mapped / edgeScale;
    if (mapped >= hi) return (refExtent - margin) + (mapped - hi) / edgeScale;
    return margin + (mapped - lo) / midScale;
}


#pragma mark space conversions

- (CGPoint)screenPointForReferencePoint:(CGPoint)p {
    if (_referenceScreenSize.width <= 0 || _referenceScreenSize.height <= 0) return p;
    [self ensureFit];
    if (_mappingMode == CPMUIMappingModeAnchored) {
        return CGPointMake(CPMNineSliceMap(p.x, _referenceScreenSize.width, _fitMarginX, _fitScaleX, _fitMidScaleX),
                           CPMNineSliceMap(p.y, _referenceScreenSize.height, _fitMarginY, _fitScaleY, _fitMidScaleY));
    }
    return CGPointMake(p.x * _fitScaleX + _fitOffsetX, p.y * _fitScaleY + _fitOffsetY);
}

- (CGRect)screenRectForReferenceRect:(CGRect)r {
    [self ensureFit];
    if (_mappingMode == CPMUIMappingModeAnchored) {
        /* Map both corners so an edge-anchored rect keeps its gap from that edge. */
        CGPoint lo = [self screenPointForReferencePoint:r.origin];
        CGPoint hi = [self screenPointForReferencePoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r))];
        return CGRectMake(MIN(lo.x, hi.x), MIN(lo.y, hi.y), fabs(hi.x - lo.x), fabs(hi.y - lo.y));
    }
    return CGRectMake(r.origin.x * _fitScaleX + _fitOffsetX,
                      r.origin.y * _fitScaleY + _fitOffsetY,
                      r.size.width * _fitScaleX,
                      r.size.height * _fitScaleY);
}

- (CGPoint)referencePointForScreenPoint:(CGPoint)p {
    if (_screenSize.width <= 0 || _screenSize.height <= 0) return p;
    [self ensureFit];
    if (_mappingMode == CPMUIMappingModeAnchored) {
        return CGPointMake(CPMNineSliceUnmap(p.x, _referenceScreenSize.width, _fitMarginX, _fitScaleX, _fitMidScaleX),
                           CPMNineSliceUnmap(p.y, _referenceScreenSize.height, _fitMarginY, _fitScaleY, _fitMidScaleY));
    }
    CGFloat sx = _fitScaleX > 0.0001 ? _fitScaleX : 1.0;
    CGFloat sy = _fitScaleY > 0.0001 ? _fitScaleY : 1.0;
    return CGPointMake((p.x - _fitOffsetX) / sx, (p.y - _fitOffsetY) / sy);
}

- (CGRect)effectiveCanvasRect {
    if (!CGRectIsNull(_canvasRect) && _canvasRect.size.width > 8 && _canvasRect.size.height > 8) {
        return CGRectIntersection(_canvasRect, CGRectMake(0, 0, _screenSize.width, _screenSize.height));
    }
    /* No calibration yet: the editor's canvas covers the middle of the screen, away
     * from the left sticker list and the right control panel. */
    CPMUIElementAnchor *selector = [self anchorForType:CPMUIElementTypeShapeSelector];
    CPMUIElementAnchor *picker = [self anchorForType:CPMUIElementTypeColorPicker];
    CGRect leftPanel = [self screenRectForReferenceRect:selector.referenceFrame];
    CGRect rightPanel = [self screenRectForReferenceRect:picker.referenceFrame];
    CGFloat x = MAX(8, CGRectGetMaxX(leftPanel) + 4);
    CGFloat right = MIN(_screenSize.width - 8, (CGRectGetWidth(rightPanel) > 0 ? CGRectGetMinX(rightPanel) : _screenSize.width * 0.75) - 4);
    if (right - x < 40) { x = _screenSize.width * 0.2; right = _screenSize.width * 0.8; }
    return CGRectMake(x, _screenSize.height * 0.06, right - x, _screenSize.height * 0.86);
}

- (void)setCanvasRect:(CGRect)canvasRect {
    _canvasRect = canvasRect;
    [self rebuildDerivedValues];
}

/// Aspect-fit of the image inside the canvas, in screen points.
- (CGAffineTransform)canvasTransformForImageSize:(CGSize)imageSize {
    CGRect canvas = [self effectiveCanvasRect];
    CGFloat iw = MAX(1.0, imageSize.width), ih = MAX(1.0, imageSize.height);
    CGFloat scale = MIN(CGRectGetWidth(canvas) / iw, CGRectGetHeight(canvas) / ih);
    if (!(scale > 0)) scale = 1.0;
    CGFloat drawnW = iw * scale, drawnH = ih * scale;
    CGFloat dx = CGRectGetMinX(canvas) + (CGRectGetWidth(canvas) - drawnW) * 0.5;
    CGFloat dy = CGRectGetMinY(canvas) + (CGRectGetHeight(canvas) - drawnH) * 0.5;
    return CGAffineTransformMake(scale, 0, 0, scale, dx, dy);
}

- (CGPoint)mappedPositionFromImagePosition:(CGPoint)imagePosition imageSize:(CGSize)imageSize {
    return CGPointApplyAffineTransform(imagePosition, [self canvasTransformForImageSize:imageSize]);
}

- (CGRect)mappedRectFromImageRect:(CGRect)imageRect imageSize:(CGSize)imageSize {
    CGAffineTransform t = [self canvasTransformForImageSize:imageSize];
    CGRect out = CGRectApplyAffineTransform(imageRect, t);
    return CGRectStandardize(out);
}

- (CGPoint)imagePositionForScreenPoint:(CGPoint)screenPoint imageSize:(CGSize)imageSize {
    CGAffineTransform t = [self canvasTransformForImageSize:imageSize];
    return CGPointApplyAffineTransform(screenPoint, CGAffineTransformInvert(t));
}

#pragma mark diagnostics

- (BOOL)isUsableForCurrentScreen {
    if (_screenSize.width <= 0 || _screenSize.height <= 0) return NO;
    if (self.anchors.count < (NSUInteger)CPMUIElementTypeCount) return NO;
    for (CPMUIElementAnchor *a in self.anchors) {
        if (!a.isValid) return NO;
    }
    /* Orientation is deliberately not a veto here: -refreshForWindowSize: rotates the
     * reference space instead, and NGUI scales its layout to whatever the window is. */
    return YES;
}

- (NSString *)validationReport {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (_referenceSpaceRotated) {
        [lines addObject:[NSString stringWithFormat:@"The compiled-in landscape table was rotated 90° "
                                                     @"to match this %@ screen — re-confirm the paint area.",
                          _screenSize.width > _screenSize.height ? @"landscape" : @"portrait"]];
    } else {
        BOOL screenLandscape = _screenSize.width > _screenSize.height;
        if (screenLandscape != _isLandscape) {
            [lines addObject:@"Profile and screen disagree on orientation — open the panel again to re-derive it."];
        }
    }
    if (!_userVerified) {
        [lines addObject:[NSString stringWithFormat:@"Anchors come from the compiled-in %@ table and were "
                                                    @"never checked on this device. Use the ROI/anchor editor "
                                                    @"to confirm them.", CPM_ANCHOR_CALIBRATION_ID]];
    }
    NSMutableArray<NSString *> *missing = [NSMutableArray array];
    for (CPMUIElementType t = 0; t < CPMUIElementTypeCount; t++) {
        CPMUIElementAnchor *a = [self anchorForType:t];
        if (!a || !a.isValid) [missing addObject:CPMUIElementTypeName(t)];
    }
    if (missing.count) [lines addObject:[NSString stringWithFormat:@"No anchor for: %@", [missing componentsJoinedByString:@", "]]];
    [self ensureFit];
    NSString *modeName = _mappingMode == CPMUIMappingModeStretch ? @"germe"
                     : _mappingMode == CPMUIMappingModeUniform ? @"oranlı" : @"çapalı";
    [lines addObject:[NSString stringWithFormat:
        @"Eşleme %@ · referans %.0f×%.0f → ekran %.0f×%.0f · %0.2f×. Buton ıskalanırsa paneldeki "
        @"eşleme modunu değiştir ya da boya alanını yeniden onayla.",
        modeName, _referenceScreenSize.width, _referenceScreenSize.height,
        _screenSize.width, _screenSize.height, _fitScaleX]];
    if (lines.count == 0) {
        [lines addObject:[NSString stringWithFormat:@"Calibration '%@' looks consistent for %@ (%0.0f×%0.0f pt).",
                          [self _calibrationId_safe],
                          _screenSize.width > _screenSize.height ? @"landscape" : @"portrait",
                          _screenSize.width, _screenSize.height]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

/// The id can be nil in a half-loaded profile; the report should still read well.
- (NSString *)_calibrationId_safe {
    return _calibrationID.length ? _calibrationID : @"(unset)";
}

#pragma mark persistence

- (void)saveToUserDefaults {
    NSData *data = nil;
    NSError *jsonError = nil;
    @try {
        data = [NSJSONSerialization dataWithJSONObject:[self toJSON] options:0 error:&jsonError];
    } @catch (NSException *e) {
        CPM_LOG(@"calibration could not be serialized: %@", e.reason);
        return;
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:data forKey:kCPMCalibrationDefaultsKey];
    [d setObject:_calibrationID ?: @"" forKey:kCPMCalibrationIDKey];
    self.userVerified = YES;
}

+ (nullable instancetype)loadFromUserDefaults {
    return [self loadFromUserDefaultsForID:nil];
}

+ (nullable instancetype)loadFromUserDefaultsForID:(NSString *)calibrationID {
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kCPMCalibrationDefaultsKey];
    if (!data.length) return nil;
    NSError *readError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&readError];
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    if (calibrationID.length && ![json[@"calibrationID"] isEqual:calibrationID]) return nil;
    CPMUICalibration *cal = [self calibrationFromJSON:json];
    cal.userVerified = YES;
    return cal;
}

+ (void)clearSavedCalibration {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d removeObjectForKey:kCPMCalibrationDefaultsKey];
    [d removeObjectForKey:kCPMCalibrationIDKey];
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    CPMUICalibration *c = [[CPMUICalibration alloc] init];
    c.calibrationID = _calibrationID;
    c.referenceScreenSize = _referenceScreenSize;
    c.screenSize = _screenSize;
    c.isLandscape = _isLandscape;
    c.userVerified = _userVerified;
    c.canvasRect = _canvasRect;
    [c.anchorsByType removeAllObjects];
    for (CPMUIElementAnchor *a in _anchorsByType.allValues) {
        c.anchorsByType[@((NSInteger)a.elementType)] = [a copy];
    }
    [c rebuildDerivedValues];
    return c;
}

@end
