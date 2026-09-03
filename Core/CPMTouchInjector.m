/**
 * CPMTouchInjector.m — see CPMTouchInjector.h for the backend contract.
 */
#import "CPMTouchInjector.h"
#import "OverlayCommon.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <unistd.h>
#import <mach/mach_time.h>

/// Opt-in: dispatch through IOHIDEventSystemClient instead of the in-process path.
/// Requires the entitlements a jailbreak grants; left off by default on purpose.
static NSString *const kCPMDefaultsUseIOHID = @"cpm_use_iohid_backend";

#pragma mark - unknown-selector shield

/*
 * UIKit/Unity occasionally ask a UIEvent/UITouch for private things. Our stand-ins
 * answer "no idea" instead of crashing the game: any unhandled message comes back
 * zeroed (see -forwardingTargetForSelector: / -forwardInvocation: below).
 */
#pragma mark - synthetic touch

@interface CPMSyntheticTouch : NSObject
@property (nonatomic, assign) UITouchPhase cp_phase;
@property (nonatomic, assign) NSTimeInterval cp_timestamp;
@property (nonatomic, assign) NSUInteger cp_tapCount;
@property (nonatomic, assign) CGPoint cp_location;
@property (nonatomic, weak, nullable) UIView *cp_view;
@property (nonatomic, weak, nullable) UIWindow *cp_window;
@end

@implementation CPMSyntheticTouch

- (UITouchPhase)phase { return _cp_phase; }
- (NSTimeInterval)timestamp { return _cp_timestamp; }
- (NSUInteger)tapCount { return _cp_tapCount; }
- (CGPoint)locationInView:(UIView *)view {
    /* The game space is the window: the overlay and the Unity view share its size. */
    (void)view;
    return _cp_location;
}
- (CGPoint)previousLocationInView:(UIView *)view { (void)view; return _cp_location; }
- (UIView *)view { return _cp_view; }
- (UIWindow *)window { return _cp_window; }
- (UITouchType)type { return UITouchTypeDirect; }
- (BOOL)isPrecise { return NO; }
- (BOOL)isEstimated { return NO; }
- (NSUInteger)modifierFlags { return 0; }
- (CGFloat)pressure { return 1.0; }
- (CGFloat)majorRadius { return 8.0; }
- (CGFloat)minorRadius { return 8.0; }
- (CGFloat)majorRadiusTolerance { return 0.0; }

// Anything Unity asks that we do not model is answered with a zeroed return.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *sig = [super methodSignatureForSelector:sel];
    if (!sig) sig = [NSMethodSignature signatureWithObjCTypes:"@@:"];
    return sig;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    NSUInteger size = 0;
    const char *types = invocation.methodSignature.methodReturnType;
    if (types && types[0] == '@') size = sizeof(void *);
    if (size) {
        void *zero = NULL;
        [invocation setReturnValue:&zero];
    } else {
        long long zero = 0;
        [invocation setReturnValue:&zero];
    }
}

@end

#pragma mark - synthetic event

@interface CPMSyntheticEvent : NSObject
@property (nonatomic, strong) NSSet<CPMSyntheticTouch *> *cp_touches;
@property (nonatomic, assign) NSTimeInterval cp_timestamp;
@end

@implementation CPMSyntheticEvent

- (NSSet *)allTouches { return _cp_touches ?: [NSSet set]; }
- (NSSet *)touchesForView:(UIView *)view { (void)view; return [self allTouches]; }
- (NSSet *)touchesForWindow:(UIWindow *)window { (void)window; return [self allTouches]; }
- (NSSet *)touchesForGestureRecognizer:(UIGestureRecognizer *)g { (void)g; return [self allTouches]; }
- (NSArray *)coalescedTouchesForTouch:(id)touch { return touch ? @[touch] : @[]; }
- (NSArray *)predictedTouchesForTouch:(id)touch { return @[]; }
- (NSTimeInterval)timestamp { return _cp_timestamp; }
- (NSInteger)type { return 0; }          // UIEventTypeTouches
- (NSInteger)subtype { return 0; }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    NSMethodSignature *sig = [super methodSignatureForSelector:sel];
    if (!sig) sig = [NSMethodSignature signatureWithObjCTypes:"@@:"];
    return sig;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    const char *types = invocation.methodSignature.methodReturnType;
    if (types && types[0] == '@') {
        void *zero = NULL;
        [invocation setReturnValue:&zero];
    } else {
        long long zero = 0;
        [invocation setReturnValue:&zero];
    }
}

@end

#pragma mark - CPMTouchEvent / CPMTouchSequence

@implementation CPMTouchEvent

- (instancetype)initWithLocation:(CGPoint)loc phase:(CPMTouchEventPhase)phase {
    self = [super init];
    if (self) {
        _location = loc;
        _timestamp = [NSDate date].timeIntervalSinceReferenceDate;
        _phase = phase;
        _touchId = 1;
    }
    return self;
}

+ (instancetype)tapAt:(CGPoint)loc {
    return [[self alloc] initWithLocation:loc phase:CPMTouchEventPhaseBegan];
}

+ (NSArray<CPMTouchEvent *> *)dragEventsFrom:(CGPoint)from to:(CGPoint)to steps:(NSInteger)steps {
    steps = MAX(1, steps);
    NSMutableArray<CPMTouchEvent *> *out = [NSMutableArray arrayWithCapacity:(NSUInteger)steps + 2];
    NSTimeInterval base = [NSDate date].timeIntervalSinceReferenceDate;
    for (NSInteger i = 0; i <= steps; i++) {
        CGFloat t = (CGFloat)i / (CGFloat)steps;
        CGPoint pt = CGPointMake(from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t);
        CPMTouchEvent *e = [[CPMTouchEvent alloc] initWithLocation:pt
                                                             phase:(i == 0 ? CPMTouchEventPhaseBegan : CPMTouchEventPhaseMoved)];
        e.timestamp = base + i * 0.016;
        [out addObject:e];
    }
    CPMTouchEvent *end = [[CPMTouchEvent alloc] initWithLocation:to phase:CPMTouchEventPhaseEnded];
    end.timestamp = base + (steps + 1) * 0.016;
    [out addObject:end];
    return out;
}

+ (NSArray<CPMTouchEvent *> *)longPressEventsAt:(CGPoint)loc duration:(NSTimeInterval)duration {
    CPMTouchEvent *begin = [[CPMTouchEvent alloc] initWithLocation:loc phase:CPMTouchEventPhaseBegan];
    CPMTouchEvent *end = [[CPMTouchEvent alloc] initWithLocation:loc phase:CPMTouchEventPhaseEnded];
    end.timestamp = begin.timestamp + MAX(0.05, duration);
    return @[begin, end];
}

@end

@implementation CPMTouchSequence

- (instancetype)initWithEvents:(NSArray<CPMTouchEvent *> *)events type:(CPMTouchActionType)type {
    self = [super init];
    if (self) {
        _events = [events copy] ?: @[];
        _actionType = type;
        if (_events.count > 1) {
            _totalDuration = _events.lastObject.timestamp - _events.firstObject.timestamp;
        }
    }
    return self;
}

- (instancetype)initWithEvents:(NSArray<CPMTouchEvent *> *)events {
    return [self initWithEvents:events type:CPMTouchActionTypeTap];
}

+ (instancetype)sequenceWithEvents:(NSArray<CPMTouchEvent *> *)events type:(CPMTouchActionType)type {
    return [[self alloc] initWithEvents:events type:type];
}

+ (instancetype)tapSequenceAt:(CGPoint)loc {
    CPMTouchEvent *b = [[CPMTouchEvent alloc] initWithLocation:loc phase:CPMTouchEventPhaseBegan];
    CPMTouchEvent *e = [[CPMTouchEvent alloc] initWithLocation:loc phase:CPMTouchEventPhaseEnded];
    e.timestamp = b.timestamp + 0.05;
    return [[self alloc] initWithEvents:@[b, e] type:CPMTouchActionTypeTap];
}

+ (instancetype)dragSequenceFrom:(CGPoint)from to:(CGPoint)to {
    return [[self alloc] initWithEvents:[CPMTouchEvent dragEventsFrom:from to:to steps:8]
                                   type:CPMTouchActionTypeDrag];
}

+ (instancetype)sliderDragSequenceAt:(CGPoint)sliderCenter
                           fromValue:(CGFloat)fromValue
                             toValue:(CGFloat)toValue
                         sliderRange:(CGSize)range {
    CGFloat minX = sliderCenter.x - range.width * 0.5;
    CGFloat fromX = CPMMapRange(CPMClamp(fromValue, 0, 1), 0, 1, minX, minX + range.width);
    CGFloat toX = CPMMapRange(CPMClamp(toValue, 0, 1), 0, 1, minX, minX + range.width);
    return [self dragSequenceFrom:CGPointMake(fromX, sliderCenter.y) to:CGPointMake(toX, sliderCenter.y)];
}

@end

#pragma mark - IOHID backend (private ABI, resolved with dlsym)

typedef struct { uint32_t hi; uint32_t lo; } CPMAbsoluteTime_;
typedef void *CPMIOHIDEventSystemClient_;
typedef void *CPMIOHIDEvent_;

typedef CPMIOHIDEventSystemClient_ *(*CPMFnHIDClientCreate)(void *allocator);
typedef int (*CPMFnHIDClientDispatch)(CPMIOHIDEventSystemClient_ *client, CPMIOHIDEvent_ *event);
typedef CPMIOHIDEvent_ *(*CPMFnHIDCreateFinger)(void *allocator, CPMAbsoluteTime_ ts, uint32_t index, uint32_t identifier,
                                                 uint32_t state, float x, float y, float z, float pressure,
                                                 float twist, float altitude, float azimuth, float quality,
                                                 float density, Boolean integrated);

@interface CPMTouchInjector () {
    CPMIOHIDEventSystemClient_ *_hidClient;
    CPMFnHIDClientCreate _fnClientCreate;
    CPMFnHIDClientDispatch _fnDispatch;
    CPMFnHIDCreateFinger _fnCreateFinger;
}
@property (nonatomic, assign, readwrite) CPMTouchBackendKind backend;
@property (nonatomic, copy, readwrite) NSString *backendDescription;
@property (nonatomic, assign, readwrite) BOOL canInjectTouches;
@property (nonatomic, assign, readwrite) BOOL emergencyStopActive;
@property (nonatomic, assign, readwrite) BOOL userTouchActive;
@property (nonatomic, weak, readwrite, nullable) UIView *inputTargetView;
@property (nonatomic, strong, nullable) UIPanGestureRecognizer *userTouchWatcher;
/// Bumped by cancel/stop so queued phases simply do not fire.
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, assign, readwrite) CGFloat screenScale;
@property (nonatomic, assign, readwrite) CGSize screenBounds;
@end

@implementation CPMTouchInjector

+ (instancetype)sharedInjector {
    static CPMTouchInjector *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[CPMTouchInjector alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _eventDelayMs = 15.0;
        _tapHoldMs = 55.0;
        _dragSteps = 8;
        _logTouchEvents = NO;
        _showsTouchRipples = NO;
        _screenScale = [UIScreen mainScreen].scale;
        _screenBounds = [UIScreen mainScreen].bounds.size;
        [self detectBackend];
    }
    return self;
}

#pragma mark backend probing

static BOOL CPMClassLooksLikeUnityInput(Class cls) {
    NSString *name = NSStringFromClass(cls);
    static NSArray<NSString *> *needles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        needles = @[@"UnityView", @"UnityViewMetal", @"UnityView_iOSMetal", @"UnityRandomViewController",
                    @"GLSurfaceView", @"CAEAGLLayer", @"CAMetalLayer", @"MMMetalView", @"Unity"];
    });
    for (NSString *needle in needles) {
        if ([name rangeOfString:needle].location != NSNotFound) return YES;
    }
    return NO;
}

- (UIWindow *)gameWindow {
    UIApplication *app = UIApplication.sharedApplication;
    NSMutableArray<UIWindow *> *candidates = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            [candidates addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    for (UIWindow *w in app.windows) {
        if (![candidates containsObject:w]) [candidates addObject:w];
    }

    // Prefer the window that actually hosts the Unity view, then any visible one that
    // is not ours (the overlay window is class-named OverlayWindow* by convention).
    for (UIWindow *w in candidates) {
        if ([CPMTouchInjector isOverlayWindow:w]) continue;
        if (w.hidden || w.alpha < 0.05) continue;
        if ([self viewInsideWindow:w matches:^BOOL(Class c) { return CPMClassLooksLikeUnityInput(c); }]) return w;
    }
    for (UIWindow *w in candidates) {
        if ([CPMTouchInjector isOverlayWindow:w]) continue;
        if (!w.hidden) return w;
    }
    return nil;
}

+ (BOOL)isOverlayWindow:(UIWindow *)window {
    NSString *cls = NSStringFromClass([window class]);
    return [cls hasPrefix:@"Overlay"] || [cls containsString:@"OverlayWindow"];
}

- (UIView *)viewInsideWindow:(UIWindow *)window matches:(BOOL (^)(Class cls))matcher {
    if (!window) return nil;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:window];
    UIView *fallback = window;
    while (stack.count) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if (v != window && matcher(v.class)) return v;
        for (UIView *sub in v.subviews) {
            [stack addObject:sub];
            if (matcher(sub.class) && !fallback) fallback = sub;
        }
    }
    for (UIView *sub in window.subviews) {
        if (matcher(sub.class)) return sub;
    }
    return (fallback != window && matcher(fallback.class)) ? fallback : nil;
}

- (void)detectBackend {
    _backend = CPMTouchBackendKindUnknown;
    _backendDescription = @"not probed";
    _canInjectTouches = NO;
    _inputTargetView = nil;

    UIView *target = self.preferredTargetView;
    UIWindow *window = [self gameWindow];
    if (!target && window) {
        target = [self viewInsideWindow:window matches:^BOOL(Class c) { return CPMClassLooksLikeUnityInput(c); }];
        if (!target) target = window.rootViewController.view ?: window;
    }
    self.inputTargetView = target;
    [self installUserTouchWatcherOnView:target];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:kCPMDefaultsUseIOHID]) {
        if ([self setupIOHID]) {
            _backend = CPMTouchBackendKindIOHID;
            _backendDescription = @"IOHIDEventSystemClient (system-wide)";
            _canInjectTouches = YES;
        }
    }
    if (_backend == CPMTouchBackendKindUnknown) {
        if (target && [target respondsToSelector:@selector(touchesBegan:withEvent:)]) {
            _backend = CPMTouchBackendKindSyntheticEvent;
            _backendDescription = [NSString stringWithFormat:@"synthetic UIEvent -> %@",
                                   NSStringFromClass(target.class)];
            _canInjectTouches = YES;
        } else {
            _backend = CPMTouchBackendKindVisualOnly;
            _backendDescription = @"no game window found yet (visual preview only)";
        }
    }
    CPM_LOG(@"touch backend: %@", _backendDescription);
}

- (void)installUserTouchWatcherOnView:(UIView *)view {
    if (self.userTouchWatcher) {
        [self.userTouchWatcher.view removeGestureRecognizer:self.userTouchWatcher];
        self.userTouchWatcher = nil;
    }
    if (!view) return;
    UIPanGestureRecognizer *watcher = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(userTouchChanged:)];
    watcher.cancelsTouchesInView = NO;
    watcher.delaysTouchesBegan = NO;
    watcher.delaysTouchesEnded = NO;
    watcher.maximumNumberOfTouches = NSIntegerMax;
    [view addGestureRecognizer:watcher];
    self.userTouchWatcher = watcher;
}

- (void)userTouchChanged:(UIPanGestureRecognizer *)gr {
    switch (gr.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
            _userTouchActive = YES;
            break;
        default:
            _userTouchActive = NO;
            break;
    }
}

#pragma mark IOHID

- (BOOL)setupIOHID {
    _fnClientCreate = (CPMFnHIDClientCreate)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientCreate");
    _fnDispatch = (CPMFnHIDClientDispatch)dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientDispatchEvent");
    _fnCreateFinger = (CPMFnHIDCreateFinger)dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerFingerEvent");
    if (!_fnClientCreate || !_fnDispatch || !_fnCreateFinger) {
        CPM_LOG(@"IOHID backend requested but the private entry points are missing");
        return NO;
    }
    if (!_hidClient) _hidClient = _fnClientCreate(NULL);
    return _hidClient != NULL;
}

- (void)iohidSendPhase:(CPMTouchEventPhase)phase at:(CGPoint)point {
    if (!_fnCreateFinger || !_fnDispatch) return;
    /* IOHIDDigitizerTransducerStatus bits: touching | range | on | identity. */
    enum {
        CPMHIDStateTouching = 1 << 0,
        CPMHIDStateRange = 1 << 1,
        CPMHIDStateOn = 1 << 2,
        CPMHIDStateIdentity = 1 << 3,
    };
    uint32_t state = 0;
    switch (phase) {
        case CPMTouchEventPhaseBegan:
            state = CPMHIDStateTouching | CPMHIDStateRange | CPMHIDStateOn | CPMHIDStateIdentity;
            break;
        case CPMTouchEventPhaseMoved:
            state = CPMHIDStateTouching | CPMHIDStateRange | CPMHIDStateOn | CPMHIDStateIdentity;
            break;
        default:
            state = 0;    // lifted
            break;
    }
    CGFloat scale = self.screenScale ?: 1.0;
    CGFloat w = self.screenBounds.width * scale;
    CGFloat h = self.screenBounds.height * scale;
    uint64_t now = mach_absolute_time();
    CPMAbsoluteTime_ ts = {(uint32_t)(now >> 32), (uint32_t)(now & 0xFFFFFFFFu)};
    void *event = _fnCreateFinger(NULL, ts, 0, 1, state,
                                 (float)(point.x * scale / MAX(1.0, w)),
                                 (float)(point.y * scale / MAX(1.0, h)),
                                 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, true);
    if (!event) return;
    (void)w; (void)h;
    _fnDispatch(_hidClient, event);
    CFRelease(event);
}

#pragma mark delivery

- (CGPoint)pointInWindowCoordinates:(CGPoint)point {
    /* Screen points and the game window's points are the same space on iOS; kept as
     * an explicit hop so the calibration code has one place to change. */
    return point;
}

- (CGPoint)adjustPointForScreenScale:(CGPoint)point {
    return CGPointMake(point.x * self.screenScale, point.y * self.screenScale);
}

- (void)deliverEvent:(CPMTouchEvent *)event {
    CGPoint p = [self pointInWindowCoordinates:event.location];
    if (self.onTouchObserved) self.onTouchObserved(p, YES);

    switch (self.backend) {
        case CPMTouchBackendKindIOHID:
            [self iohidSendPhase:event.phase at:p];
            return;
        case CPMTouchBackendKindVisualOnly:
        case CPMTouchBackendKindUnknown:
            [self showRippleAt:p phase:event.phase];
            return;
        case CPMTouchBackendKindSyntheticEvent:
            break;
    }

    UIView *view = self.inputTargetView;
    if (!view) {
        CPM_LOG(@"input view vanished, falling back to preview mode");
        self.backend = CPMTouchBackendKindVisualOnly;
        self.backendDescription = @"input view lost (visual preview only)";
        self.canInjectTouches = NO;
        [self showRippleAt:p phase:event.phase];
        return;
    }

    CPMSyntheticTouch *touch = [[CPMSyntheticTouch alloc] init];
    touch.cp_location = p;
    touch.cp_timestamp = event.timestamp;
    touch.cp_tapCount = (event.phase == CPMTouchEventPhaseBegan) ? 1 : 0;
    touch.cp_view = view;
    touch.cp_window = view.window;
    switch (event.phase) {
        case CPMTouchEventPhaseBegan: touch.cp_phase = UITouchPhaseBegan; break;
        case CPMTouchEventPhaseMoved: touch.cp_phase = UITouchPhaseMoved; break;
        case CPMTouchEventPhaseEnded: touch.cp_phase = UITouchPhaseEnded; break;
        case CPMTouchEventPhaseCancelled: touch.cp_phase = UITouchPhaseCancelled; break;
    }

    CPMSyntheticEvent *ev = [[CPMSyntheticEvent alloc] init];
    ev.cp_touches = [NSSet setWithObject:touch];
    ev.cp_timestamp = event.timestamp;

    NSSet *touches = [NSSet setWithObject:touch];
    switch (event.phase) {
        case CPMTouchEventPhaseBegan:
            [view touchesBegan:touches withEvent:(UIEvent *)ev];
            break;
        case CPMTouchEventPhaseMoved:
            [view touchesMoved:touches withEvent:(UIEvent *)ev];
            break;
        case CPMTouchEventPhaseEnded:
            [view touchesEnded:touches withEvent:(UIEvent *)ev];
            break;
        case CPMTouchEventPhaseCancelled:
            [view touchesCancelled:touches withEvent:(UIEvent *)ev];
            break;
    }
    [self showRippleAt:p phase:event.phase];
}

- (void)scheduleEvents:(NSArray<CPMTouchEvent *> *)events
             completion:(nullable void (^)(BOOL success))completion {
    NSUInteger myGen = self.generation;
    NSTimeInterval base = events.firstObject.timestamp ?: [NSDate date].timeIntervalSinceReferenceDate;
    __block BOOL any = NO;
    void (^scheduleEnd)(void) = ^{
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(myGen == self.generation && any);
            });
        }
    };
    if (events.count == 0) { scheduleEnd(); return; }
    NSTimeInterval last = 0;
    for (CPMTouchEvent *e in events) {
        NSTimeInterval offset = (e.timestamp - base) + self.eventDelayMs / 1000.0;
        last = MAX(last, offset);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0, offset) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (myGen != self.generation || self.emergencyStopActive) return;
            if (self.userTouchActive) {           // never fight a real finger
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    if (myGen != self.generation || self.emergencyStopActive) return;
                    any = YES;
                    [self deliverEvent:e];
                });
                return;
            }
            any = YES;
            [self deliverEvent:e];
        });
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((last + 0.02) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        scheduleEnd();
    });
}

- (void)synthesizeTapAt:(CGPoint)screenPoint {
    [self synthesizeTapAt:screenPoint completion:nil];
}

- (void)synthesizeTapAt:(CGPoint)screenPoint completion:(void (^)(BOOL))completion {
    CPMTouchEvent *b = [[CPMTouchEvent alloc] initWithLocation:screenPoint phase:CPMTouchEventPhaseBegan];
    CPMTouchEvent *e = [[CPMTouchEvent alloc] initWithLocation:screenPoint phase:CPMTouchEventPhaseEnded];
    e.timestamp = b.timestamp + MAX(0.02, self.tapHoldMs / 1000.0);
    [self scheduleEvents:@[b, e] completion:completion];
}

- (void)synthesizeDragFrom:(CGPoint)fromPoint to:(CGPoint)toPoint {
    NSArray *events = [CPMTouchEvent dragEventsFrom:fromPoint to:toPoint steps:self.dragSteps];
    for (NSUInteger i = 0; i < events.count; i++) {
        CPMTouchEvent *e = events[i];
        e.timestamp = e.timestamp + (i * self.eventDelayMs / 1000.0);
    }
    [self scheduleEvents:events completion:nil];
}

- (void)synthesizeLongPressAt:(CGPoint)screenPoint duration:(NSTimeInterval)duration {
    [self scheduleEvents:[CPMTouchEvent longPressEventsAt:screenPoint duration:duration] completion:nil];
}

- (void)synthesizeSliderAdjustAt:(CGPoint)sliderCenter
                       fromValue:(CGFloat)fromValue
                         toValue:(CGFloat)toValue
                     sliderRange:(CGSize)range {
    CPMTouchSequence *seq = [CPMTouchSequence sliderDragSequenceAt:sliderCenter
                                                        fromValue:fromValue
                                                          toValue:toValue
                                                      sliderRange:range];
    [self executeSequence:seq completion:nil];
}

- (void)executeSequence:(CPMTouchSequence *)sequence completion:(void (^)(BOOL))completion {
    if (!sequence || sequence.events.count == 0) {
        if (completion) completion(NO);
        return;
    }
    [self scheduleEvents:sequence.events completion:completion];
}

- (void)cancelCurrentInjection {
    self.generation++;
    self.emergencyStopActive = YES;   // callers re-arm with -clearEmergencyStop
}

- (void)emergencyStop {
    [self cancelCurrentInjection];
    CPM_LOG(@"emergency stop — pending synthesized touches dropped");
}

/// Called by the controller when a new run starts.
- (void)clearEmergencyStop {
    self.emergencyStopActive = NO;
}

#pragma mark preview ripples

- (void)showRippleAt:(CGPoint)point phase:(CPMTouchEventPhase)phase {
    if (!self.showsTouchRipples && self.backend != CPMTouchBackendKindVisualOnly) return;
    if (phase != CPMTouchEventPhaseBegan) return;
    UIView *host = self.previewHostView;
    if (!host) return;

    UIView *ring = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    ring.center = point;
    ring.layer.cornerRadius = 22;
    ring.layer.borderWidth = 2;
    ring.layer.borderColor = (self.backend == CPMTouchBackendKindVisualOnly)
        ? [UIColor systemOrangeColor].CGColor
        : [UIColor systemGreenColor].CGColor;
    ring.userInteractionEnabled = NO;
    [host addSubview:ring];

    [UIView animateWithDuration:0.45 animations:^{
        ring.transform = CGAffineTransformMakeScale(1.8, 1.8);
        ring.alpha = 0;
    } completion:^(__unused BOOL f) {
        [ring removeFromSuperview];
    }];
}

@end
