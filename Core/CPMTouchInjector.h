/**
 * CPMTouchInjector.h
 * Touch synthesis for the CPM vinyl editor.
 *
 * v2.0 shipped an IOHID "setup" that called functions which do not exist
 * (IOHIDeviceSetCreate / IOOPCICollectionCreate / IOHIDServiceGetMatchingServices)
 * and whose sendTouchEventAt: body only logged — nothing ever reached the game.
 * This version picks a real delivery path at runtime and tells the caller which
 * one it got:
 *
 *   CPMTouchBackendKindSyntheticEvent (default)
 *      Builds UITouch/UIEvent stand-ins and calls touchesBegan/Moved/Ended on the
 *      game's own input view. In-process, needs no entitlements, works on a
 *      TrollStore/sideloaded build as well as on a jailbreak, and Unity/NGUI read
 *      their input from exactly that path (Input.touches), so NGUI raycasts,
 *      MoveSliderToTarget and JoystickNGUI all react normally.
 *
 *   CPMTouchBackendKindIOHID (opt-in: UserDefaults key cpm_use_iohid_backend,
 *   i.e. kCPMDefaultsUseIOHID — needs a jailbroken/entitled device to be useful)
 *      IOHIDEventSystemClientDispatchEvent. System-wide, but the private ABI needs
 *      the entitlements a jailbreak provides, so it is not the default.
 *
 *   CPMTouchBackendKindVisualOnly
 *      Nothing can be delivered; the automation shows the finger positions on the
 *      overlay and refuses to claim success. Better than silently doing nothing.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPMTouchEventPhase) {
    CPMTouchEventPhaseBegan,
    CPMTouchEventPhaseMoved,
    CPMTouchEventPhaseEnded,
    CPMTouchEventPhaseCancelled,
};

typedef NS_ENUM(NSInteger, CPMTouchActionType) {
    CPMTouchActionTypeTap,
    CPMTouchActionTypeDrag,
    CPMTouchActionTypeLongPress,
    CPMTouchActionTypeSliderDrag,
};

typedef NS_ENUM(NSInteger, CPMTouchBackendKind) {
    CPMTouchBackendKindUnknown = 0,
    CPMTouchBackendKindVisualOnly = 1,
    CPMTouchBackendKindSyntheticEvent = 2,
    CPMTouchBackendKindIOHID = 3,
};

@interface CPMTouchEvent : NSObject

@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) CPMTouchEventPhase phase;
@property (nonatomic, assign) NSInteger touchId;
@property (nonatomic, copy, nullable) NSString *note;

- (instancetype)initWithLocation:(CGPoint)loc phase:(CPMTouchEventPhase)phase;
+ (instancetype)tapAt:(CGPoint)loc;
+ (NSArray<CPMTouchEvent *> *)dragEventsFrom:(CGPoint)from to:(CGPoint)to steps:(NSInteger)steps;
+ (NSArray<CPMTouchEvent *> *)longPressEventsAt:(CGPoint)loc duration:(NSTimeInterval)duration;

@end

@interface CPMTouchSequence : NSObject

@property (nonatomic, copy, readonly) NSArray<CPMTouchEvent *> *events;
@property (nonatomic, assign, readonly) NSTimeInterval totalDuration;
@property (nonatomic, assign, readonly) CPMTouchActionType actionType;

- (instancetype)initWithEvents:(NSArray<CPMTouchEvent *> *)events;
- (instancetype)initWithEvents:(NSArray<CPMTouchEvent *> *)events type:(CPMTouchActionType)type;
+ (instancetype)sequenceWithEvents:(NSArray<CPMTouchEvent *> *)events type:(CPMTouchActionType)type;
+ (instancetype)tapSequenceAt:(CGPoint)loc;
+ (instancetype)dragSequenceFrom:(CGPoint)from to:(CGPoint)to;
+ (instancetype)sliderDragSequenceAt:(CGPoint)sliderCenter
                           fromValue:(CGFloat)fromValue
                             toValue:(CGFloat)toValue
                         sliderRange:(CGSize)range;

@end

@interface CPMTouchInjector : NSObject

+ (instancetype)sharedInjector;
/// Probes the environment once (safe to call before the game window exists — then
/// call -detectBackend again later).
- (instancetype)init;

#pragma mark Backend

@property (nonatomic, assign, readonly) CPMTouchBackendKind backend;
@property (nonatomic, copy, readonly) NSString *backendDescription;
/// YES when injected touches actually reach the game.
@property (nonatomic, assign, readonly) BOOL canInjectTouches;
/// Re-probes the environment (call after the game's window exists).
- (void)detectBackend;
/// The view synthetic touches are delivered to (Unity's GL/Metal view when found).
@property (nonatomic, weak, readonly, nullable) UIView *inputTargetView;

#pragma mark Configuration

/// Settle time between synthesized phases; the editor's NGUI pass needs a frame.
@property (nonatomic, assign) NSTimeInterval eventDelayMs;   // default 15 ms
@property (nonatomic, assign) NSTimeInterval tapHoldMs;       // default 55 ms
@property (nonatomic, assign) NSInteger dragSteps;            // default 8
@property (nonatomic, assign) BOOL logTouchEvents;
/// YES while a real user finger is on the glass — automation yields instead of fighting it.
@property (nonatomic, assign, readonly) BOOL userTouchActive;

#pragma mark Core synthesis

- (void)synthesizeTapAt:(CGPoint)screenPoint;
- (void)synthesizeTapAt:(CGPoint)screenPoint completion:(nullable void (^)(BOOL success))completion;
- (void)synthesizeDragFrom:(CGPoint)fromPoint to:(CGPoint)toPoint;
- (void)synthesizeLongPressAt:(CGPoint)screenPoint duration:(NSTimeInterval)duration;
- (void)synthesizeSliderAdjustAt:(CGPoint)sliderCenter
                       fromValue:(CGFloat)fromValue
                         toValue:(CGFloat)toValue
                     sliderRange:(CGSize)range;

#pragma mark Sequences

- (void)executeSequence:(CPMTouchSequence *)sequence completion:(nullable void (^)(BOOL success))completion;
- (void)cancelCurrentInjection;
- (void)emergencyStop;
@property (nonatomic, assign, readonly) BOOL emergencyStopActive;
/// Re-arm after an emergency stop / user abort (start of a new run).
- (void)clearEmergencyStop;

#pragma mark Debug / calibration

/// Called for every synthesized *and* captured point (anchor calibration hook).
@property (nonatomic, copy, nullable) void (^onTouchObserved)(CGPoint point, BOOL synthesized);
/// Draws the synthesized touch into the overlay (visual-only mode + debugging).
@property (nonatomic, assign) BOOL showsTouchRipples;
/// View the ripples are drawn in (the overlay window's root view). Weak: owned by UI.
@property (nonatomic, weak, nullable) UIView *previewHostView;
/// Force the delivery target (the game's Unity view). nil = auto-detect.
@property (nonatomic, weak, nullable) UIView *preferredTargetView;

#pragma mark Geometry

@property (nonatomic, assign, readonly) CGFloat screenScale;
@property (nonatomic, assign, readonly) CGSize screenBounds;
- (CGPoint)pointInWindowCoordinates:(CGPoint)point;
- (CGPoint)adjustPointForScreenScale:(CGPoint)point;

@end

NS_ASSUME_NONNULL_END
