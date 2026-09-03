/**
 * CPMShapeDecomposer.h
 *
 * Image → sticker decomposition for CPM's vinyl editor.
 *
 * What it produces is a list of CPMVinylShape quads (position, size, rotation, color,
 * paint order) — the same information one StickerItem holds in the game. Pipeline, all
 * of it computed here rather than guessed by the caller:
 *
 *   1. ROI crop + color-accurate rasterization into RGBA8 (1 pt = 1 px, premultiplied
 *      alpha undone so semi-transparent edges are not darkened).
 *   2. Exact color histogram; if the artwork already has ≤ colorCount distinct colors,
 *      quantization is skipped (logo-friendly, zero color error).
 *   3. Weighted k-means (L*a*b* distance by default, with an explicit sRGB gamma step),
 *      seeded by k-means++.
 *   4. Connected components per color class (4-connectivity, two-pass union-find).
 *   5. Per-component geometry: area, centroid, bbox, Moore-traced contour,
 *      Douglas-Peucker simplification, orientation from the covariance tensor.
 *   6. Shape-type classification (circle / square / triangle / line / polygon) plus the
 *      layer-budget pass that keeps the biggest shapes when they exceed the game's limit.
 *
 * Everything runs off the main thread; -cancelDecomposition aborts between stages and
 * between components. No game state is read or written from here.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@class CPMVinylShape;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPMColorDistanceSpace) {
    /// Euclidean distance on gamma-corrected sRGB 0..1 channels (fast).
    CPMColorDistanceSpaceSRGB = 0,
    /// CIE76 ΔE in D65 Lab (slower, matches perceived differences).
    CPMColorDistanceSpaceLab = 1,
    /// Hue-chroma-weighted: keeps flat-color logos from merging two similar inks.
    CPMColorDistanceSpaceHueChroma = 2,
};

typedef NS_ENUM(NSInteger, CPMQuantizationMethod) {
    /// Exact if possible, otherwise k-means. Default.
    CPMQuantizationAuto = 0,
    CPMQuantizationKMeans = 1,
    CPMQuantizationMedianCut = 2,
};

FOUNDATION_EXPORT NSErrorDomain const CPMShapeDecomposerErrorDomain;

typedef NS_ERROR_ENUM(CPMShapeDecomposerErrorDomain, CPMShapeDecomposerError) {
    CPMShapeDecomposerErrorNoImage = 1,
    CPMShapeDecomposerErrorRasterizeFailed = 2,
    CPMShapeDecomposerErrorNoForeground = 3,
    CPMShapeDecomposerErrorROIInvalid = 4,
    CPMShapeDecomposerErrorCancelled = 5,
    CPMShapeDecomposerErrorBusy = 6,
};

@interface CPMShapeDecompositionConfig : NSObject <NSCopying>

/* Rasterization */
/// Largest side of the internal working bitmap; keeps 4K imports cheap. Default 512.
@property (nonatomic, assign) NSInteger workingMaxDimension;
/// ROI inside the *image* (pixels). CGRectNull (default) = whole image.
@property (nonatomic, assign) CGRect roiRect;
/// Alpha below this counts as background. Default 0.5.
@property (nonatomic, assign) CGFloat alphaThreshold;

/* Color quantization */
@property (nonatomic, assign) NSInteger colorCount;                    // default 8
@property (nonatomic, assign) CPMQuantizationMethod quantizationMethod;
@property (nonatomic, assign) CPMColorDistanceSpace distanceSpace;     // default Lab
/// Skip quantization when the artwork has at most this many distinct colors. Default 64.
@property (nonatomic, assign) NSInteger maxDistinctColorsForExactMatch;
/// Merge colors closer than this (ΔE76 or 0..1 sRGB) into one class. Default 6.
@property (nonatomic, assign) CGFloat maxColorDistance;
/// Extra centroid seeds, as UIColor (e.g. the game's available paint palette).
@property (nonatomic, copy, nullable) NSArray<UIColor *> *paletteSeeds;
/// Weights for (L, a, b, alpha) distance. Defaults to 1,1,1,0.5.
@property (nonatomic, assign) CGFloat weightL, weightA, weightB, weightAlpha;

/* Shape extraction */
/// Hard cap on emitted stickers: the game's own limit, not a taste decision.
@property (nonatomic, assign) NSInteger maxShapes;
/// Drop components smaller than this fraction of the ROI area. Default 0.0005.
@property (nonatomic, assign) CGFloat areaThreshold;
/// Drop components smaller than this many working pixels². Default 12.
@property (nonatomic, assign) NSInteger minComponentAreaPx;
/// Trace contours so triangles/polygons can be emitted (vs. rect-only output).
@property (nonatomic, assign) BOOL allowComplexShapes;
/// Set NO to keep every sticker axis-aligned. Default YES.
@property (nonatomic, assign) BOOL allowRotation;
/// Max vertices kept after Douglas-Peucker for polygon stickers. Default 24.
@property (nonatomic, assign) NSInteger maxPolygonVertices;
/// Douglas-Peucker epsilon, in working pixels. Default 1.5.
@property (nonatomic, assign) CGFloat epsilonPx;
/// Fill each component with its own alpha (semi-transparent art stays translucent).
@property (nonatomic, assign) BOOL keepAlpha;

+ (instancetype)defaultConfig;
/// Small budget: few, big, opaque shapes — what a car body actually accepts.
+ (instancetype)configForCarBodyWithMaxLayers:(NSInteger)layerLimit;
/// Full detail: every colour class, complex shapes allowed.
+ (instancetype)configForDetailedLogoWithMaxLayers:(NSInteger)layerLimit;
+ (nullable instancetype)configWithDictionary:(NSDictionary<NSString *, id> *)dict;
- (NSDictionary<NSString *, id> *)dictionaryRepresentation;
@end

@interface CPMShapeDecompositionResult : NSObject

@property (nonatomic, copy, readonly) NSArray<CPMVinylShape *> *shapes;
@property (nonatomic, copy, readonly) NSArray<UIColor *> *palette;
@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
@property (nonatomic, assign, readonly) NSTimeInterval processingTime;
/// Working pixels inspected (ROI size, not the original bitmap).
@property (nonatomic, assign, readonly) NSUInteger inputPixelCount;
/// Non-transparent pixels found inside the ROI.
@property (nonatomic, assign, readonly) NSUInteger foregroundPixelCount;
/// Pixels covered by the emitted shapes / foregroundPixelCount.
@property (nonatomic, assign, readonly) CGFloat coverageRatio;
/// Components dropped because the color budget or the minimum area cut them.
@property (nonatomic, assign, readonly) NSUInteger droppedShapeCount;
/// YES when the image had ≤ maxDistinctColorsForExactMatch colors: no approximation.
@property (nonatomic, assign, readonly) BOOL exactColorMatch;
/// Working bitmap size the numbers above refer to.
@property (nonatomic, assign, readonly) CGSize workingSize;

- (BOOL)meetsQualityThreshold;
- (NSString *)summaryString;
/// Re-emits the layout for a tighter layer budget without re-running vision.
- (NSArray<CPMVinylShape *> *)shapesForLayerBudget:(NSInteger)budget;

@end

@interface CPMShapeDecomposer : NSObject

+ (instancetype)sharedDecomposer;

- (void)decomposeImage:(UIImage *)image
             withConfig:(CPMShapeDecompositionConfig *)config
             completion:(void (^)(CPMShapeDecompositionResult *_Nullable result,
                                  NSError *_Nullable error))completion;
/// Synchronous variant (debug tooling and unit tests). Never call from the main thread.
- (CPMShapeDecompositionResult *_Nullable)decomposeImageSync:(UIImage *)image
                                                    withConfig:(CPMShapeDecompositionConfig *)config
                                                         error:(NSError *_Nullable *_Nullable)error;
- (void)cancelDecomposition;
@property (nonatomic, assign, readonly) BOOL isProcessing;

/// Fractional progress (0..1) for each stage; delivered on the main thread.
@property (nonatomic, copy, nullable) void (^progressHandler)(CGFloat progress, NSString *stage);

@end

NS_ASSUME_NONNULL_END
