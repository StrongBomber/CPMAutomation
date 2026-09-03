/**
 * CPMExecutionController.h
 *
 * Drives the vinyl editor from a decomposed image: one sticker per CPMVinylShape, in
 * paint order, through synthesised touches only.
 *
 * Safety model (this is the part that must not regress):
 *   - The game is never written to. Field offsets are read through CPMIl2CppBridge
 *     (validated, read-only) and used for feedback only; touches are the only effect.
 *   - Placement stops on request (stop), on a real finger touching the screen
 *     (userTouchActive) and on emergencyStop, which also drops queued touch phases.
 *   - The layer budget comes from the game when the bridge can read
 *     VinylsEditor._maxVinylsCount, otherwise from -maxLayers.
 *   - If the calibration profile does not match the screen (wrong orientation, missing
 *     anchors), -startAutomationWithImage:roiRect: refuses to tap and reports why.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CPMShapeDecomposer.h"

@class CPMVinylShape;
@class CPMTouchInjector;
@class CPMUICalibration;
@class CPMIl2CppBridge;
@class CPMUIElementAnchor;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPMAutomationStep) {
    CPMAutomationStepNone = 0,
    CPMAutomationStepLoadingImage = 1,
    CPMAutomationStepDecomposingImage = 2,
    CPMAutomationStepPlacingLayers = 3,
    CPMAutomationStepPaused = 4,
    CPMAutomationStepCompleted = 5,
    CPMAutomationStepStopped = 6,
    CPMAutomationStepFailed = 7,
    CPMAutomationStepVerifying = 8,
};

FOUNDATION_EXPORT NSString *CPMAutomationStepName(CPMAutomationStep step);

/// How the colour picker's three sliders are to be interpreted.
typedef NS_ENUM(NSInteger, CPMColorInputMode) {
    CPMColorInputModeRGB = 0,
    CPMColorInputModeHSV = 1,
};

@protocol CPMExecutionControllerDelegate <NSObject>
@optional
- (void)controller:(id)controller didUpdateProgress:(CGFloat)progress;
- (void)controller:(id)controller didChangeState:(CPMAutomationStep)state;
- (void)controller:(id)controller didPlaceLayer:(NSUInteger)layerIndex total:(NSUInteger)total;
- (void)controller:(id)controller didLogStep:(NSString *)line;
- (void)controller:(id)controller didEncounterError:(NSError *)error;
- (void)controllerDidFinish:(id)controller;
- (void)controllerDidRequestEmergencyStop:(id)controller;
@end

@interface CPMExecutionController : NSObject

@property (nonatomic, weak, nullable) id<CPMExecutionControllerDelegate> delegate;

@property (nonatomic, assign, readonly) CPMAutomationStep currentState;
@property (nonatomic, assign, readonly) CGFloat progress;              // 0…1
@property (nonatomic, assign, readonly) NSUInteger layersPlaced;
@property (nonatomic, assign, readonly) NSUInteger totalLayers;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) BOOL isPaused;
@property (nonatomic, assign, readonly) BOOL emergencyStopActive;
/// What the run is doing right now, one line, for the panel's status label.
@property (nonatomic, copy, readonly) NSString *currentActivity;

@property (nonatomic, strong, nullable) UIImage *referenceImage;
@property (nonatomic, assign) CGRect referenceROIRect;

/* Configuration */
@property (nonatomic, assign) NSInteger maxLayers;          // clamped to the game limit when the bridge is live
@property (nonatomic, assign) NSTimeInterval touchDelayMs;  // settle between touches, ms
@property (nonatomic, assign) BOOL respectLayerLimit;
/// NO = preview only: build and log the plan, never inject a touch.
@property (nonatomic, assign) BOOL dryRun;
/// Tap the editor's Confirm button once the queue is exhausted.
@property (nonatomic, assign) BOOL autoSaveVinyl;
/// Re-select the shape type on every sticker (safer when the game resets it).
@property (nonatomic, assign) BOOL alwaysSelectShapeType;
@property (nonatomic, assign) CPMColorInputMode colorInputMode;
/// Keep a safety margin under the game's own cap (default 1 layer).
@property (nonatomic, assign) NSInteger layerSafetyMargin;
/// Refuse to start when the calibration profile does not match the screen.
@property (nonatomic, assign) BOOL requiresVerifiedCalibration;

/* Dependencies (injected for testing; defaults are the shared singletons) */
@property (nonatomic, strong, nullable) CPMShapeDecomposer *decomposer;
@property (nonatomic, strong, nullable) CPMTouchInjector *injector;
@property (nonatomic, strong, nullable) CPMUICalibration *calibration;
@property (nonatomic, strong, nullable) CPMIl2CppBridge *bridge;

/* Results */
@property (nonatomic, copy, readonly) NSArray<CPMVinylShape *> *plan;
@property (nonatomic, copy, readonly) NSArray<NSString *> *stepLog;
@property (nonatomic, strong, readonly, nullable) CPMShapeDecompositionResult *lastDecomposition;

/* Actions */
- (void)startAutomationWithImage:(UIImage *)image roiRect:(CGRect)roiRect;
/// Run a plan that was produced elsewhere (the preview sheet uses this).
- (void)startWithPlan:(NSArray<CPMVinylShape *> *)plan imageSize:(CGSize)imageSize;
- (void)pauseAutomation;
- (void)resumeAutomation;
- (void)stopAutomation;
- (void)emergencyStop;
- (void)setMaxLayers:(NSInteger)limit;
- (void)setTouchDelay:(NSTimeInterval)ms;

/// Layer cap and current count as the game reports them (0 when blind).
- (NSInteger)gameLayerLimit;
- (NSInteger)gameLayerCount;
/// The full plan as human-readable lines, without running it.
- (NSArray<NSString *> *)planPreviewForShapes:(NSArray<CPMVinylShape *> *)shapes imageSize:(CGSize)imageSize;

/* Progress callbacks (an alternative to the delegate; both are fine together) */
@property (nonatomic, copy, nullable) void (^progressHandler)(CGFloat progress, NSUInteger placed, NSUInteger total);
@property (nonatomic, copy, nullable) void (^stateHandler)(CPMAutomationStep state);

- (NSString *)statusDescription;
- (void)reset;
/// Re-read the game (layer cap / current count / layout drift) and log what changed.
- (void)refreshFromGame;

@end

NS_ASSUME_NONNULL_END
