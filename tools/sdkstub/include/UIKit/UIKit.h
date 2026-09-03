/* Minimal UIKit for the offline type-check harness (see tools/README-cpm-check.md).
 * Only what this repo uses. Not a real SDK; never shipped. */
#ifndef _CPMSTUB_UIKIT_H
#define _CPMSTUB_UIKIT_H

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#define UIKIT_EXTERN extern
#define UIKIT_STATIC_INLINE static inline

typedef struct UIEdgeInsets { CGFloat top, left, bottom, right; } UIEdgeInsets;
#define UIEdgeInsetsZero ((UIEdgeInsets){0,0,0,0})
#define UIEdgeInsetsMake(t,l,b,r) ((UIEdgeInsets){(t),(l),(b),(r)})

typedef NSInteger NSTextAlignment;
enum { NSTextAlignmentLeft = 0, NSTextAlignmentCenter = 1, NSTextAlignmentRight = 2,
       NSTextAlignmentJustified = 3, NSTextAlignmentNatural = 4 };
typedef NSInteger NSWritingDirection;
enum { NSWritingDirectionNatural = -1, NSWritingDirectionLeftToRight = 0, NSWritingDirectionRightToLeft = 1 };

typedef NSInteger UIControlEvents;
enum { UIControlEventTouchDown = 1 << 0, UIControlEventTouchDownRepeat = 1 << 1,
       UIControlEventTouchDragInside = 1 << 2, UIControlEventTouchDragOutside = 1 << 3,
       UIControlEventTouchUpInside = 1 << 6, UIControlEventTouchUpOutside = 1 << 7,
       UIControlEventTouchCancel = 1 << 8, UIControlEventValueChanged = 1 << 12,
       UIControlEventAllEvents = 0xFFFFFFFF };
typedef NSInteger UIControlState;
enum { UIControlStateNormal = 0, UIControlStateHighlighted = 1 << 0, UIControlStateDisabled = 1 << 1,
       UIControlStateSelected = 1 << 2, UIControlStateFocused = 1 << 3 };

enum { UIScrollViewIndicatorStyleDefault = 0, UIScrollViewIndicatorStyleBlack = 1, UIScrollViewIndicatorStyleWhite = 2 };

typedef NS_ENUM(NSInteger, UIViewContentMode) {
    UIViewContentModeScaleToFill = 0, UIViewContentModeScaleAspectFit = 1,
    UIViewContentModeScaleAspectFill = 2, UIViewContentModeRedraw = 3, UIViewContentModeCenter = 4,
    UIViewContentModeTop = 5, UIViewContentModeBottom = 6, UIViewContentModeLeft = 7,
    UIViewContentModeRight = 8, UIViewContentModeTopLeft = 9, UIViewContentModeTopRight = 10,
    UIViewContentModeBottomLeft = 11, UIViewContentModeBottomRight = 12
};
typedef NS_OPTIONS(NSUInteger, UIViewAutoresizing) {
    UIViewAutoresizingNone = 0, UIViewAutoresizingFlexibleLeftMargin = 1 << 0,
    UIViewAutoresizingFlexibleWidth = 1 << 1, UIViewAutoresizingFlexibleRightMargin = 1 << 2,
    UIViewAutoresizingFlexibleTopMargin = 1 << 3, UIViewAutoresizingFlexibleHeight = 1 << 4,
    UIViewAutoresizingFlexibleBottomMargin = 1 << 5
};
typedef NS_OPTIONS(NSUInteger, UIViewTintAdjustmentMode) {
    UIViewTintAdjustmentModeAutomatic = 0, UIViewTintAdjustmentModeNormal = 1, UIViewTintAdjustmentModeDimmed = 2
};
typedef NS_OPTIONS(NSUInteger, UIRectCorner) {
    UIRectCornerTopLeft = 1 << 0, UIRectCornerTopRight = 1 << 1, UIRectCornerBottomLeft = 1 << 2,
    UIRectCornerBottomRight = 1 << 3, UIRectCornerAllCorners = ~0UL
};
typedef NS_OPTIONS(NSUInteger, UIRectEdge) {
    UIRectEdgeNone = 0, UIRectEdgeTop = 1 << 0, UIRectEdgeLeft = 1 << 1,
    UIRectEdgeBottom = 1 << 2, UIRectEdgeRight = 1 << 3, UIRectEdgeAll = 15
};
typedef NS_ENUM(NSInteger, UIViewAnimationCurve) {
    UIViewAnimationCurveEaseInOut = 0, UIViewAnimationCurveEaseIn = 1,
    UIViewAnimationCurveEaseOut = 2, UIViewAnimationCurveLinear = 3
};
typedef NS_OPTIONS(NSUInteger, UIViewAnimationOptions) {
    UIViewAnimationOptionLayoutSubviews = 1 << 0, UIViewAnimationOptionAllowUserInteraction = 1 << 1,
    UIViewAnimationOptionBeginFromCurrentState = 1 << 2, UIViewAnimationOptionRepeat = 1 << 4,
    UIViewAnimationOptionAutoreverse = 1 << 5, UIViewAnimationOptionCurveEaseInOut = 0 << 16,
    UIViewAnimationOptionCurveEaseIn = 1 << 16, UIViewAnimationOptionCurveEaseOut = 2 << 16,
    UIViewAnimationOptionCurveLinear = 3 << 16, UIViewAnimationOptionTransitionNone = 0 << 20,
    UIViewAnimationOptionTransitionCrossDissolve = 2 << 20, UIViewAnimationOptionTransitionFlipFromLeft = 3 << 20,
    UIViewAnimationOptionTransitionFlipFromRight = 4 << 20
};
typedef CGFloat UIWindowLevel;
enum { UIWindowLevelNormal = 0, UIWindowLevelAlert = 2000.0, UIWindowLevelStatusBar = 1000.0 };
typedef NS_ENUM(NSInteger, UIStatusBarStyle) { UIStatusBarStyleDefault = 0, UIStatusBarStyleLightContent = 1 };
typedef NS_ENUM(NSInteger, UIInterfaceOrientation) {
    UIInterfaceOrientationUnknown = 0, UIInterfaceOrientationPortrait = 1,
    UIInterfaceOrientationPortraitUpsideDown = 2, UIInterfaceOrientationLandscapeLeft = 3,
    UIInterfaceOrientationLandscapeRight = 4
};
typedef NS_ENUM(NSInteger, UIInterfaceOrientationMask) {
    UIInterfaceOrientationMaskPortrait = 1 << 1, UIInterfaceOrientationMaskLandscapeLeft = 1 << 4,
    UIInterfaceOrientationMaskLandscapeRight = 1 << 3, UIInterfaceOrientationMaskAll = 0x1f
};
typedef NS_ENUM(NSInteger, UIModalPresentationStyle) {
    UIModalPresentationFullScreen = 0, UIModalPresentationPageSheet = 1, UIModalPresentationFormSheet = 2,
    UIModalPresentationCurrentContext = 3, UIModalPresentationPopover = 6, UIModalPresentationOverFullScreen = 7,
    UIModalPresentationAutomatic = -2
};
typedef NS_ENUM(NSInteger, UIModalTransitionStyle) {
    UIModalTransitionStyleCoverVertical = 0, UIModalTransitionStyleFlipHorizontal = 1,
    UIModalTransitionStyleCrossDissolve = 2, UIModalTransitionStylePartialCurl = 3
};
typedef NS_ENUM(NSInteger, UIAlertControllerStyle) { UIAlertControllerStyleActionSheet = 0, UIAlertControllerStyleAlert = 1 };
typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
    UIAlertActionStyleDefault = 0, UIAlertActionStyleCancel = 1, UIAlertActionStyleDestructive = 2
};
typedef NS_ENUM(NSInteger, UIKeyboardType) {
    UIKeyboardTypeDefault = 0, UIKeyboardTypeASCIICapable = 1, UIKeyboardTypeNumbersAndPunctuation = 2,
    UIKeyboardTypeURL = 3, UIKeyboardTypeNumberPad = 4, UIKeyboardTypeDecimalPad = 8
};
typedef NS_ENUM(NSInteger, UIReturnKeyType) { UIReturnKeyDefault = 0, UIReturnKeyGo = 6, UIReturnKeyDone = 7 };
typedef NS_ENUM(NSInteger, UITextAutocapitalizationType) {
    UITextAutocapitalizationTypeNone = 0, UITextAutocapitalizationTypeWords = 1
};
typedef NS_ENUM(NSInteger, NSLineBreakMode) {
    NSLineBreakByWordWrapping = 0, NSLineBreakByTruncatingTail = 1, NSLineBreakByClipping = 2
};
typedef NS_ENUM(NSInteger, UIButtonType) {
    UIButtonTypeCustom = 0, UIButtonTypeSystem = 1, UIButtonTypeDetailDisclosure = 2,
    UIButtonTypeInfoLight = 3, UIButtonTypeContactAdd = 4, UIButtonTypeClose = 7
};
typedef NS_ENUM(NSInteger, UISwipeGestureRecognizerDirection) {
    UISwipeGestureRecognizerDirectionRight = 1 << 0, UISwipeGestureRecognizerDirectionLeft = 1 << 1,
    UISwipeGestureRecognizerDirectionUp = 1 << 2, UISwipeGestureRecognizerDirectionDown = 1 << 3
};
typedef NS_ENUM(NSInteger, UIGestureRecognizerState) {
    UIGestureRecognizerStatePossible = 0, UIGestureRecognizerStateBegan = 1, UIGestureRecognizerStateChanged = 2,
    UIGestureRecognizerStateEnded = 3, UIGestureRecognizerStateCancelled = 4, UIGestureRecognizerStateFailed = 5,
    UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded
};
typedef NS_ENUM(NSInteger, UIBlurEffectStyle) {
    UIBlurEffectStyleExtraLight = 1, UIBlurEffectStyleLight = 2, UIBlurEffectStyleDark = 3,
    UIBlurEffectStyleRegular = 6, UIBlurEffectStyleProminent = 7
};
typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
    UIActivityIndicatorViewStyleWhiteLarge = 2, UIActivityIndicatorViewStyleGray = 3
};
typedef NS_ENUM(NSInteger, UIProgressViewStyle) { UIProgressViewStyleDefault = 0, UIProgressViewStyleBar = 1 };
typedef NS_ENUM(NSInteger, UIScrollViewIndicatorStyle) { UIScrollViewIndicatorStyleDefault = 0 };
typedef NS_ENUM(NSInteger, UIImpactFeedbackGeneratorStyle) {
    UIImpactFeedbackGeneratorStyleLight = 0, UIImpactFeedbackGeneratorStyleMedium = 1,
    UIImpactFeedbackGeneratorStyleHeavy = 2
};
typedef NS_ENUM(NSInteger, UINotificationFeedbackType) {
    UINotificationFeedbackTypeSuccess = 0, UINotificationFeedbackTypeWarning = 1, UINotificationFeedbackTypeError = 2
};
typedef NS_ENUM(NSInteger, UIDeviceOrientation) {
    UIDeviceOrientationUnknown = 0, UIDeviceOrientationPortrait = 1, UIDeviceOrientationPortraitUpsideDown = 2,
    UIDeviceOrientationLandscapeLeft = 3, UIDeviceOrientationLandscapeRight = 4
};
typedef NS_ENUM(NSInteger, UIApplicationState) {
    UIApplicationStateActive = 0, UIApplicationStateInactive = 1, UIApplicationStateBackground = 2
};
typedef NS_ENUM(NSInteger, UIImageOrientation) { UIImageOrientationUp = 0 };
typedef NS_ENUM(NSInteger, UITouchPhase) {
    UITouchPhaseBegan = 0x1, UITouchPhaseMoved = 0x2, UITouchPhaseStationary = 0x4,
    UITouchPhaseEnded = 0x8, UITouchPhaseCancelled = 0x10
};
typedef NS_ENUM(NSInteger, UITouchType) { UITouchTypeDirect = 0, UITouchTypeIndirect = 1, UITouchTypeStylus = 2 };
typedef NS_ENUM(NSUInteger, UIFontWeight) {
    UIFontWeightUltraLight = -1.2, UIFontWeightThin = -1.1, UIFontWeightLight = -0.7, UIFontWeightRegular = 0,
    UIFontWeightMedium = 0.23, UIFontWeightSemibold = 0.3, UIFontWeightBold = 0.4,
    UIFontWeightHeavy = 0.56, UIFontWeightBlack = 0.62
};

@class UIImage, UIColor, UIFont, UIView, UIWindow, UIViewController, UITouch, UIEvent,
       UIGestureRecognizer, UILabel, UIImageView, UIButton, UISlider, UIScrollView, UIBezierPath;

@protocol UIResponder <NSObject>
@property (nonatomic, readonly, nullable) UIResponder *nextResponder;
- (BOOL)canBecomeFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)isFirstResponder;
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
@end

@interface UIResponder : NSObject <UIResponder>
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget;
@end

@interface UIColor : NSObject <NSCopying>
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (UIColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
+ (UIColor *)colorWithCGColor:(CGColorRef)cgColor;
+ (UIColor *)colorWithPatternImage:(UIImage *)image;
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;
- (BOOL)getWhite:(nullable CGFloat *)white alpha:(nullable CGFloat *)alpha;
- (BOOL)getHue:(nullable CGFloat *)hue saturation:(nullable CGFloat *)saturation
    brightness:(nullable CGFloat *)brightness alpha:(nullable CGFloat *)alpha;
- (BOOL)getRed:(nullable CGFloat *)r green:(nullable CGFloat *)g blue:(nullable CGFloat *)b alpha:(nullable CGFloat *)a;
@property (nonatomic, readonly) CGColorRef CGColor;
+ (UIColor *)blackColor; + (UIColor *)whiteColor; + (UIColor *)clearColor;
+ (UIColor *)redColor; + (UIColor *)greenColor; + (UIColor *)blueColor;
+ (UIColor *)grayColor; + (UIColor *)lightGrayColor; + (UIColor *)darkGrayColor;
+ (UIColor *)yellowColor; + (UIColor *)orangeColor; + (UIColor *)purpleColor;
+ (UIColor *)brownColor; + (UIColor *)cyanColor; + (UIColor *)magentaColor;
+ (UIColor *)systemBlueColor; + (UIColor *)systemGreenColor; + (UIColor *)systemRedColor;
+ (UIColor *)systemOrangeColor; + (UIColor *)systemYellowColor; + (UIColor *)systemPinkColor;
+ (UIColor *)systemPurpleColor; + (UIColor *)systemTealColor; + (UIColor *)systemIndigoColor;
+ (UIColor *)systemGrayColor; + (UIColor *)systemGray2Color; + (UIColor *)systemGray3Color;
+ (UIColor *)systemGray4Color; + (UIColor *)systemGray5Color; + (UIColor *)systemGray6Color;
+ (UIColor *)labelColor; + (UIColor *)secondaryLabelColor; + (UIColor *)tertiaryLabelColor;
@end

@interface UIFont : NSObject <NSCopying>
+ (UIFont *)systemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)italicSystemFontOfSize:(CGFloat)fontSize;
+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
+ (UIFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight;
+ (UIFont *)preferredFontForTextStyle:(NSString *)style;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGFloat ascender;
@property (nonatomic, readonly) CGFloat descender;
@property (nonatomic, readonly) CGFloat leading;
@property (nonatomic, readonly) CGFloat lineHeight;
- (UIFont *)fontWithSize:(CGFloat)size;
@end

typedef NS_ENUM(NSInteger, UIImageOrientation) {
    UIImageOrientationUp = 0, UIImageOrientationDown, UIImageOrientationLeft, UIImageOrientationRight,
    UIImageOrientationUpMirrored, UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored
};
@interface UIImage : NSObject <NSCopying>
+ (nullable instancetype)imageWithCGImage:(CGImageRef)cgImage;
+ (nullable instancetype)imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
- (void)drawInRect:(CGRect)rect;
- (void)drawInRect:(CGRect)rect blendMode:(NSInteger)blendMode alpha:(CGFloat)alpha;
+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)imageWithContentsOfFile:(NSString *)path;
+ (UIImage *)imageWithData:(NSData *)data;
+ (UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;
+ (UIImage *)imageByRotscribing_shim;
- (instancetype)initWithContentsOfFile:(NSString *)path;
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) UIImageOrientation imageOrientation;
@property (nonatomic, readonly) CGImageRef CGImage;
@end

UIKIT_EXTERN NSData *UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality);
UIKIT_EXTERN NSData *UIImagePNGRepresentation(UIImage *image);
UIKIT_EXTERN void UIGraphicsBeginImageContext(CGSize size);
UIKIT_EXTERN void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
UIKIT_EXTERN UIImage *UIGraphicsGetImageFromCurrentImageContext(void);
UIKIT_EXTERN void UIGraphicsEndImageContext(void);
UIKIT_EXTERN CGContextRef UIGraphicsGetCurrentContext(void);
UIKIT_EXTERN void UIGraphicsPushContext(CGContextRef context);
UIKIT_EXTERN void UIGraphicsPopContext(void);
UIKIT_EXTERN void UIRectFill(CGRect rect);
UIKIT_EXTERN void UIRectFrame(CGRect rect);
UIKIT_EXTERN void UIRectFillUsingBlendMode(CGRect rect, CGBlendMode mode);
UIKIT_EXTERN CGRect CGRectInset_unused_shim(void);

@interface UIBezierPath : NSObject <NSCopying>
+ (UIBezierPath *)bezierPath;
+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)radii;
+ (UIBezierPath *)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius
    startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)addCurveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)cp1 controlPoint2:(CGPoint)cp2;
- (void)addQuadCurveToPoint:(CGPoint)endPoint controlPoint:(CGPoint)controlPoint;
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle
    endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)appendPath:(UIBezierPath *)bezierPath;
- (void)closePath;
- (void)setLineDash:(const CGFloat *)pattern count:(NSInteger)count phase:(CGFloat)phase;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic) CGLineCap lineCapStyle;
@property (nonatomic) CGLineJoin lineJoinStyle;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, readonly) CGPathRef CGPath;
@end

@interface UIView : UIResponder <NSCoding>
+ (Class)layerClass;
- (instancetype)initWithCoder:(NSCoder *)coder;
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)init;
@property (nonatomic) CGRect frame;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) BOOL opaque;
@property (nonatomic) CGFloat alpha;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, getter=isMultipleTouchEnabled) BOOL multipleTouchEnabled;
@property (nonatomic, getter=isExclusiveTouch) BOOL exclusiveTouch;
@property (nonatomic) NSInteger tag;
@property (nonatomic, strong, nullable) UIView *superview;
@property (nonatomic, copy, readonly, nullable) NSArray<UIView *> *subviews;
@property (nonatomic, strong, nullable) CALayer *layer;
@property (nonatomic, copy, nullable) NSString *accessibilityLabel;
@property (nonatomic, strong, nullable) UIColor *backgroundColor;
@property (nonatomic) UIViewContentMode contentMode;
@property (nonatomic) UIViewAutoresizing autoresizingMask;
@property (nonatomic) UIViewTintAdjustmentMode tintAdjustmentMode;
@property (nonatomic, copy, nullable) UIColor *tintColor;
@property (nonatomic) UIEdgeInsets layoutMargins;
@property (nonatomic, readonly) BOOL canBecomeFirstResponder;
- (void)setNeedsDisplay;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (void)layoutSubviews;
- (void)sizeToFit;
- (void)drawRect:(CGRect)rect;
- (CGPoint)convertPoint:(CGPoint)point toView:(nullable UIView *)view;
- (CGPoint)convertPoint:(CGPoint)point fromView:(nullable UIView *)view;
- (CGRect)convertRect:(CGRect)rect toView:(nullable UIView *)view;
- (CGRect)convertRect:(CGRect)rect fromView:(nullable UIView *)view;
- (nullable UIView *)hitTest:(CGPoint)point withEvent:(nullable UIEvent *)event;
- (void)addSubview:(UIView *)view;
- (void)insertSubview:(UIView *)view aboveSubview:(UIView *)siblingSubview;
- (void)insertSubview:(UIView *)view belowSubview:(UIView *)siblingSubview;
- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index;
- (void)exchangeSubviewAtIndex:(NSInteger)index1 withSubviewAtIndex:(NSInteger)index2;
- (void)removeFromSuperview;
- (void)bringSubviewToFront:(UIView *)view;
- (void)sendSubviewToBack:(UIView *)view;
- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event;
- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)afterUpdates;
- (void)didMoveToSuperview;
- (void)didMoveToWindow;
- (void)willMoveToSuperview:(nullable UIView *)newSuperview;
- (void)willMoveToWindow:(nullable UIWindow *)newWindow;
@end

@interface UIView (CPMCoding)
- (nullable instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
@end

@interface UIView (UIViewAnimation)
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
    completion:(void (^nullable)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
    completion:(void (^nullable)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
    usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity
    options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
    completion:(void (^nullable)(BOOL finished))completion;
+ (void)transitionWithView:(UIView *)view duration:(NSTimeInterval)duration
    options:(UIViewAnimationOptions)options animations:(void (^nullable)(void))animations
    completion:(void (^nullable)(BOOL finished))completion;
+ (void)transitionFromView:(UIView *)fromView toView:(UIView *)toView duration:(NSTimeInterval)duration
    options:(UIViewAnimationOptions)options completion:(void (^nullable)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;
@end

@interface UIImageView : UIView
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic, strong, nullable) UIImage *highlightedImage;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@end

@interface UILabel : UIView
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, strong, nullable) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) NSWritingDirection writingDirection;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic, strong, nullable) UIColor *highlightedTextColor;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end

@interface UIControl : UIView
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
- (void)addTarget:(nullable id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action forControlEvents:(UIControlEvents)controlEvents;
- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents;
@end

@interface UIButton : UIControl
+ (UIButton *)buttonWithType:(UIButtonType)type;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UIImageView *imageView;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic) UIEdgeInsets contentEdgeInsets;
@property (nonatomic) UIEdgeInsets titleEdgeInsets;
@property (nonatomic) UIEdgeInsets imageEdgeInsets;
@property (nonatomic) BOOL adjustsImageWhenHighlighted;
@property (nonatomic) BOOL adjustsImageWhenDisabled;
- (void)setTitle:(nullable NSString *)title forState:(UIControlState)state;
- (void)setTitleColor:(nullable UIColor *)color forState:(UIControlState)state;
- (void)setImage:(nullable UIImage *)image forState:(UIControlState)state;
- (void)setBackgroundImage:(nullable UIImage *)image forState:(UIControlState)state;
- (nullable NSString *)titleForState:(UIControlState)state;
- (nullable UIImage *)imageForState:(UIControlState)state;
@end

@interface UISlider : UIControl
@property (nonatomic) float value;
@property (nonatomic) float minimumValue;
@property (nonatomic) float maximumValue;
- (void)setValue:(float)value animated:(BOOL)animated;
@property (nonatomic, strong, nullable) UIColor *minimumTrackTintColor;
@property (nonatomic, strong, nullable) UIColor *maximumTrackTintColor;
@property (nonatomic, strong, nullable) UIColor *thumbTintColor;
@end

@interface UIProgressView : UIView
@property (nonatomic) float progress;
@property (nonatomic, strong, nullable) UIColor *progressTintColor;
@property (nonatomic, strong, nullable) UIColor *trackTintColor;
@property (nonatomic) UIProgressViewStyle progressViewStyle;
- (void)setProgress:(float)progress animated:(BOOL)animated;
@end

@interface UIActivityIndicatorView : UIView
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;
@end

@interface UIScrollView : UIView
@property (nonatomic) CGPoint contentOffset;
@property (nonatomic) CGSize contentSize;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) BOOL scrollEnabled;
@property (nonatomic) BOOL pagingEnabled;
@property (nonatomic) BOOL bounces;
@property (nonatomic) BOOL delaysContentTouches;
@property (nonatomic) BOOL canCancelContentTouches;
@property (nonatomic) BOOL showsVerticalScrollIndicator;
@property (nonatomic) BOOL showsHorizontalScrollIndicator;
@property (nonatomic) BOOL alwaysBounceVertical;
@property (nonatomic) BOOL alwaysBounceHorizontal;
@property (nonatomic) CGFloat zoomScale;
@property (nonatomic) CGFloat minimumZoomScale;
@property (nonatomic) CGFloat maximumZoomScale;
- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated;
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated;
@property (nonatomic) NSInteger indicatorStyle;     /* UIScrollViewIndicatorStyle */
@property (nonatomic) BOOL drawsAsynchronously;
@property (nonatomic) BOOL keyboardDismissMode;
@end

typedef NS_ENUM(NSInteger, UILayoutConstraintAxis) { UILayoutConstraintAxisHorizontal = 0, UILayoutConstraintAxisVertical = 1 };
typedef NS_ENUM(NSInteger, UIStackViewAlignment) { UIStackViewAlignmentFill = 0, UIStackViewAlignmentLeading, UIStackViewAlignmentFirstBaseline, UIStackViewAlignmentCenter, UIStackViewAlignmentTrailing, UIStackViewAlignmentLastBaseline };
typedef NS_ENUM(NSInteger, UIStackViewDistribution) { UIStackViewDistributionFill = 0, UIStackViewDistributionFillEqually, UIStackViewDistributionFillProportionally, UIStackViewDistributionEqualSpacing, UIStackViewDistributionEqualCentering };

@interface UIStackView : UIView
@property (nonatomic) UILayoutConstraintAxis axis;
@property (nonatomic) CGFloat spacing;
@property (nonatomic) UIStackViewAlignment alignment;
@property (nonatomic) UIStackViewDistribution distribution;
@property (nonatomic) BOOL layoutMarginsRelativeArrangement;
@property (nonatomic) UIEdgeInsets layoutMargins;
@property (nonatomic, copy) NSArray<UIView *> *arrangedSubviews;
- (void)addArrangedSubview:(UIView *)view;
- (void)removeArrangedSubview:(UIView *)view;
@end

typedef NS_ENUM(NSInteger, UISegmentedControlStyle) { UISegmentedControlStylePlain = 0, UISegmentedControlStyleBar = 1 };
@interface UISegmentedControl : UIControl
- (instancetype)initWithItems:(nullable NSArray *)items;
@property (nonatomic) NSInteger selectedSegmentIndex;
@property (nonatomic) UISegmentedControlStyle segmentControlStyle;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic, strong, nullable) UIColor *onTintColor;
@property (nonatomic, strong, nullable) UIColor *selectedSegmentTintColor API_AVAILABLE(ios(13.0));
@property (nonatomic, getter=isMomentary) BOOL momentary;
- (NSInteger)numberOfSegments;
- (void)setTitle:(nullable NSString *)title forSegmentAtIndex:(NSUInteger)segment;
- (nullable NSString *)titleForSegmentAtIndex:(NSUInteger)segment;
- (void)setImage:(nullable UIImage *)image forSegmentAtIndex:(NSUInteger)segment;
- (void)removeSegmentAtIndex:(NSUInteger)segment animated:(BOOL)animated;
- (void)insertSegmentWithTitle:(nullable NSString *)title atSegment:(NSUInteger)segment animated:(BOOL)animated;
- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)segment;
- (void)setTitleTextAttributes:(nullable NSDictionary *)attributes forState:(UIControlState)state;
@end

@interface UITextField : UIControl
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSString *placeholder;
@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, strong, nullable) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) BOOL secureTextEntry;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic, weak, nullable) id delegate;
@end

@interface UISwitch : UIControl
@property (nonatomic, getter=isOn) BOOL on;
@property (nonatomic, strong, nullable) UIColor *onTintColor;
@property (nonatomic, strong, nullable) UIColor *thumbTintColor;
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic, copy, nullable) NSString *accessibilityLabel;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
- (void)setTitle:(nullable NSString *)title forOffState:(NSInteger)state API_DEPRECATED("", ios(15.0, 100.0));
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@interface UIVisualEffect : NSObject
@end
@interface UIBlurEffect : UIVisualEffect
+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style;
@end
@interface UIVisualEffectView : UIView
- (instancetype)initWithEffect:(nullable UIVisualEffect *)effect;
@property (nonatomic, strong, readonly) UIVisualEffect *effect;
@property (nonatomic, strong, readonly) UIView *contentView;
@end

@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other;
@end

@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, weak, readonly, nullable) UIView *view;
@property (nonatomic, weak, nullable) id<UIGestureRecognizerDelegate> delegate;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nonatomic) BOOL delaysTouchesBegan;
@property (nonatomic) BOOL delaysTouchesEnded;
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other;
- (CGPoint)locationInView:(nullable UIView *)view;
@end

@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
@property (nonatomic, readonly) NSUInteger numberOfTouches;
@property (nonatomic) NSUInteger minimumNumberOfTouches;
@property (nonatomic) NSUInteger maximumNumberOfTouches;
- (CGPoint)translationInView:(nullable UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(nullable UIView *)view;
- (CGPoint)velocityInView:(nullable UIView *)view;
@end

@interface UIPinchGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat scale;   /* readwrite in the real SDK (gesture resolvers set it) */
@property (nonatomic, readonly) CGFloat velocity;
@property (nonatomic, readonly) NSUInteger numberOfTouches;
@end

@interface UIRotationGestureRecognizer : UIGestureRecognizer
@property (nonatomic) CGFloat rotation;
@property (nonatomic, readonly) CGFloat velocity;
@end

@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@end

@interface UISwipeGestureRecognizer : UIGestureRecognizer
@property (nonatomic) UISwipeGestureRecognizerDirection direction;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end

@interface UIScreenEdgePanGestureRecognizer : UIPanGestureRecognizer
@property (nonatomic) UIRectEdge edges;
@end

@interface UITouch : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly, strong, nullable) UIWindow *window;
@property (nonatomic, readonly, strong, nullable) UIView *view;
@property (nonatomic, readonly) UITouchType type;
- (CGPoint)locationInView:(nullable UIView *)view;
- (CGPoint)previousLocationInView:(nullable UIView *)view;
@end

@interface UIEvent : NSObject
- (NSSet<UITouch *> *)allTouches;
- (nullable NSSet<UITouch *> *)touchesForView:(nullable UIView *)view;
- (nullable NSSet<UITouch *> *)touchesForWindow:(nullable UIWindow *)window;
- (nullable NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@end

@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat nativeScale;
@property (nonatomic, readonly) CGRect nativeBounds;
@property (nonatomic, readonly) NSInteger maximumFramesPerSecond;
@end

typedef NS_ENUM(NSInteger, UISceneActivationState) {
    UISceneActivationStateUnattached = -1,
    UISceneActivationStateForegroundActive = 0,
    UISceneActivationStateForegroundInactive = 1,
    UISceneActivationStateBackground = 2,
};
@interface UIWindowSceneGeometry : NSObject
@end
@protocol UICoordinateSpace <NSObject>
@property (nonatomic, readonly) CGAffineTransform identityTransform;
@property (nonatomic, readonly) CGRect bounds;
@end
@interface UICoordinateSpace : NSObject <UICoordinateSpace>
@property (nonatomic, readonly) CGRect bounds;
@end
@interface UIWindowScene : UIResponder
@property (nonatomic, readonly) NSString *identifier;
- (NSArray<__kindof UIWindow *> *)windows;
@property (nonatomic, readonly) NSInteger interfaceOrientation;
@property (nonatomic, readonly) NSInteger activationState;
@property (nonatomic, readonly, nullable) id<UICoordinateSpace> coordinateSpace;
@property (nonatomic, readonly, nullable) UIWindowSceneGeometry *geometry API_AVAILABLE(ios(13.0));
@property (nonatomic, readonly, nullable) UIWindow *keyWindow API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@end

@interface UIWindow : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene API_AVAILABLE(ios(13.0));
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@property (nonatomic) UIWindowLevel windowLevel;
@property (nonatomic, readonly, getter=isKeyWindow) BOOL keyWindow;
@property (nonatomic, strong, nullable) UIViewController *rootViewController;
@property (nonatomic, strong, nullable) UIScreen *screen;
@property (nonatomic, strong, nullable) UIWindowScene *windowScene API_AVAILABLE(ios(13.0));
- (void)makeKeyWindow;
- (void)makeKeyAndVisible;
- (void)orderFront:(BOOL)above;
- (void)orderBack:(BOOL)below;
- (void)resignKey;
@end

@interface UIScene : NSObject
@end

@interface UITextView : UIScrollView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong, nullable) UIFont *font;
@property (nonatomic, strong, nullable) UIColor *textColor;
@property (nonatomic, strong, nullable) UIColor *backgroundColor;
@property (nonatomic) BOOL editable;
@property (nonatomic, getter=isSelectable) BOOL selectable;
@property (nonatomic) UIEdgeInsets textContainerInset;
@property (nonatomic, weak, nullable) id delegate;
- (void)scrollRangeToVisible:(NSRange)range;
@end

@interface UIGraphicsImageRendererFormat : NSObject
+ (instancetype)defaultFormat;
@property (nonatomic) CGFloat scale;
@property (nonatomic) BOOL opaque;
@end

@class UIGraphicsImageRendererContext;
@interface UIGraphicsImageRendererContext : NSObject
@property (nonatomic, readonly) CGContextRef CGContext;
@property (nonatomic, readonly, strong) UIGraphicsImageRendererFormat *rendererFormat;
@end
@interface UIGraphicsImageRenderer : NSObject
- (instancetype)initWithBounds:(CGRect)bounds;
- (instancetype)initWithSize:(CGSize)size;
- (instancetype)initWithBounds:(CGRect)bounds format:(nullable UIGraphicsImageRendererFormat *)format;
- (instancetype)initWithSize:(CGSize)size format:(nullable UIGraphicsImageRendererFormat *)format;
- (UIImage *)imageWithActions:(void (^)(UIGraphicsImageRendererContext *rendererContext))actions;
- (UIImage *)image:(void (^)(UIGraphicsImageRendererContext *rendererContext))actions;
@end

@interface UIViewController : UIResponder
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong, readonly, nullable) UIView *viewIfLoaded API_AVAILABLE(ios(13.0));
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, strong, readonly, nullable) UIViewController *parentViewController;
@property (nonatomic, strong, readonly, nullable) UIViewController *presentingViewController;
@property (nonatomic, strong, readonly, nullable) UIViewController *presentedViewController;
@property (nonatomic, copy) NSArray<UIViewController *> *childViewControllers;
@property (nonatomic, readonly, getter=isViewLoaded) BOOL viewLoaded;
@property (nonatomic) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic) UIModalTransitionStyle modalTransitionStyle;
@property (nonatomic) CGSize preferredContentSize;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@property (nonatomic, readonly) UIWindow *viewWindow;
@property (nonatomic, readonly, nullable) UIWindow *window;
@property (nonatomic, readonly) UIScreen *screen;
- (void)loadView;
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (void)presentViewController:(UIViewController *)toPresent animated:(BOOL)flag completion:(void (^nullable)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^nullable)(void))completion;
- (void)addChildViewController:(UIViewController *)childController;
- (void)removeFromParentViewController;
- (void)didMoveToParentViewController:(nullable UIViewController *)parent;
- (void)willMoveToParentViewController:(nullable UIViewController *)parent;
- (void)setNeedsStatusBarAppearanceUpdate;
- (BOOL)prefersStatusBarHidden;
- (UIStatusBarStyle)preferredStatusBarStyle;
- (BOOL)prefersHomeIndicatorAutoHidden;
@end

@interface UIAlertController : UIViewController
+ (UIAlertController *)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message
    preferredStyle:(UIAlertControllerStyle)preferredStyle;
- (void)addAction:(UIAlertAction *)action;
- (void)addTextFieldWithConfigurationHandler:(void (^nullable)(UITextField *textField))configurationHandler;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, readonly, copy) NSArray<UIAlertAction *> *actions;
@property (nonatomic, readonly, copy) NSArray<UITextField *> *textFields;
@property (nonatomic, readonly) UIAlertControllerStyle preferredStyle;
@end

@interface UIAlertAction : NSObject <NSCopying>
+ (UIAlertAction *)actionWithTitle:(nullable NSString *)title style:(UIAlertActionStyle)style
    handler:(void (^nullable)(UIAlertAction *action))handler;
@property (nonatomic) BOOL enabled;
@end

typedef NS_ENUM(NSInteger, UIImpactFeedbackStyle) { UIImpactFeedbackStyleLight = 0, UIImpactFeedbackStyleMedium = 1, UIImpactFeedbackStyleHeavy = 2 };
@interface UIImpactFeedbackGenerator : NSObject
- (instancetype)initWithStyle:(UIImpactFeedbackGeneratorStyle)style;
- (void)impactOccurred;
- (void)prepare;
@end

@interface UINotificationFeedbackGenerator : NSObject
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;
- (void)prepare;
@end

@interface UIDevice : NSObject
+ (UIDevice *)currentDevice;
@property (nonatomic, readonly) NSString *model;
@property (nonatomic, readonly) NSString *systemName;
@property (nonatomic, readonly) NSString *systemVersion;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) UIDeviceOrientation orientation;
@property (nonatomic, getter=isOrientationEnabled) BOOL orientationEnabled;
- (void)beginGeneratingDeviceOrientationNotifications;
- (void)endGeneratingDeviceOrientationNotifications;
@end

@protocol UIApplicationDelegate <NSObject>
@end

OBJC_EXPORT NSString * const UIApplicationDidEnterBackgroundNotification;
OBJC_EXPORT NSString * const UIApplicationWillEnterForegroundNotification;
OBJC_EXPORT NSString * const UIApplicationDidBecomeActiveNotification;
OBJC_EXPORT NSString * const UIApplicationDidChangeStatusBarOrientationNotification;
OBJC_EXPORT NSString * const UISceneDidActivateNotification;
OBJC_EXPORT NSString * const UISceneWillDeactivateNotification;
OBJC_EXPORT NSString * const UISceneDidConnectToSessionNotification;

OBJC_EXPORT NSString * const UIApplicationWillFinishLaunchingNotification;
OBJC_EXPORT NSString * const UIApplicationDidFinishLaunchingNotification;
OBJC_EXPORT NSString * const UIApplicationWillTerminateNotification;
OBJC_EXPORT NSString * const UIApplicationWillResignActiveNotification;
OBJC_EXPORT NSString * const UIApplicationDidChangeStatusBarFrameNotification;
OBJC_EXPORT NSString * const UISceneWillEnterForegroundNotification;
OBJC_EXPORT NSString * const UISceneDidEnterBackgroundNotification;

@interface UIApplication : NSObject
@property (nonatomic, weak, nullable) id<UIApplicationDelegate> delegate;
+ (UIApplication *)sharedApplication;
@property (nonatomic, readonly, strong, nullable) UIWindow *keyWindow;
@property (nonatomic, readonly, copy) NSArray<UIWindow *> *windows;
@property (nonatomic, readonly, copy) NSSet<id> *connectedScenes;
@property (nonatomic, readonly) UIApplicationState applicationState;
@property (nonatomic, getter=isIdleTimerDisabled) BOOL idleTimerDisabled;
- (BOOL)sendEvent:(UIEvent *)event;
- (void)openURL:(NSURL *)url;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^nullable)(BOOL success))completion;
- (CGRect)statusBarFrame;
@end

UIKIT_EXTERN UIApplication *UIApplicationShim(void);

@interface UIPasteboard : NSObject
+ (instancetype)generalPasteboard;
@property (nonatomic, copy, nullable) UIImage *image;
@property (nonatomic, copy, nullable) NSString *string;
@property (nonatomic, copy, readonly, nullable) NSArray<UIImage *> *images;
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *strings;
@end

#define UIScreenMainScreen ([UIScreen mainScreen])

@interface UIView (CPMCompat)
- (nullable __kindof UIView *)viewWithTag:(NSInteger)tag;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@property (nonatomic) BOOL clipsToBounds;
@property (nonatomic, readonly, nullable) UIWindow *window;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@interface UIResponder (CPMTouches)
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
@end
#endif /* _CPMSTUB_UIKIT_H */
