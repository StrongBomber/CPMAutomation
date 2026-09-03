/* Minimal QuartzCore for the offline type-check harness. */
#ifndef _CPMSTUB_QUARTZCORE_H
#define _CPMSTUB_QUARTZCORE_H
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct CATransform3D {
    CGFloat m11, m12, m13, m14;
    CGFloat m21, m22, m23, m24;
    CGFloat m31, m32, m33, m34;
    CGFloat m41, m42, m43, m44;
} CATransform3D;

extern const CATransform3D CATransform3DIdentity;
CATransform3D CATransform3DMakeTranslation(CGFloat tx, CGFloat ty, CGFloat tz);
CATransform3D CATransform3DMakeScale(CGFloat sx, CGFloat sy, CGFloat sz);
CATransform3D CATransform3DMakeRotation(CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
CATransform3D CATransform3DTranslate(CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz);
CATransform3D CATransform3DScale(CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz);
CATransform3D CATransform3DRotate(CATransform3D t, CGFloat angle, CGFloat x, CGFloat y, CGFloat z);
CATransform3D CATransform3DConcat(CATransform3D a, CATransform3D b);
CATransform3D CATransform3DInvert(CATransform3D t);
bool CATransform3DIsIdentity(CATransform3D t);
bool CATransform3DEqualToTransform(CATransform3D a, CATransform3D b);
CGPoint CATransform3DApplyPoint_shim(void);

extern NSString *const kCAGravityCenter;
extern NSString *const kCAGravityTopLeft;
extern NSString *const kCAGravityTop;
extern NSString *const kCAGravityTopRight;
extern NSString *const kCAGravityLeft;
extern NSString *const kCAGravityRight;
extern NSString *const kCAGravityBottomLeft;
extern NSString *const kCAGravityBottom;
extern NSString *const kCAGravityBottomRight;
extern NSString *const kCAGravityResize;
extern NSString *const kCAGravityResizeAspect;
extern NSString *const kCAGravityResizeAspectFill;
extern NSString *const kCATransactionAnimationDisableActions;
extern NSString *const kCAOnImage;

@interface CAAnimation : NSObject <NSCopying>
@property (nonatomic, copy) NSString *name;
@property (nonatomic) CFTimeInterval beginTime;
@property (nonatomic) CFTimeInterval duration;
@property (nonatomic) CFTimeInterval timeOffset;
@property (nonatomic) float repeatCount;
@property (nonatomic) float repeatDuration;
@property (nonatomic, getter=isAutoReversed) BOOL autoReversed;
@property (nonatomic) float speed;
@property (nonatomic, getter=isRemovedOnCompletion) BOOL removedOnCompletion;
@property (nonatomic, retain, nullable) CAMediaTimingFunction *timingFunction;
@property (nonatomic, assign) id delegate;
@property (nonatomic, copy) NSString *fillMode;
@end

@interface CAMediaTimingFunction : NSObject <NSCopying>
+ (instancetype)functionWithName:(NSString *)name;
+ (instancetype)functionWithControlPoints:(Float)c1x :(Float)c1y :(Float)c2x :(Float)c2y;
@end
extern NSString *const kCAMediaTimingFunctionDefault;
extern NSString *const kCAMediaTimingFunctionLinear;
extern NSString *const kCAMediaTimingFunctionEaseIn;
extern NSString *const kCAMediaTimingFunctionEaseOut;
extern NSString *const kCAMediaTimingFunctionEaseInEaseOut;

@interface CABasicAnimation : CAAnimation
+ (instancetype)animationWithKeyPath:(nullable NSString *)path;
@property (nonatomic, retain) id keyPath;
@property (nonatomic, retain) id fromValue;
@property (nonatomic, retain) id toValue;
@property (nonatomic, retain) id byValue;
@end

@interface CAAnimationGroup : CAAnimation
@property (nonatomic, copy) NSArray<CAAnimation *> *animations;
@end

@interface CAKeyframeAnimation : CAAnimation
@property (nonatomic, copy) NSArray *values;
@property (nonatomic, copy) NSArray<NSNumber *> *keyTimes;
@property (nonatomic, copy) NSString *calculationMode;
@end

@interface CALayer : NSObject
@property (nonatomic) BOOL drawsAsynchronously; <NSCopying>
+ (id)layer;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGPoint position;
@property (nonatomic) CGFloat zPosition;
@property (nonatomic) CGPoint anchorPoint;
@property (nonatomic) CGFloat anchorPointZ;
@property (nonatomic) CGAffineTransform affineTransform;
@property (nonatomic) CATransform3D transform;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, readonly) CALayer *superlayer;
@property (nonatomic, copy) NSArray<CALayer *> *sublayers;
@property (nonatomic) BOOL hidden;
@property (nonatomic) CGFloat opacity;
@property (nonatomic, copy) NSArray *filters;
@property (nonatomic, copy) id minificationFilter;
@property (nonatomic, copy) id magnificationFilter;
@property (nonatomic, copy) NSArray *backgroundFilters;
@property (nonatomic) BOOL allowsOpacity;
@property (nonatomic) BOOL allowsGroupOpacity;
@property (nonatomic) BOOL allowsEdgeAntialiasing;
@property (nonatomic) unsigned edgeAntialiasingMask;
@property (nonatomic) BOOL needsDisplayOnBoundsChange;
@property (nonatomic, retain) id contents;
@property (nonatomic, copy) NSString *contentsGravity;
@property (nonatomic) CGFloat contentsScale;
@property (nonatomic) CGInterpolationQuality contentsInterpolationQuality;
@property (nonatomic) CGRect contentsRect;
@property (nonatomic, copy) CGColorRef backgroundColor;
@property (nonatomic) CGFloat borderWidth;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic, copy) CGColorRef borderColor;
@property (nonatomic, copy) id compositingFilter;
@property (nonatomic) BOOL shouldRasterize;
@property (nonatomic) CGFloat rasterizationScale;
@property (nonatomic, copy) CGColorRef shadowColor;
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic) CGFloat shadowOpacity;
@property (nonatomic) CGFloat shadowRadius;
@property (nonatomic, copy) CGPathRef shadowPath;
@property (nonatomic, getter=isOpaque) BOOL opaque;
@property (nonatomic) BOOL masksToBounds;
@property (nonatomic) BOOL geometryFlipped;
@property (nonatomic, strong) CALayer *mask;
- (void)setNeedsDisplay;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (void)display;
- (void)addSublayer:(CALayer *)layer;
- (void)insertSublayer:(CALayer *)layer at:(unsigned)index;
- (void)insertSublayer:(CALayer *)layer below:(nullable CALayer *)sibling;
- (void)insertSublayer:(CALayer *)layer above:(nullable CALayer *)sibling;
- (void)removeFromSuperlayer;
- (void)addAnimation:(CAAnimation *)anim forKey:(nullable NSString *)key;
- (void)removeAnimationForKey:(NSString *)key;
- (void)removeAllAnimations;
- (nullable CAAnimation *)animationForKey:(NSString *)key;
- (void)renderInContext:(CGContextRef)ctx;
- (CGPoint)convertPoint:(CGPoint)point fromLayer:(nullable CALayer *)l;
- (CGPoint)convertPoint:(CGPoint)point toLayer:(nullable CALayer *)l;
- (CGRect)convertRect:(CGRect)rect fromLayer:(nullable CALayer *)l;
- (CGRect)convertRect:(CGRect)rect toLayer:(nullable CALayer *)l;
- (nullable CALayer *)hitTest:(CGPoint)point;
+ (CFTimeInterval)beginTimeFromCurrentTime:(CFTimeInterval)currentTime;
@end

@interface CALayer (CPMCompat)
@property (nonatomic) CGRect frame;
@end

typedef struct { double a, b, c, d, tx, ty; } CACornerRadiiShim;
enum {
    kCALayerMinXMinYCorner = 1U << 0,
    kCALayerMaxXMinYCorner = 1U << 1,
    kCALayerMinXMaxYCorner = 1U << 2,
    kCALayerMaxXMaxYCorner = 1U << 3,
};
@interface CALayer (CPMCompat)
@property (nonatomic) NSUInteger maskedCorners;
@end

@interface CAShapeLayer : CALayer
@property (nonatomic, copy) CGPathRef path;
@property (nonatomic, copy) CGColorRef fillColor;
@property (nonatomic, copy) NSString *fillRule;
@property (nonatomic, copy) CGColorRef strokeColor;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat miterLimit;
@property (nonatomic) CGLineCap lineCap;
@property (nonatomic) CGLineJoin lineJoin;
@property (nonatomic, copy) NSArray<NSNumber *> *lineDashPattern;
@property (nonatomic) CGFloat lineDashPhase;
@end

@interface CATextLayer : CALayer
@property (nonatomic, copy) id string;
@property (nonatomic, retain) id font;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic, copy) CGColorRef foregroundColor;
@end

@interface CAGradientLayer : CALayer
@property (nonatomic, copy) NSArray *colors;
@property (nonatomic, copy) NSArray<NSNumber *> *locations;
@property (nonatomic) CGPoint startPoint;
@property (nonatomic) CGPoint endPoint;
@end

@interface CATransaction : NSObject
+ (void)begin;
+ (void)commit;
+ (void)setDisableActions:(BOOL)flag;
+ (void)setCompletionBlock:(void (^)(void))block;
@end

#endif /* _CPMSTUB_QUARTZCORE_H */
