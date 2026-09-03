#ifndef _CPMSTUB_COREIMAGE_H
#define _CPMSTUB_COREIMAGE_H
#import <UIKit/UIKit.h>

OBJC_EXPORT NSString *const kCIInputImageKey;
OBJC_EXPORT NSString *const kCIInputBackgroundImageKey;
OBJC_EXPORT NSString *const kCIInputRadiusKey;
OBJC_EXPORT NSString *const kCIInputScaleKey;
OBJC_EXPORT NSString *const kCIInputCenterKey;
OBJC_EXPORT NSString *const kCIInputAspectRatioKey;
OBJC_EXPORT NSString *const kCIInputAngleKey;
OBJC_EXPORT NSString *const kCIInputWidthKey;
OBJC_EXPORT NSString *const kCIInputColorKey;
OBJC_EXPORT NSString *const kCIContextUseSoftwareRenderer;

@interface CIVector : NSObject
+ (instancetype)vectorWithCGAffineTransform:(CGAffineTransform)t;
+ (instancetype)vectorWithX:(CGFloat)x Y:(CGFloat)y;
+ (instancetype)vectorWithValues:(const double *)values count:(NSUInteger)count;
@end

@interface CIImage : NSObject
- (nullable instancetype)initWithImage:(id)image;
- (nullable instancetype)initWithCGImage:(CGImageRef)cgImage;
- (nullable instancetype)initWithData:(id)data;
+ (instancetype)imageWithContentsOfURL:(id)url;
+ (instancetype)imageWithData:(id)data;
+ (nullable instancetype)imageWithCGImage:(CGImageRef)cgImage;
+ (nullable instancetype)imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(NSInteger)orientation;
+ (nullable instancetype)imageWithImage:(id)image;
+ (nullable instancetype)imageWithURL:(id)URL;
+ (nullable instancetype)imageWithCVPixelBuffer:(void *)buffer;
@property (nonatomic, readonly) CGRect extent;
- (instancetype)imageByApplyingTransform:(CGAffineTransform)transform;
- (instancetype)imageByCroppingToRect:(CGRect)rect;
- (instancetype)imageByCompositingOverImage:(CIImage *)image;
@end

@interface CIContext : NSObject
+ (instancetype)context;
+ (nullable instancetype)contextWithOptions:(nullable NSDictionary *)options;
- (void)drawImage:(CIImage *)image inRect:(CGRect)rect fromRect:(CGRect)fromRect;
- (nullable CGImageRef)createCGImage:(CIImage *)image fromRect:(CGRect)rect;
@end

@interface CIFilter : NSObject
+ (nullable instancetype)filterWithName:(NSString *)name;
@property (nonatomic, copy, readonly) NSString *name;
- (nullable id)defaultValueForKey:(NSString *)key;
- (void)setValue:(nullable id)value forKey:(NSString *)key;
- (nullable id)valueForKey:(NSString *)key;
- (nullable CIImage *)outputImage;
@end
#endif
