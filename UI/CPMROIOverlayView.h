/**
 * CPMROIOverlayView.h
 *
 * Full-screen drag-a-rect selector used to tell the automation where the car's paint
 * surface actually is on this device. While it is hidden it must not intercept touches;
 * `pointInside:withEvent:` is the guard for that.
 */
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CPMROIOverlayViewDelegate <NSObject>
@optional
- (void)roiOverlay:(id)overlay didFinishWithRect:(CGRect)rect;
- (void)roiOverlayDidCancel:(id)overlay;
@end

@interface CPMROIOverlayView : UIView

@property (nonatomic, weak, nullable) id<CPMROIOverlayViewDelegate> delegate;
@property (nonatomic, assign, readonly) CGRect selectedRect;
@property (nonatomic, assign) BOOL showGuides;
@property (nonatomic, assign) BOOL showCenterCrosshair;
@property (nonatomic, assign, readonly) BOOL isSelecting;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)beginSelection;
- (void)cancelSelection;
- (void)clearSelection;
/// Accept whatever is currently dragged (the panel's Done button).
- (void)finishSelection;
/// Show an existing rect without entering selection mode.
- (void)showSelectedRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
