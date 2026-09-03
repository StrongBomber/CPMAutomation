/**
 * CPMAutoDrawViewController.h
 *
 * The automation's control panel: pick an image, mark the region on screen, preview the
 * sticker plan, then run / pause / stop it. It is a thin driver — every number the user
 * touches goes straight into CPMExecutionController, and every status line comes back out
 * of it, so the panel never holds state the game disagrees with.
 *
 * It also shows *why* something is not safe to run: the calibration profile's validity and
 * the il2cpp readout (layer cap, drift) are both reported here before Start is enabled.
 */
#import <UIKit/UIKit.h>
#import "CPMExecutionController.h"
#import "CPMROIOverlayView.h"

@class CPMUICalibration;

NS_ASSUME_NONNULL_BEGIN

@protocol CPMAutoDrawViewControllerDelegate <NSObject>
@optional
- (void)autoDrawControllerDidRequestImage:(id)controller;
- (void)autoDrawController:(id)controller didRequestROISelection:(BOOL)startFromCurrent;
- (void)autoDrawControllerDidRequestStart:(id)controller;
- (void)autoDrawControllerDidRequestPause:(id)controller;
- (void)autoDrawControllerDidRequestStop:(id)controller;
- (void)autoDrawControllerDidRequestEmergencyStop:(id)controller;
- (void)autoDrawController:(id)controller didUpdateProgress:(CGFloat)progress;
- (void)autoDrawController:(id)controller didUpdateLayerCount:(NSUInteger)placed total:(NSUInteger)total;
- (void)autoDrawController:(id)controller didEncounterError:(NSError *)error;
@end

@interface CPMAutoDrawViewController : UIViewController <CPMExecutionControllerDelegate, CPMROIOverlayViewDelegate>

@property (nonatomic, weak, nullable) id<CPMAutoDrawViewControllerDelegate> delegate;
@property (nonatomic, strong, nullable) UIImage *referenceImage;
/// Region of the *image* to decompose, in image points. CGRectNull = the whole image.
@property (nonatomic, assign) CGRect roiRect;
/// Region of the *screen* the vinyl canvas occupies; handed to the calibration.
@property (nonatomic, assign) CGRect canvasScreenRect;
@property (nonatomic, assign) BOOL roiSelectionEnabled;
@property (nonatomic, strong, nullable) CPMExecutionController *executionController;
/// Shared calibration profile; created from UserDefaults / the compiled-in table.
@property (nonatomic, strong, nullable) CPMUICalibration *calibration;
/// Overlay view the ROI drag is drawn into (owned by the overlay window).
@property (nonatomic, weak, nullable) CPMROIOverlayView *roiOverlayView;
/// Preview-only: build and log the plan, never inject touches.
@property (nonatomic, assign) BOOL previewMode;

- (void)setLayerLimit:(NSInteger)limit;
- (NSInteger)layerLimit;
- (void)setTouchDelay:(NSTimeInterval)ms;
- (NSTimeInterval)touchDelay;

- (void)loadReferenceImage:(UIImage *)image;
- (void)clearReferenceImage;
/// Called by the ROI editor when the user finishes dragging the canvas rect.
- (void)updateROI:(CGRect)rect;
- (void)showControlsAnimated:(BOOL)animated;
- (void)hideControlsAnimated:(BOOL)animated;
/// Re-read the bridge + calibration and refresh the diagnostics line.
- (void)refreshDiagnostics;
- (void)appendLogLine:(NSString *)line;

- (NSString *)statusText;

@end

NS_ASSUME_NONNULL_END
