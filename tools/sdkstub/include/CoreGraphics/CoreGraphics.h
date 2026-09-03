/* Minimal CoreGraphics for the offline type-check harness. */
#ifndef _CPMSTUB_CG_H
#define _CPMSTUB_CG_H
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#define CG_EXTERN extern
#define CG_AVAILABLE(...)
#define CG_CLASS_AVAILABLE(...)
#define CGFloat double
#define CGFLOAT_MIN 2.2250738585072014e-308
#define CGFLOAT_MAX 1.7976931348623157e308
#define CGFLOAT_TYPE double
typedef CGFloat Float;

typedef struct CGPoint { CGFloat x; CGFloat y; } CGPoint;
typedef struct CGSize { CGFloat width; CGFloat height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;
typedef struct CGVector { CGFloat dx; CGFloat dy; } CGVector;
typedef struct CGAffineTransform { CGFloat a, b, c, d, tx, ty; } CGAffineTransform;
extern const CGAffineTransform CGAffineTransformIdentity;

static const CGPoint CGPointZero = {0.0, 0.0};
static const CGSize CGSizeZero = {0.0, 0.0};
static const CGRect CGRectZero = {{0.0,0.0},{0.0,0.0}};
static const CGRect CGRectNull = {{CGFLOAT_MAX, CGFLOAT_MAX},{-CGFLOAT_MAX, -CGFLOAT_MAX}};
#define CGZERO_RECT(zero) (CGRect)zero

CG_EXTERN CGPoint CGPointMake(CGFloat x, CGFloat y);
CG_EXTERN CGSize CGSizeMake(CGFloat w, CGFloat h);
CG_EXTERN CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h);
CG_EXTERN CGFloat CGRectGetMidX(CGRect r);
CG_EXTERN CGFloat CGRectGetMidY(CGRect r);
CG_EXTERN CGFloat CGRectGetMinX(CGRect r);
CG_EXTERN CGFloat CGRectGetMaxX(CGRect r);
CG_EXTERN CGFloat CGRectGetMinY(CGRect r);
CG_EXTERN CGFloat CGRectGetMaxY(CGRect r);
CG_EXTERN CGFloat CGRectGetWidth(CGRect r);
CG_EXTERN CGFloat CGRectGetHeight(CGRect r);
CG_EXTERN bool CGPointEqualToPoint(CGPoint a, CGPoint b);
CG_EXTERN bool CGSizeEqualToSize(CGSize a, CGSize b);
CG_EXTERN bool CGRectEqualToRect(CGRect a, CGRect b);
CG_EXTERN bool CGRectContainsPoint(CGRect r, CGPoint p);
CG_EXTERN bool CGRectContainsRect(CGRect a, CGRect b);
CG_EXTERN bool CGRectIntersectsRect(CGRect a, CGRect b);
CG_EXTERN bool CGRectIsEmpty(CGRect r);
CG_EXTERN bool CGRectIsNull(CGRect r);
CG_EXTERN bool CGRectInfinite_IsEmpty(void);
CG_EXTERN CGRect CGRectStandardize(CGRect r);
CG_EXTERN CGRect CGRectIntegral(CGRect r);
CG_EXTERN CGRect CGRectIntersection(CGRect a, CGRect b);
CG_EXTERN CGRect CGRectUnion(CGRect a, CGRect b);
CG_EXTERN CGRect CGRectInset(CGRect r, CGFloat dx, CGFloat dy);
CG_EXTERN CGRect CGRectOffset(CGRect r, CGFloat dx, CGFloat dy);
CG_EXTERN CGRect CGRectApplyAffineTransform(CGRect r, CGAffineTransform t);
CG_EXTERN const CGRect CGRectInfinite;

typedef struct __CGColor *CGColorRef;
typedef struct __CGColorSpace *CGColorSpaceRef;
typedef struct __CGImage *CGImageRef;
typedef struct __CGContext *CGContextRef;
typedef struct __CGPath *CGPathRef;
typedef struct __CGPath *CGMutablePathRef;
typedef struct __CGPattern *CGPatternRef;
typedef struct __CGGradient *CGGradientRef;
typedef struct __CGDataProvider *CGDataProviderRef;
typedef struct __CGDataConsumer *CGDataConsumerRef;

typedef uint32_t CGBitmapInfo;
typedef uint32_t CGImageAlphaInfo;
typedef uint32_t CGColorRenderingIntent;
typedef int32_t CGInterpolationQuality;
typedef uint32_t CGBlendMode;
typedef uint32_t CGLineCap;
typedef uint32_t CGLineJoin;
typedef unsigned int CGPathDrawingMode;

enum {
  kCGImageAlphaNone = 0, kCGImageAlphaPremultipliedLast = 1, kCGImageAlphaPremultipliedFirst = 2,
  kCGImageAlphaLast = 3, kCGImageAlphaFirst = 4, kCGImageAlphaNoneSkipLast = 5,
  kCGImageAlphaNoneSkipFirst = 6, kCGImageAlphaOnly = 7
};
enum {
  kCGBitmapByteOrder32Little = (2 << 12), kCGBitmapByteOrder32Big = (4 << 12),
  kCGBitmapByteOrder16Little = (1 << 12), kCGBitmapByteOrderDefault = 0
};
enum { kCGInterpolationDefault = 0, kCGInterpolationNone = 1, kCGInterpolationLow = 2,
       kCGInterpolationMedium = 4, kCGInterpolationHigh = 3 };
enum { kCGBlendModeNormal = 0, kCGBlendModeMultiply = 1, kCGBlendModeScreen = 2,
       kCGBlendModeOverlay = 3, kCGBlendModeClear = 0, kCGBlendModeCopy = 10,
       kCGBlendModeSourceIn = 14, kCGBlendModeDestinationIn = 22 };
enum { kCGLineCapButt = 0, kCGLineCapRound = 1, kCGLineCapSquare = 2 };
enum { kCGLineJoinMiter = 0, kCGLineJoinRound = 1, kCGLineJoinBevel = 2 };
enum { kCGRenderingIntentDefault = 0, kCGRenderingIntentAbsoluteColorimetric = 1 };
enum { kCGPathFill = 0, kCGPathEOFill = 1, kCGPathStroke = 2, kCGPathFillStroke = 3 };

CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceRGB(void);
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateDeviceGray(void);
CG_EXTERN CGColorSpaceRef CGColorSpaceCreateWithName(const char *name);
CG_EXTERN void CGColorSpaceRelease(CGColorSpaceRef cs);
CG_EXTERN CFIndex CGColorSpaceGetNumberOfComponents(CGColorSpaceRef cs);
#define kCGColorSpaceSRGB "kCGColorSpaceSRGB"

CG_EXTERN CGContextRef CGBitmapContextCreate(void *data, size_t width, size_t height, size_t bitsPerComponent,
    size_t bytesPerRow, CGColorSpaceRef space, CGBitmapInfo bitmapInfo);
CG_EXTERN CGContextRef CGBitmapContextCreateImage_(void);
CG_EXTERN void CGContextRelease(CGContextRef c);
CG_EXTERN void CGContextRetain(CGContextRef c);
CG_EXTERN void CGContextDrawImage(CGContextRef c, CGRect rect, CGImageRef image);
CG_EXTERN void CGContextDrawTiledImage(CGContextRef c, CGRect rect, CGImageRef image);
CG_EXTERN void CGContextSetFillColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetStrokeColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetRGBFillColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetRGBStrokeColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetLineWidth(CGContextRef c, CGFloat w);
CG_EXTERN void CGContextSetLineCap(CGContextRef c, CGLineCap cap);
CG_EXTERN void CGContextSetLineJoin(CGContextRef c, CGLineJoin join);
CG_EXTERN void CGContextSetLineDash(CGContextRef c, CGFloat phase, const CGFloat lengths[], size_t count);
CG_EXTERN void CGContextSetBlendMode(CGContextRef c, CGBlendMode mode);
CG_EXTERN void CGContextSetInterpolationQuality(CGContextRef c, CGInterpolationQuality q);
CG_EXTERN void CGContextSetShouldAntialias(CGContextRef c, bool flag);
CG_EXTERN void CGContextBeginPath(CGContextRef c);
CG_EXTERN void CGContextClosePath(CGContextRef c);
CG_EXTERN void CGContextMoveToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddLineToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddCurveToPoint(CGContextRef c, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddQuadCurveToPoint(CGContextRef c, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddArc(CGContextRef c, CGFloat x, CGFloat y, CGFloat r, CGFloat a1, CGFloat a2, int ccw);
CG_EXTERN void CGContextAddEllipseInRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextAddRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextAddPath(CGContextRef c, CGPathRef path);
CG_EXTERN void CGContextFillPath(CGContextRef c);
CG_EXTERN void CGContextEOFillPath(CGContextRef c);
CG_EXTERN void CGContextStrokePath(CGContextRef c);
CG_EXTERN void CGContextFillRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextFillEllipseInRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextStrokeRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextStrokeRectWithWidth(CGContextRef c, CGRect rect, CGFloat w);
CG_EXTERN void CGContextClearRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextClip(CGContextRef c);
CG_EXTERN void CGContextClipToRect(CGContextRef c, CGRect rect);
CG_EXTERN void CGContextSaveGState(CGContextRef c);
CG_EXTERN void CGContextRestoreGState(CGContextRef c);
CG_EXTERN void CGContextTranslateCTM(CGContextRef c, CGFloat tx, CGFloat ty);
CG_EXTERN void CGContextScaleCTM(CGContextRef c, CGFloat sx, CGFloat sy);
CG_EXTERN void CGContextRotateCTM(CGContextRef c, CGFloat angle);
CG_EXTERN void CGContextConcatCTM(CGContextRef c, CGAffineTransform t);
CG_EXTERN CGAffineTransform CGContextGetCTM(CGContextRef c);
CG_EXTERN CGImageRef CGBitmapContextCreateImage(CGContextRef c);
CG_EXTERN size_t CGBitmapContextGetBytesPerRow(CGContextRef c);
CG_EXTERN void *CGBitmapContextGetData(CGContextRef c);

CG_EXTERN size_t CGImageGetWidth(CGImageRef image);
CG_EXTERN size_t CGImageGetHeight(CGImageRef image);
CG_EXTERN size_t CGImageGetBitsPerComponent(CGImageRef image);
CG_EXTERN size_t CGImageGetBitsPerPixel(CGImageRef image);
CG_EXTERN size_t CGImageGetBytesPerRow(CGImageRef image);
CG_EXTERN CGColorSpaceRef CGImageGetColorSpace(CGImageRef image);
CG_EXTERN CGImageAlphaInfo CGImageGetAlphaInfo(CGImageRef image);
CG_EXTERN CGBitmapInfo CGImageGetBitmapInfo(CGImageRef image);
CG_EXTERN CGDataProviderRef CGImageGetDataProvider(CGImageRef image);
CG_EXTERN CFDataRef CGDataProviderCopyData(CGDataProviderRef provider);
CG_EXTERN CGImageRef CGImageCreateWithImageInRect(CGImageRef image, CGRect rect);
CG_EXTERN void CGImageRelease(CGImageRef image);
CG_EXTERN CGImageRef CGImageCreateWithJPEGDataProvider(CGDataProviderRef provider, const CGFloat decode[], bool shouldInterpolate, CGColorRenderingIntent intent);
CG_EXTERN CGImageRef CGImageCreateWithPNGDataProvider(CGDataProviderRef provider, const CGFloat decode[], bool shouldInterpolate, CGColorRenderingIntent intent);
CG_EXTERN CGImageRef CGImageRetain(CGImageRef image);

CG_EXTERN CGColorRef CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN CGColorRef CGColorCreate(CGColorSpaceRef cs, const CGFloat comps[]);
CG_EXTERN CGColorRef CGColorCreateCopy(CGColorRef color);
CG_EXTERN CGColorRef CGColorCreateCopyWithAlpha(CGColorRef color, CGFloat alpha);
CG_EXTERN void CGColorRelease(CGColorRef color);
CG_EXTERN CGColorRef CGColorRetain(CGColorRef color);
CG_EXTERN const CGFloat *CGColorGetComponents(CGColorRef color);
CG_EXTERN size_t CGColorGetNumberOfComponents(CGColorRef color);
CG_EXTERN CGFloat CGColorGetAlpha(CGColorRef color);
CG_EXTERN CGColorSpaceRef CGColorGetColorSpace(CGColorRef color);

CG_EXTERN CGAffineTransform CGAffineTransformMake(double a, double b, double c, double d, double tx, double ty);
CG_EXTERN CGAffineTransform CGAffineTransformMakeScale(CGFloat sx, CGFloat sy);
CG_EXTERN CGAffineTransform CGAffineTransformMakeRotation(CGFloat angle);
CG_EXTERN CGAffineTransform CGAffineTransformMakeTranslation(CGFloat tx, CGFloat ty);
CG_EXTERN CGAffineTransform CGAffineTransformInvert(CGAffineTransform t);
CG_EXTERN CGAffineTransform CGAffineTransformConcat(CGAffineTransform a, CGAffineTransform b);
CG_EXTERN bool CGAffineTransformIsIdentity(CGAffineTransform t);
CG_EXTERN bool CGAffineTransformEqualToTransform(CGAffineTransform a, CGAffineTransform b);
extern const CGAffineTransform kCGIdentityTransform;

CG_EXTERN CGMutablePathRef CGPathCreateMutable(void);
CG_EXTERN void CGPathRelease(CGMutablePathRef p);
CG_EXTERN void CGPathMoveToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddLineToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddCurveToPoint(CGMutablePathRef p, const CGAffineTransform *m, CGFloat c1x, CGFloat c1y, CGFloat c2x, CGFloat c2y, CGFloat x, CGFloat y);
CG_EXTERN void CGPathAddEllipseInRect(CGMutablePathRef p, const CGAffineTransform *m, CGRect r);
CG_EXTERN void CGPathAddRect(CGMutablePathRef p, const CGAffineTransform *m, CGRect r);
CG_EXTERN void CGPathCloseSubpath(CGMutablePathRef p);
CG_EXTERN CGRect CGPathGetBoundingBox(CGPathRef p);
CG_EXTERN bool CGPathContainsPoint(CGPathRef p, const CGAffineTransform *m, CGPoint pt, bool eoFill);

CGPoint CGPointApplyAffineTransform(CGPoint point, CGAffineTransform t);
CGSize CGSizeApplyAffineTransform(CGSize size, CGAffineTransform t);
#endif
