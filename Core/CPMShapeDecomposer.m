/**
 * CPMShapeDecomposer.m — the vision pipeline documented in CPMShapeDecomposer.h.
 *
 * Offline by construction: it reads pixels and writes CPMVinylShape objects. It never
 * touches the game, the overlay, or the touch injector.
 */
#import "CPMShapeDecomposer.h"
#import "CPMVinylShape.h"
#import "OverlayCommon.h"

#import <math.h>
#import <stdlib.h>

NSErrorDomain const CPMShapeDecomposerErrorDomain = @"CPMShapeDecomposerErrorDomain";

/// RGB histogram: 4 bits per channel → 4096 buckets, each one a candidate color class.
#define CPM_HISTOGRAM_BITS 4
#define CPM_HISTOGRAM_LEVELS (1 << CPM_HISTOGRAM_BITS)
#define CPM_HISTOGRAM_SIZE (CPM_HISTOGRAM_LEVELS * CPM_HISTOGRAM_LEVELS * CPM_HISTOGRAM_LEVELS)
#define CPM_MAX_CLASSES 256
/// Poll for cancellation every N pixels (an atomic read per pixel is not free).
#define CPM_CANCEL_CHECK_MASK 0xFFFF

static NSError *CPMDecomposerError(CPMShapeDecomposerError code, NSString *reason);
/// Draws + crops + downscales into a caller-owned RGBA8 buffer (defined at the bottom).
static BOOL CPMRenderImageToRGBA(UIImage *image, CGRect roiRect, NSInteger maxDim, BOOL keepAlpha,
                                 uint8_t **outBuffer, int *outW, int *outH, size_t *outRowBytes);

static NSError *CPMDecomposerError(CPMShapeDecomposerError code, NSString *reason) {
    return [NSError errorWithDomain:CPMShapeDecomposerErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: reason ?: @"decomposition failed"}];
}

#pragma mark - config

@implementation CPMShapeDecompositionConfig

+ (instancetype)defaultConfig {
    CPMShapeDecompositionConfig *c = [[CPMShapeDecompositionConfig alloc] init];
    c.workingMaxDimension = 512;
    c.roiRect = CGRectNull;
    c.alphaThreshold = 0.5;
    c.colorCount = 8;
    c.quantizationMethod = CPMQuantizationAuto;
    c.distanceSpace = CPMColorDistanceSpaceLab;
    c.maxDistinctColorsForExactMatch = 64;
    c.maxColorDistance = 6.0;
    c.weightL = 1.0; c.weightA = 1.0; c.weightB = 1.0; c.weightAlpha = 0.5;
    c.maxShapes = 250;
    c.areaThreshold = 0.0005;
    c.minComponentAreaPx = 12;
    c.allowComplexShapes = YES;
    c.allowRotation = YES;
    c.maxPolygonVertices = 24;
    c.epsilonPx = 1.5;
    c.keepAlpha = YES;
    return c;
}

+ (instancetype)configForCarBodyWithMaxLayers:(NSInteger)layerLimit {
    CPMShapeDecompositionConfig *c = [self defaultConfig];
    c.maxShapes = MAX(1, layerLimit);
    c.colorCount = MIN(6, MAX(2, layerLimit / 4));
    c.areaThreshold = 0.002;
    c.minComponentAreaPx = 48;
    c.allowComplexShapes = NO;      /* plain quads: fewer taps, fewer misfires */
    c.maxColorDistance = 12.0;
    return c;
}

+ (instancetype)configForDetailedLogoWithMaxLayers:(NSInteger)layerLimit {
    CPMShapeDecompositionConfig *c = [self defaultConfig];
    c.maxShapes = MAX(1, layerLimit);
    c.colorCount = MIN(16, MAX(2, layerLimit / 3));
    c.areaThreshold = 0.0002;
    c.minComponentAreaPx = 8;
    c.allowComplexShapes = YES;
    c.workingMaxDimension = 768;
    return c;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    CPMShapeDecompositionConfig *c = [[CPMShapeDecompositionConfig alloc] init];
    c.workingMaxDimension = self.workingMaxDimension;
    c.roiRect = self.roiRect;
    c.alphaThreshold = self.alphaThreshold;
    c.colorCount = self.colorCount;
    c.quantizationMethod = self.quantizationMethod;
    c.distanceSpace = self.distanceSpace;
    c.maxDistinctColorsForExactMatch = self.maxDistinctColorsForExactMatch;
    c.maxColorDistance = self.maxColorDistance;
    c.paletteSeeds = self.paletteSeeds;
    c.weightL = self.weightL; c.weightA = self.weightA;
    c.weightB = self.weightB; c.weightAlpha = self.weightAlpha;
    c.maxShapes = self.maxShapes;
    c.areaThreshold = self.areaThreshold;
    c.minComponentAreaPx = self.minComponentAreaPx;
    c.allowComplexShapes = self.allowComplexShapes;
    c.allowRotation = self.allowRotation;
    c.maxPolygonVertices = self.maxPolygonVertices;
    c.epsilonPx = self.epsilonPx;
    c.keepAlpha = self.keepAlpha;
    return c;
}

static CGFloat CPMDictNumber(NSDictionary *d, NSString *key, CGFloat fallback, BOOL *present) {
    NSNumber *n = [d objectForKey:key];
    if (![n isKindOfClass:NSNumber.class]) { if (present) *present = NO; return fallback; }
    if (present) *present = YES;
    return (CGFloat)n.doubleValue;
}

+ (instancetype)configWithDictionary:(NSDictionary<NSString *, id> *)dict {
    if (![dict isKindOfClass:NSDictionary.class]) return nil;
    CPMShapeDecompositionConfig *c = [self defaultConfig];
    BOOL has = NO;
    CGFloat v;
    v = CPMDictNumber(dict, @"workingMaxDimension", c.workingMaxDimension, &has); if (has) c.workingMaxDimension = (NSInteger)v;
    v = CPMDictNumber(dict, @"alphaThreshold", c.alphaThreshold, &has); if (has) c.alphaThreshold = v;
    v = CPMDictNumber(dict, @"colorCount", c.colorCount, &has); if (has) c.colorCount = (NSInteger)v;
    v = CPMDictNumber(dict, @"maxColorDistance", c.maxColorDistance, &has); if (has) c.maxColorDistance = v;
    v = CPMDictNumber(dict, @"maxDistinctColorsForExactMatch", c.maxDistinctColorsForExactMatch, &has);
    if (has) c.maxDistinctColorsForExactMatch = (NSInteger)v;
    v = CPMDictNumber(dict, @"maxShapes", c.maxShapes, &has); if (has) c.maxShapes = (NSInteger)v;
    v = CPMDictNumber(dict, @"areaThreshold", c.areaThreshold, &has); if (has) c.areaThreshold = v;
    v = CPMDictNumber(dict, @"minComponentAreaPx", c.minComponentAreaPx, &has); if (has) c.minComponentAreaPx = (NSInteger)v;
    v = CPMDictNumber(dict, @"maxPolygonVertices", c.maxPolygonVertices, &has); if (has) c.maxPolygonVertices = (NSInteger)v;
    v = CPMDictNumber(dict, @"epsilonPx", c.epsilonPx, &has); if (has) c.epsilonPx = v;
    v = CPMDictNumber(dict, @"distanceSpace", c.distanceSpace, &has); if (has) c.distanceSpace = (CPMColorDistanceSpace)v;
    v = CPMDictNumber(dict, @"quantizationMethod", c.quantizationMethod, &has); if (has) c.quantizationMethod = (CPMQuantizationMethod)v;
    v = CPMDictNumber(dict, @"allowComplexShapes", c.allowComplexShapes, &has); if (has) c.allowComplexShapes = v != 0;
    v = CPMDictNumber(dict, @"allowRotation", c.allowRotation, &has); if (has) c.allowRotation = v != 0;
    v = CPMDictNumber(dict, @"keepAlpha", c.keepAlpha, &has); if (has) c.keepAlpha = v != 0;
    NSArray *arr = [dict objectForKey:@"roiRect"];
    if ([arr isKindOfClass:NSArray.class] && arr.count == 4) {
        c.roiRect = CGRectMake([arr[0] doubleValue], [arr[1] doubleValue],
                               [arr[2] doubleValue], [arr[3] doubleValue]);
    }
    NSArray *seeds = [dict objectForKey:@"paletteSeeds"];
    if ([seeds isKindOfClass:NSArray.class]) {
        NSMutableArray<UIColor *> *cols = [NSMutableArray array];
        for (NSNumber *packed in seeds) {
            if (![packed isKindOfClass:NSNumber.class]) continue;
            uint32_t p = (uint32_t)packed.unsignedLongValue;
            [cols addObject:[UIColor colorWithRed:((p >> 24) & 0xFF) / 255.0
                                            green:((p >> 16) & 0xFF) / 255.0
                                             blue:((p >> 8) & 0xFF) / 255.0
                                            alpha:((p) & 0xFF) / 255.0]];
        }
        if (cols.count) c.paletteSeeds = cols;
    }
    return c;
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"workingMaxDimension"] = @(self.workingMaxDimension);
    d[@"alphaThreshold"] = @(self.alphaThreshold);
    d[@"colorCount"] = @(self.colorCount);
    d[@"maxColorDistance"] = @(self.maxColorDistance);
    d[@"maxDistinctColorsForExactMatch"] = @(self.maxDistinctColorsForExactMatch);
    d[@"maxShapes"] = @(self.maxShapes);
    d[@"areaThreshold"] = @(self.areaThreshold);
    d[@"minComponentAreaPx"] = @(self.minComponentAreaPx);
    d[@"maxPolygonVertices"] = @(self.maxPolygonVertices);
    d[@"epsilonPx"] = @(self.epsilonPx);
    d[@"distanceSpace"] = @(self.distanceSpace);
    d[@"quantizationMethod"] = @(self.quantizationMethod);
    d[@"allowComplexShapes"] = @(self.allowComplexShapes);
    d[@"allowRotation"] = @(self.allowRotation);
    d[@"keepAlpha"] = @(self.keepAlpha);
    if (!CGRectIsNull(self.roiRect) && !CGRectIsEmpty(self.roiRect)) {
        d[@"roiRect"] = @[@(self.roiRect.origin.x), @(self.roiRect.origin.y),
                          @(self.roiRect.size.width), @(self.roiRect.size.height)];
    }
    if (self.paletteSeeds.count) {
        NSMutableArray *packed = [NSMutableArray arrayWithCapacity:self.paletteSeeds.count];
        for (UIColor *c in self.paletteSeeds) {
            CGFloat r = 0, g = 0, b = 0, a = 0;
            [c getRed:&r green:&g blue:&b alpha:&a];
            [packed addObject:@(CPMPackRGBA(r * 255.0, g * 255.0, b * 255.0, a * 255.0))];
        }
        d[@"paletteSeeds"] = packed;
    }
    return d;
}

@end

#pragma mark - result

@interface CPMShapeDecompositionResult ()
@property (nonatomic, copy, readwrite) NSArray<CPMVinylShape *> *shapes;
@property (nonatomic, copy, readwrite) NSArray<UIColor *> *palette;
@property (nonatomic, copy, readwrite) NSArray<NSString *> *warnings;
@property (nonatomic, assign, readwrite) NSTimeInterval processingTime;
@property (nonatomic, assign, readwrite) NSUInteger inputPixelCount;
@property (nonatomic, assign, readwrite) NSUInteger foregroundPixelCount;
@property (nonatomic, assign, readwrite) CGFloat coverageRatio;
@property (nonatomic, assign, readwrite) NSUInteger droppedShapeCount;
@property (nonatomic, assign, readwrite) BOOL exactColorMatch;
@property (nonatomic, assign, readwrite) CGSize workingSize;
@end

@implementation CPMShapeDecompositionResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _shapes = @[];
        _palette = @[];
        _warnings = @[];
    }
    return self;
}

- (BOOL)meetsQualityThreshold {
    if (self.shapes.count == 0) return NO;
    if (self.coverageRatio < 0.75) return NO;
    for (CPMVinylShape *s in self.shapes) {
        if (s.scale.width < 1 || s.scale.height < 1) return NO;
    }
    return YES;
}

- (NSArray<CPMVinylShape *> *)shapesForLayerBudget:(NSInteger)budget {
    if (budget <= 0) return @[];
    if ((NSInteger)self.shapes.count <= budget) return self.shapes;
    NSArray *sorted = [self.shapes sortedArrayUsingComparator:^NSComparisonResult(CPMVinylShape *a, CPMVinylShape *b) {
        if (a.areaPixels > b.areaPixels) return NSOrderedAscending;
        if (a.areaPixels < b.areaPixels) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<CPMVinylShape *> *out = [NSMutableArray array];
    [sorted enumerateObjectsUsingBlock:^(CPMVinylShape *obj, NSUInteger idx, BOOL *stop) {
        if ((NSInteger)out.count >= budget) { *stop = YES; return; }
        [out addObject:[obj shapeWithOrder:(NSInteger)out.count]];
    }];
    return out;
}

- (NSString *)summaryString {
    return [NSString stringWithFormat:
            @"%lu sticker%@ from %lux%lu working px — coverage %0.1f%%, %@, %0.0f ms%@",
            (unsigned long)self.shapes.count, self.shapes.count == 1 ? @"" : @"s",
            (unsigned long)(NSUInteger)self.workingSize.width,
            (unsigned long)(NSUInteger)self.workingSize.height,
            self.coverageRatio * 100.0,
            self.exactColorMatch ? @"exact colors" : @"quantized",
            self.processingTime * 1000.0,
            self.droppedShapeCount ? [NSString stringWithFormat:@", %lu dropped",
                                      (unsigned long)self.droppedShapeCount] : @""];
}

- (NSString *)description { return [self summaryString]; }

@end

#pragma mark - color math

typedef struct {
    uint8_t r, g, b, a;
    double L, A, B;
} CPMColorPoint;

static double CPM_srgb_to_linear(double u) {
    return u <= 0.04045 ? u / 12.92 : pow((u + 0.055) / 1.055, 2.4);
}

static double CPM_lab_f(double t) {
    const double k = 8.0 / 903.2962962;
    return t > k ? cbrt(t) : (t / (3.0 * k * k) + 4.0 / 29.0);
}

static void CPM_lab_from_uint8(uint8_t r, uint8_t g, uint8_t b, double *L, double *A, double *B) {
    double R = CPM_srgb_to_linear(r / 255.0);
    double G = CPM_srgb_to_linear(g / 255.0);
    double Bl = CPM_srgb_to_linear(b / 255.0);
    double X = 0.4124564 * R + 0.3575761 * G + 0.1804375 * Bl;
    double Y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * Bl;
    double Z = 0.0193339 * R + 0.1191920 * G + 0.9503041 * Bl;
    double fx = CPM_lab_f(X / 0.95047), fy = CPM_lab_f(Y), fz = CPM_lab_f(Z / 1.08883);
    *L = 116.0 * fy - 16.0;
    *A = 500.0 * (fx - fy);
    *B = 200.0 * (fy - fz);
}

static CPMColorPoint CPM_make_point(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    CPMColorPoint p;
    p.r = r; p.g = g; p.b = b; p.a = a;
    CPM_lab_from_uint8(r, g, b, &p.L, &p.A, &p.B);
    return p;
}

/// Smaller = closer. sRGB mode returns a 0…100-ish scale so maxColorDistance is
/// comparable across spaces.
static double CPM_color_distance(CPMColorPoint p, CPMColorPoint q, CPMColorDistanceSpace space,
                                 double wL, double wA, double wB, double wAlpha) {
    double dAlpha = fabs((double)p.a - (double)q.a) / 255.0 * wAlpha * 100.0;
    if (space == CPMColorDistanceSpaceSRGB) {
        double dr = ((double)p.r - (double)q.r) / 255.0 * wL;
        double dg = ((double)p.g - (double)q.g) / 255.0 * wA;
        double db = ((double)p.b - (double)q.b) / 255.0 * wB;
        return sqrt(dr * dr + dg * dg + db * db) * 100.0 + dAlpha;
    }
    double dL = (p.L - q.L) * wL;
    double dA = (p.A - q.A) * wA;
    double dB = (p.B - q.B) * wB;
    if (space == CPMColorDistanceSpaceHueChroma) {
        double c1 = hypot(p.A, p.B), c2 = hypot(q.A, q.B);
        double h1 = atan2(p.B, p.A) * 180.0 / M_PI;
        double h2 = atan2(q.B, q.A) * 180.0 / M_PI;
        double dh = CPMNormalizeAngle(h1 - h2);
        if (dh > 180.0) dh -= 360.0;
        double dChroma = 2.0 * sqrt(c1 * c2) * sin(dh * M_PI / 360.0);
        double dC = c1 - c2;
        return sqrt(pow(dL * 0.35, 2) + pow(dC, 2) + pow(dChroma * 1.2, 2)) + dAlpha;
    }
    return sqrt(dL * dL + dA * dA + dB * dB) + dAlpha;
}

#pragma mark - histogram

typedef struct {
    uint64_t count;
    uint64_t sumR, sumG, sumB, sumA;
    uint8_t minR, maxR, minG, maxG, minB, maxB;
} CPMHistogramBucket;

static inline uint32_t CPM_histogram_index(uint8_t r, uint8_t g, uint8_t b) {
    const int shift = 8 - CPM_HISTOGRAM_BITS;
    return ((uint32_t)(r >> shift) << (2 * CPM_HISTOGRAM_BITS)) |
           ((uint32_t)(g >> shift) << CPM_HISTOGRAM_BITS) |
           ((uint32_t)(b >> shift));
}

static inline CPMColorPoint CPM_bucket_mean_point(const CPMHistogramBucket *h) {
    uint64_t n = h->count ? h->count : 1;
    uint8_t r = (uint8_t)MIN(255, (h->sumR + n / 2) / n);
    uint8_t g = (uint8_t)MIN(255, (h->sumG + n / 2) / n);
    uint8_t b = (uint8_t)MIN(255, (h->sumB + n / 2) / n);
    uint8_t a = (uint8_t)MIN(255, (h->sumA + n / 2) / n);
    return CPM_make_point(r, g, b, a);
}

#pragma mark - clustering over the histogram

typedef struct {
    CPMColorPoint centroid;
    double weight;
    uint32_t bucketCount;
    BOOL used;
} CPMColorClass;

static NSUInteger CPM_kmeans(const CPMColorPoint *pts, const double *wts, const uint32_t *bucketOf,
                             NSUInteger n, NSInteger k, CPMColorDistanceSpace space,
                             double wL, double wA, double wB, double wAlpha,
                             const CPMColorPoint *seeds, NSUInteger seedCount,
                             int32_t *assign, CPMColorClass *classes, int32_t *bucketLabel);
static NSUInteger CPM_median_cut(const CPMColorPoint *pts, const double *wts, const uint32_t *bucketOf,
                                 NSUInteger n, NSInteger k, CPMColorDistanceSpace space,
                                 double wL, double wA, double wB, double wAlpha,
                                 int32_t *assign, CPMColorClass *classes, int32_t *bucketLabel);

/**
 * Groups the used histogram buckets into at most `k` classes.
 * `bucketLabel` gets one entry per histogram bucket (-1 for unused buckets).
 * Returns the number of classes produced.
 */
static NSUInteger CPM_classify_colors(const CPMHistogramBucket *hist,
                                      NSUInteger histSize,
                                      NSInteger k,
                                      CPMQuantizationMethod method,
                                      CPMColorDistanceSpace space,
                                      double wL, double wA, double wB, double wAlpha,
                                      const CPMColorPoint *seeds, NSUInteger seedCount,
                                      NSInteger maxDistinctForExact,
                                      int32_t *bucketLabel,
                                      CPMColorClass *classes) {
    for (NSUInteger i = 0; i < histSize; i++) bucketLabel[i] = -1;
    for (NSUInteger i = 0; i < (NSUInteger)CPM_MAX_CLASSES; i++) classes[i].used = NO;

    NSUInteger used = 0;
    for (NSUInteger i = 0; i < histSize; i++) if (hist[i].count) used++;
    if (used == 0) return 0;
    if (k > CPM_MAX_CLASSES) k = CPM_MAX_CLASSES;
    if (k < 1) k = 1;

    CPMColorPoint *pts = (CPMColorPoint *)malloc(sizeof(CPMColorPoint) * used);
    double *wts = (double *)malloc(sizeof(double) * used);
    uint32_t *bucketOf = (uint32_t *)malloc(sizeof(uint32_t) * used);
    if (!pts || !wts || !bucketOf) {
        free(pts); free(wts); free(bucketOf);
        return 0;
    }
    NSUInteger n = 0;
    for (NSUInteger i = 0; i < histSize; i++) {
        if (!hist[i].count) continue;
        pts[n] = CPM_bucket_mean_point(&hist[i]);
        wts[n] = (double)hist[i].count;
        bucketOf[n] = (uint32_t)i;
        n++;
    }

    BOOL exact = (method != CPMQuantizationKMeans) && (NSInteger)n <= MIN(k, maxDistinctForExact);
    if (method == CPMQuantizationAuto && !exact && (NSInteger)n <= k) exact = YES;
    /* "Exact" only if no bucket mixes visibly different colors. */
    if (exact) {
        for (NSUInteger i = 0; i < histSize; i++) {
            if (!hist[i].count) continue;
            double spreadR = fabs((double)hist[i].maxR - (double)hist[i].minR);
            double spreadG = fabs((double)hist[i].maxG - (double)hist[i].minG);
            double spreadB = fabs((double)hist[i].maxB - (double)hist[i].minB);
            double worst = MAX(spreadR, MAX(spreadG, spreadB));
            if (worst > 24.0) { exact = NO; break; }
        }
    }
    if (exact) {
        NSUInteger c = 0;
        for (NSUInteger i = 0; i < n && c < (NSUInteger)CPM_MAX_CLASSES; i++) {
            bucketLabel[bucketOf[i]] = (int32_t)c;
            classes[c].centroid = pts[i];
            classes[c].weight = wts[i];
            classes[c].bucketCount = 1;
            classes[c].used = YES;
            c++;
        }
        free(pts); free(wts); free(bucketOf);
        return c;
    }

    int32_t *assign = (int32_t *)malloc(sizeof(int32_t) * n);
    if (!assign) { free(pts); free(wts); free(bucketOf); return 0; }
    for (NSUInteger i = 0; i < n; i++) assign[i] = 0;

    NSUInteger classCount = (NSUInteger)k;
    if (method == CPMQuantizationMedianCut) {
        classCount = CPM_median_cut(pts, wts, bucketOf, n, (NSInteger)k, space,
                                    wL, wA, wB, wAlpha, assign, classes, bucketLabel);
    } else {
        classCount = CPM_kmeans(pts, wts, bucketOf, n, (NSInteger)k, space,
                                wL, wA, wB, wAlpha, seeds, seedCount, assign, classes, bucketLabel);
    }
    free(assign);
    free(pts); free(wts); free(bucketOf);
    return classCount;
}

#pragma mark - k-means / median cut (used by CPM_classify_colors)

static double CPM_weighted_mean_of(const CPMColorPoint *pts, const double *wts,
                                   const uint32_t *idx, NSUInteger first, NSUInteger count, int ch,
                                   double totalWeight) {
    double acc = 0;
    for (NSUInteger i = first; i < first + count; i++) {
        const CPMColorPoint *p = &pts[idx[i]];
        double v = ch == 0 ? p->r : ch == 1 ? p->g : ch == 2 ? p->b : p->a;
        acc += v * wts[idx[i]];
    }
    return totalWeight > 0 ? acc / totalWeight : 0;
}

static NSUInteger CPM_kmeans(const CPMColorPoint *pts, const double *wts, const uint32_t *bucketOf,
                             NSUInteger n, NSInteger k, CPMColorDistanceSpace space,
                             double wL, double wA, double wB, double wAlpha,
                             const CPMColorPoint *seeds, NSUInteger seedCount,
                             int32_t *assign, CPMColorClass *classes, int32_t *bucketLabel) {
    if (n == 0 || k < 1) return 0;
    if (k > CPM_MAX_CLASSES) k = CPM_MAX_CLASSES;
    if ((NSUInteger)k > n) k = (NSInteger)n;

    CPMColorPoint *cents = (CPMColorPoint *)malloc(sizeof(CPMColorPoint) * (size_t)k);
    double *best = (double *)malloc(sizeof(double) * n);
    if (!cents || !best) { free(cents); free(best); return 0; }

    /* k-means++ seeding, with any caller-provided seeds (game paint palette) first. */
    uint64_t rng = 0x9E3779B97F4A7C15ull;
    for (NSUInteger i = 0; i < n; i++) best[i] = INFINITY;
    NSUInteger used = 0;
    for (NSUInteger s = 0; s < seedCount && (NSInteger)used < k; s++) {
        uint32_t pick = 0; double pickDist = INFINITY;
        for (uint32_t i = 0; i < n; i++) {
            double d = CPM_color_distance(pts[i], seeds[s], space, wL, wA, wB, wAlpha);
            if (d < pickDist) { pickDist = d; pick = i; }
        }
        cents[used++] = pts[pick];
        for (uint32_t i = 0; i < n; i++) {
            double d = CPM_color_distance(pts[i], pts[pick], space, wL, wA, wB, wAlpha);
            if (d < best[i]) best[i] = d;
        }
    }
    while ((NSInteger)used < k) {
        double total = 0;
        for (uint32_t i = 0; i < n; i++) total += best[i] * best[i] * wts[i];
        uint32_t pick = 0;
        if (!(total > 0.0)) {
            rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
            pick = (uint32_t)(rng % n);
        } else {
            rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17;
            double target = (double)(rng >> 11) / (double)(1ull << 53) * total;
            double acc = 0;
            for (uint32_t i = 0; i < n; i++) {
                acc += best[i] * best[i] * wts[i];
                if (acc >= target) { pick = i; break; }
            }
        }
        cents[used++] = pts[pick];
        for (uint32_t i = 0; i < n; i++) {
            double d = CPM_color_distance(pts[i], pts[pick], space, wL, wA, wB, wAlpha);
            if (d < best[i]) best[i] = d;
        }
    }

    for (int iter = 0; iter < 24; iter++) {
        BOOL changed = NO;
        for (uint32_t i = 0; i < n; i++) {
            double bestD = INFINITY; int32_t bestC = 0;
            for (NSUInteger c = 0; c < used; c++) {
                double d = CPM_color_distance(pts[i], cents[c], space, wL, wA, wB, wAlpha);
                if (d < bestD) { bestD = d; bestC = (int32_t)c; }
            }
            if (assign[i] != bestC) { assign[i] = bestC; changed = YES; }
        }
        if (!changed) break;
        for (NSUInteger c = 0; c < used; c++) {
            double tot = 0, sr = 0, sg = 0, sb = 0, sa = 0;
            for (uint32_t i = 0; i < n; i++) {
                if ((NSUInteger)assign[i] != c) continue;
                double w = wts[i];
                tot += w;
                sr += pts[i].r * w; sg += pts[i].g * w; sb += pts[i].b * w; sa += pts[i].a * w;
            }
            if (!(tot > 0)) continue;      /* empty class: keep the previous centroid */
            cents[c] = CPM_make_point((uint8_t)MIN(255.0, sr / tot + 0.5),
                                      (uint8_t)MIN(255.0, sg / tot + 0.5),
                                      (uint8_t)MIN(255.0, sb / tot + 0.5),
                                      (uint8_t)MIN(255.0, sa / tot + 0.5));
        }
    }

    for (NSUInteger c = 0; c < used; c++) classes[c].used = NO;
    for (uint32_t i = 0; i < CPM_HISTOGRAM_SIZE; i++) bucketLabel[i] = -1;
    for (uint32_t i = 0; i < n; i++) {
        int32_t c = assign[i];
        if (c < 0) c = 0;
        bucketLabel[bucketOf[i]] = c;
        if (!classes[c].used) {
            classes[c].used = YES;
            classes[c].centroid = cents[c];
            classes[c].weight = 0;
            classes[c].bucketCount = 0;
        }
        classes[c].weight += wts[i];
        classes[c].bucketCount += 1;
    }
    free(best);
    free(cents);
    return used;
}

static NSUInteger CPM_median_cut(const CPMColorPoint *pts, const double *wts, const uint32_t *bucketOf,
                                 NSUInteger n, NSInteger k, CPMColorDistanceSpace space,
                                 double wL, double wA, double wB, double wAlpha,
                                 int32_t *assign, CPMColorClass *classes, int32_t *bucketLabel) {
    (void)space; (void)wL; (void)wA; (void)wB; (void)wAlpha;
    if (n == 0 || k < 1) return 0;
    if (k > CPM_MAX_CLASSES) k = CPM_MAX_CLASSES;
    if ((NSUInteger)k > n) k = (NSInteger)n;

    uint32_t *order = (uint32_t *)malloc(sizeof(uint32_t) * n);
    uint32_t *scratch = (uint32_t *)malloc(sizeof(uint32_t) * n);
    if (!order || !scratch) { free(order); free(scratch); return 0; }
    for (uint32_t i = 0; i < n; i++) order[i] = i;

    typedef struct { NSUInteger first, count; } CPMBox;
    CPMBox boxes[CPM_MAX_CLASSES];
    NSUInteger boxCount = 1;
    boxes[0].first = 0; boxes[0].count = n;

    while ((NSInteger)boxCount < k) {
        NSUInteger pick = NSNotFound;
        double pickRange = 0;
        int pickChannel = 0;
        for (NSUInteger bi = 0; bi < boxCount; bi++) {
            if (boxes[bi].count < 2) continue;
            for (int ch = 0; ch < 3; ch++) {
                double lo = 1e9, hi = -1e9;
                for (NSUInteger i = boxes[bi].first; i < boxes[bi].first + boxes[bi].count; i++) {
                    const CPMColorPoint *p = &pts[order[i]];
                    double v = ch == 0 ? p->r : ch == 1 ? p->g : p->b;
                    lo = MIN(lo, v); hi = MAX(hi, v);
                }
                if (hi - lo > pickRange) { pickRange = hi - lo; pick = bi; pickChannel = ch; }
            }
        }
        if (pick == NSNotFound || pickRange <= 0) break;

        CPMBox box = boxes[pick];
        /* counting sort of the box by the chosen channel's value (0…255) */
        uint32_t counts[257];
        for (int i = 0; i < 257; i++) counts[i] = 0;
        for (NSUInteger i = box.first; i < box.first + box.count; i++) {
            const CPMColorPoint *p = &pts[order[i]];
            double v = pickChannel == 0 ? p->r : pickChannel == 1 ? p->g : p->b;
            counts[(int)MIN(255.0, MAX(0.0, v))]++;
        }
        for (int i = 1; i < 256; i++) counts[i] += counts[i - 1];
        for (NSUInteger i = box.first; i < box.first + box.count; i++) {
            const CPMColorPoint *p = &pts[order[i]];
            double v = pickChannel == 0 ? p->r : pickChannel == 1 ? p->g : p->b;
            int slot = (int)MIN(255.0, MAX(0.0, v));
            scratch[box.first + counts[slot] - 1] = order[i];
            counts[slot]--;
        }
        for (NSUInteger i = box.first; i < box.first + box.count; i++) order[i] = scratch[i];

        double total = 0;
        for (NSUInteger i = box.first; i < box.first + box.count; i++) total += wts[order[i]];
        double acc = 0; NSUInteger split = box.count - 1;
        for (NSUInteger i = box.first; i < box.first + box.count; i++) {
            acc += wts[order[i]];
            if (acc >= total * 0.5) { split = i - box.first + 1; break; }
        }
        if (split < 1) split = 1;
        if (split >= box.count) split = box.count - 1;
        boxes[pick].count = split;
        boxes[boxCount].first = box.first + split;
        boxes[boxCount].count = box.count - split;
        boxCount++;
    }

    for (uint32_t i = 0; i < CPM_HISTOGRAM_SIZE; i++) bucketLabel[i] = -1;
    for (NSUInteger c = 0; c < CPM_MAX_CLASSES; c++) classes[c].used = NO;

    NSUInteger produced = 0;
    for (NSUInteger bi = 0; bi < boxCount; bi++) {
        CPMBox box = boxes[bi];
        double tot = 0;
        for (NSUInteger i = box.first; i < box.first + box.count; i++) tot += wts[order[i]];
        if (!(tot > 0)) continue;
        CPMColorPoint centroid;
        centroid.r = (uint8_t)MIN(255.0, CPM_weighted_mean_of(pts, wts, order, box.first, box.count, 0, tot) + 0.5);
        centroid.g = (uint8_t)MIN(255.0, CPM_weighted_mean_of(pts, wts, order, box.first, box.count, 1, tot) + 0.5);
        centroid.b = (uint8_t)MIN(255.0, CPM_weighted_mean_of(pts, wts, order, box.first, box.count, 2, tot) + 0.5);
        centroid.a = (uint8_t)MIN(255.0, CPM_weighted_mean_of(pts, wts, order, box.first, box.count, 3, tot) + 0.5);
        CPM_lab_from_uint8(centroid.r, centroid.g, centroid.b, &centroid.L, &centroid.A, &centroid.B);

        classes[produced].centroid = centroid;
        classes[produced].weight = tot;
        classes[produced].bucketCount = (uint32_t)box.count;
        classes[produced].used = YES;
        for (NSUInteger i = box.first; i < box.first + box.count; i++) {
            uint32_t pointIndex = order[i];
            assign[pointIndex] = (int32_t)produced;
            bucketLabel[bucketOf[pointIndex]] = (int32_t)produced;
        }
        produced++;
        if (produced >= (NSUInteger)k) break;
    }
    /* Any point that landed in a skipped box goes to the first class. */
    for (uint32_t i = 0; i < n; i++) if (assign[i] < 0 || assign[i] >= (int32_t)produced) assign[i] = 0;
    free(scratch);
    free(order);
    return produced;
}

#pragma mark - geometry

static double CPM_perp_distance(CGPoint p, CGPoint a, CGPoint b) {
    double dx = b.x - a.x, dy = b.y - a.y;
    double len2 = dx * dx + dy * dy;
    if (len2 <= 1e-12) return hypot(p.x - a.x, p.y - a.y);
    double t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
    t = MAX(0.0, MIN(1.0, t));
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

static void CPM_douglas_peucker(const CGPoint *pts, NSUInteger first, NSUInteger last,
                                double eps, uint8_t *keep) {
    if (last <= first + 1) return;
    double worst = -1;
    NSUInteger at = first;
    CGPoint a = pts[first], b = pts[last];
    for (NSUInteger i = first + 1; i < last; i++) {
        double d = CPM_perp_distance(pts[i], a, b);
        if (d > worst) { worst = d; at = i; }
    }
    if (worst <= eps) return;
    keep[at] = 1;
    CPM_douglas_peucker(pts, first, at, eps, keep);
    CPM_douglas_peucker(pts, at, last, eps, keep);
}

/**
 * Moore-neighborhood boundary trace over a 1-byte mask, starting at the top-left-most
 * set pixel. Jacob's stopping criterion keeps it finite on thin shapes.
 */
static size_t CPM_trace_contour(const uint8_t *mask, int mw, int mh, CGPoint *out, size_t maxOut) {
    int sx = -1, sy = -1;
    for (int y = 0; y < mh && sx < 0; y++) {
        for (int x = 0; x < mw; x++) {
            if (mask[(size_t)y * (size_t)mw + (size_t)x]) { sx = x; sy = y; break; }
        }
    }
    if (sx < 0) return 0;
    static const int dx[8] = {1, 1, 0, -1, -1, -1, 0, 1};
    static const int dy[8] = {0, 1, 1, 1, 0, -1, -1, -1};
    size_t count = 0;
    int x = sx, y = sy;
    int backtrack = 6;      /* come from "west" so the walk goes clockwise */
    int guard = mw * mh * 8 + 1024;
    out[count++] = CGPointMake(x, y);
    while (guard-- > 0) {
        int found = -1;
        for (int i = 0; i < 8; i++) {
            int nd = (backtrack + i) & 7;
            int nx = x + dx[nd], ny = y + dy[nd];
            if (nx < 0 || ny < 0 || nx >= mw || ny >= mh) continue;
            if (mask[(size_t)ny * (size_t)mw + (size_t)nx]) { found = nd; break; }
        }
        if (found < 0) break;                       /* lone pixel */
        x += dx[found]; y += dy[found];
        backtrack = (found + 6) & 7;
        if (x == sx && y == sy) {                   /* wrapped around */
            int nx = x + dx[backtrack], ny = y + dy[backtrack];
            if (nx >= 0 && ny >= 0 && nx < mw && ny < mh && mask[(size_t)ny * (size_t)mw + (size_t)nx]) break;
            break;
        }
        if (count >= maxOut) break;
        out[count++] = CGPointMake(x, y);
    }
    return count;
}

#pragma mark - components

typedef struct {
    uint64_t area;
    double sumX, sumY, sumXX, sumYY, sumXY;
    uint64_t sumR, sumG, sumB, sumA;
    int32_t minX, minY, maxX, maxY;
    uint64_t perimeter;
    int32_t colorClass;
    BOOL keep;
} CPMComponentStat;

static int32_t CPM_uf_find(int32_t *parent, int32_t x) {
    int32_t root = x;
    while (parent[root] != root) root = parent[root];
    while (parent[x] != root) { int32_t next = parent[x]; parent[x] = root; x = next; }
    return root;
}

static void CPM_uf_union(int32_t *parent, int32_t a, int32_t b) {
    int32_t ra = CPM_uf_find(parent, a), rb = CPM_uf_find(parent, b);
    if (ra == rb) return;
    if (ra < rb) parent[rb] = ra; else parent[ra] = rb;
}

#pragma mark - decomposer

@interface CPMShapeDecomposer () {
    dispatch_queue_t _workQueue;
    volatile bool _cancelRequested;
    volatile bool _processing;
}
@end

@implementation CPMShapeDecomposer

+ (instancetype)sharedDecomposer {
    static CPMShapeDecomposer *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[CPMShapeDecomposer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _workQueue = dispatch_queue_create("com.cpm.overlay.shape-decomposer", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)isProcessing { return _processing; }

- (void)cancelDecomposition { _cancelRequested = true; }

- (void)reportProgress:(CGFloat)progress stage:(NSString *)stage {
    void (^handler)(CGFloat, NSString *) = self.progressHandler;
    if (!handler) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(CPMClamp(progress, 0, 1), stage);
    });
}

- (void)decomposeImage:(UIImage *)image
             withConfig:(CPMShapeDecompositionConfig *)config
             completion:(void (^)(CPMShapeDecompositionResult *_Nullable, NSError *_Nullable))completion {
    if (_processing) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, CPMDecomposerError(CPMShapeDecomposerErrorBusy, @"a decomposition is already running"));
            });
        }
        return;
    }
    CPMShapeDecompositionConfig *cfg = config ? [config copy] : [CPMShapeDecompositionConfig defaultConfig];
    _processing = true;
    _cancelRequested = false;
    __weak CPMShapeDecomposer *weakSelf = self;
    dispatch_async(_workQueue, ^{
        CPMShapeDecomposer *strongSelf = weakSelf;
        NSError *error = nil;
        CPMShapeDecompositionResult *result = [strongSelf runOnImage:image config:cfg error:&error];
        if (!strongSelf) return;
        void (^handler)(CGFloat, NSString *) = strongSelf.progressHandler;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf->_processing = false;
            if (handler) handler(result ? 1.0 : 0.0, result ? @"done" : @"failed");
            if (completion) completion(result, error);
        });
    });
}

- (CPMShapeDecompositionResult *)decomposeImageSync:(UIImage *)image
                                           withConfig:(CPMShapeDecompositionConfig *)config
                                                error:(NSError **)error {
    return [self runOnImage:image config:config error:error];
}

- (CPMShapeDecompositionResult *)runOnImage:(UIImage *)image
                                    config:(CPMShapeDecompositionConfig *)cfg
                                     error:(NSError **)error {
    NSTimeInterval started = [NSDate date].timeIntervalSinceReferenceDate;
    if (!image) {
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorNoImage, @"no image supplied");
        return nil;
    }
    if (!cfg) cfg = [CPMShapeDecompositionConfig defaultConfig];

    /* ---------- 1. rasterize the ROI ---------- */
    [self reportProgress:0.05 stage:@"rasterizing"];
    uint8_t *buf = NULL;
    size_t rowBytes = 0;
    int W = 0, H = 0;
    if (!CPMRenderImageToRGBA(image, cfg.roiRect, cfg.workingMaxDimension, cfg.keepAlpha, &buf, &W, &H, &rowBytes)) {
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorRasterizeFailed,
                                                cfg.roiRect.size.width < 1 ? @"ROI is empty" : @"image could not be rasterized");
        return nil;
    }

    const double alphaCutoff = CPMClamp(cfg.alphaThreshold, 0, 1) * 255.0;
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    /* ---------- 2. histogram over foreground pixels ---------- */
    [self reportProgress:0.15 stage:@"sampling colors"];
    CPMHistogramBucket *hist = (CPMHistogramBucket *)calloc(CPM_HISTOGRAM_SIZE, sizeof(CPMHistogramBucket));
    if (!hist) { free(buf); if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorRasterizeFailed, @"out of memory"); return nil; }
    uint64_t foreground = 0;
    for (int y = 0; y < H; y++) {
        const uint8_t *row = buf + (size_t)y * rowBytes;
        for (int x = 0; x < W; x++) {
            const uint8_t *px = row + (size_t)x * 4;
            if (px[3] < (uint8_t)alphaCutoff) continue;
            foreground++;
            uint32_t idx = CPM_histogram_index(px[0], px[1], px[2]);
            CPMHistogramBucket *h = &hist[idx];
            h->count++;
            h->sumR += px[0]; h->sumG += px[1]; h->sumB += px[2]; h->sumA += px[3];
            if (h->count == 1) {
                h->minR = h->maxR = px[0]; h->minG = h->maxG = px[1]; h->minB = h->maxB = px[2];
            } else {
                if (px[0] < h->minR) h->minR = px[0];
                if (px[0] > h->maxR) h->maxR = px[0];
                if (px[1] < h->minG) h->minG = px[1];
                if (px[1] > h->maxG) h->maxG = px[1];
                if (px[2] < h->minB) h->minB = px[2];
                if (px[2] > h->maxB) h->maxB = px[2];
            }
        }
    }
    if (foreground == 0) {
        free(hist); free(buf);
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorNoForeground,
                                                @"the selected region is fully transparent");
        return nil;
    }

    /* ---------- 3. color classes ---------- */
    [self reportProgress:0.3 stage:@"quantizing"];
    int32_t *bucketLabel = (int32_t *)malloc(sizeof(int32_t) * CPM_HISTOGRAM_SIZE);
    CPMColorClass *classes = (CPMColorClass *)calloc(CPM_MAX_CLASSES, sizeof(CPMColorClass));
    CPMColorPoint *seedPoints = NULL;
    NSUInteger seedCount = 0;
    if (cfg.paletteSeeds.count) {
        seedPoints = (CPMColorPoint *)malloc(sizeof(CPMColorPoint) * cfg.paletteSeeds.count);
        for (UIColor *c in cfg.paletteSeeds) {
            CGFloat r = 0, g = 0, b = 0, a = 1;
            [c getRed:&r green:&g blue:&b alpha:&a];
            seedPoints[seedCount++] = CPM_make_point((uint8_t)MIN(255.0, r * 255.0),
                                                     (uint8_t)MIN(255.0, g * 255.0),
                                                     (uint8_t)MIN(255.0, b * 255.0),
                                                     (uint8_t)MIN(255.0, a * 255.0));
        }
    }
    NSUInteger classCount = CPM_classify_colors(hist, CPM_HISTOGRAM_SIZE, cfg.colorCount,
                                                cfg.quantizationMethod, cfg.distanceSpace,
                                                cfg.weightL, cfg.weightA, cfg.weightB, cfg.weightAlpha,
                                                seedPoints, seedCount,
                                                cfg.maxDistinctColorsForExactMatch,
                                                bucketLabel, classes);
    BOOL exactColorMatch = YES;
    for (NSUInteger c = 0; c < classCount; c++) {
        if (classes[c].bucketCount > 1) { exactColorMatch = NO; break; }
    }
    free(seedPoints);
    if (classCount == 0) {
        free(bucketLabel); free(classes); free(hist); free(buf);
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorNoForeground, @"no color classes");
        return nil;
    }
    /* Buckets with no label (only possible if a class assignment failed) get their own. */
    for (uint32_t i = 0; i < CPM_HISTOGRAM_SIZE; i++) {
        if (hist[i].count && bucketLabel[i] < 0) bucketLabel[i] = 0;
    }

    /* ---------- 4. connected components per color class ---------- */
    [self reportProgress:0.45 stage:@"finding shapes"];
    size_t pixels = (size_t)W * (size_t)H;
    int32_t *comp = (int32_t *)malloc(sizeof(int32_t) * pixels);
    int32_t *parent = (int32_t *)malloc(sizeof(int32_t) * pixels);
    uint16_t *labelMap = (uint16_t *)malloc(sizeof(uint16_t) * pixels);
    if (!comp || !parent || !labelMap) {
        free(comp); free(parent); free(labelMap);
        free(bucketLabel); free(classes); free(hist); free(buf);
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorRasterizeFailed, @"out of memory");
        return nil;
    }
    int32_t nextId = 0;
    uint64_t counter = 0;
    BOOL cancelled = NO;
    for (int y = 0; y < H && !cancelled; y++) {
        const uint8_t *row = buf + (size_t)y * rowBytes;
        for (int x = 0; x < W; x++) {
            if ((++counter & CPM_CANCEL_CHECK_MASK) == 0 && _cancelRequested) { cancelled = YES; break; }
            const uint8_t *px = row + (size_t)x * 4;
            size_t at = (size_t)y * (size_t)W + (size_t)x;
            if (px[3] < (uint8_t)alphaCutoff) { comp[at] = -1; labelMap[at] = 0xFFFF; continue; }
            uint32_t idx = CPM_histogram_index(px[0], px[1], px[2]);
            int32_t cls = bucketLabel[idx];
            labelMap[at] = (uint16_t)cls;
            int32_t left = -1, up = -1;
            if (x > 0) {
                size_t l = at - 1;
                if (comp[l] >= 0 && labelMap[l] == cls) left = CPM_uf_find(parent, comp[l]);
            }
            if (y > 0) {
                size_t u = at - (size_t)W;
                if (comp[u] >= 0 && labelMap[u] == cls) up = CPM_uf_find(parent, comp[u]);
            }
            if (left < 0 && up < 0) {
                comp[at] = nextId;
                parent[nextId] = nextId;
                nextId++;
            } else if (left >= 0 && up >= 0) {
                int32_t m = MIN(left, up);
                comp[at] = m;
                CPM_uf_union(parent, left, up);
            } else {
                comp[at] = left >= 0 ? left : up;
            }
        }
    }
    if (cancelled || nextId == 0) {
        free(comp); free(parent); free(labelMap);
        free(bucketLabel); free(classes); free(hist); free(buf);
        if (error) *error = CPMDecomposerError(cancelled ? CPMShapeDecomposerErrorCancelled
                                                          : CPMShapeDecomposerErrorNoForeground,
                                               cancelled ? @"cancelled" : @"no shapes found");
        return nil;
    }

    CPMComponentStat *stats = (CPMComponentStat *)calloc((size_t)nextId, sizeof(CPMComponentStat));
    if (!stats) {
        free(comp); free(parent); free(labelMap);
        free(bucketLabel); free(classes); free(hist); free(buf);
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorRasterizeFailed, @"out of memory");
        return nil;
    }
    for (int i = 0; i < nextId; i++) {
        stats[i].minX = W; stats[i].minY = H; stats[i].maxX = -1; stats[i].maxY = -1;
    }
    for (int y = 0; y < H; y++) {
        const uint8_t *row = buf + (size_t)y * rowBytes;
        for (int x = 0; x < W; x++) {
            size_t at = (size_t)y * (size_t)W + (size_t)x;
            if (comp[at] < 0) continue;
            comp[at] = CPM_uf_find(parent, comp[at]);
        }
    }
    /* accumulate + perimeter (neighbors compared after finalization) */
    counter = 0;
    for (int y = 0; y < H; y++) {
        const uint8_t *row = buf + (size_t)y * rowBytes;
        for (int x = 0; x < W; x++) {
            size_t at = (size_t)y * (size_t)W + (size_t)x;
            int32_t id = comp[at];
            if (id < 0) continue;
            CPMComponentStat *s = &stats[id];
            const uint8_t *px = row + (size_t)x * 4;
            s->area++;
            s->sumX += x; s->sumY += y;
            s->sumXX += (double)x * (double)x;
            s->sumYY += (double)y * (double)y;
            s->sumXY += (double)x * (double)y;
            s->sumR += px[0]; s->sumG += px[1]; s->sumB += px[2]; s->sumA += px[3];
            if (x < s->minX) s->minX = x;
            if (x > s->maxX) s->maxX = x;
            if (y < s->minY) s->minY = y;
            if (y > s->maxY) s->maxY = y;
            BOOL edge = NO;
            if (x == 0 || comp[at - 1] != id) edge = YES;
            else if (y == 0 || comp[at - (size_t)W] != id) edge = YES;
            else if (x + 1 >= W || comp[at + 1] != id) edge = YES;
            else if (y + 1 >= H || comp[at + (size_t)W] != id) edge = YES;
            if (edge) s->perimeter++;
        }
    }
    free(parent);

    NSUInteger minAreaPx = (NSUInteger)MAX(1, cfg.minComponentAreaPx);
    double minAreaFraction = (double)foreground * MAX(0.0, cfg.areaThreshold);
    NSUInteger keptCandidates = 0;
    NSUInteger droppedBySize = 0;
    for (int i = 0; i < nextId; i++) {
        CPMComponentStat *s = &stats[i];
        if (s->area == 0) continue;
        if (s->area < minAreaPx || (double)s->area < minAreaFraction) { s->keep = NO; droppedBySize++; continue; }
        s->keep = YES;
        keptCandidates++;
    }
    NSUInteger budget = (NSUInteger)MAX(1, cfg.maxShapes);
    NSUInteger droppedByBudget = 0;
    if (keptCandidates > budget) {
        /* Keep the `budget` largest components; the rest are reported as dropped. */
        NSUInteger *ids = (NSUInteger *)malloc(sizeof(NSUInteger) * keptCandidates);
        if (ids) {
            NSUInteger n = 0;
            for (int s2 = 0; s2 < nextId; s2++) if (stats[s2].keep) ids[n++] = (NSUInteger)s2;
            for (NSUInteger gap = n / 2; gap > 0; gap /= 2) {          /* shell sort by area desc */
                for (NSUInteger i = gap; i < n; i++) {
                    NSUInteger mov = ids[i];
                    uint64_t movArea = stats[mov].area;
                    NSUInteger j = i;
                    while (j >= gap && stats[ids[j - gap]].area < movArea) { ids[j] = ids[j - gap]; j -= gap; }
                    ids[j] = mov;
                }
            }
            for (NSUInteger i = budget; i < n; i++) { stats[ids[i]].keep = NO; droppedByBudget++; }
            free(ids);
        }
    }

    /* ---------- 5/6. geometry, classification, emission ---------- */
    [self reportProgress:0.7 stage:@"tracing outlines"];
    NSMutableArray<CPMVinylShape *> *shapes = [NSMutableArray array];
    uint64_t covered = 0;
    NSUInteger emitted = 0;
    double eps = MAX(0.25, cfg.epsilonPx);
    counter = 0;
    for (int i = 0; i < nextId && !cancelled; i++) {
        if ((++counter & CPM_CANCEL_CHECK_MASK) == 0 && _cancelRequested) { cancelled = YES; break; }
        CPMComponentStat *s = &stats[i];
        if (!s->keep) continue;
        double area = (double)s->area;
        double cx = s->sumX / area;
        double cy = s->sumY / area;
        double bw = (double)(s->maxX - s->minX + 1);
        double bh = (double)(s->maxY - s->minY + 1);
        double sxx = s->sumXX - (double)s->sumX * (double)s->sumX / area;
        double syy = s->sumYY - (double)s->sumY * (double)s->sumY / area;
        double sxy = s->sumXY - (double)s->sumX * (double)s->sumY / area;
        double theta = 0.5 * atan2(2.0 * sxy, sxx - syy);
        double fill = area / MAX(1.0, bw * bh);
        double aspect = MAX(bw, bh) / MAX(1.0, MIN(bw, bh));
        double perim = (double)s->perimeter;
        double circularity = perim > 0 ? (4.0 * M_PI * area) / (perim * perim) : 0.0;

        /* contour for complex shapes */
        NSArray<NSValue *> *localVerts = nil;
        NSUInteger vertexCount = 0;
        double contourAngleForRect = theta;
        double extentAlong = bw, extentPerp = bh;
        double centreAlong = 0, centrePerp = 0;      /* bbox centre in the rotated frame */
        CGPoint contourCentre = CGPointZero;
        if (cfg.allowComplexShapes && bw <= 1024 && bh <= 1024) {
            int mw = (int)bw, mh = (int)bh;
            uint8_t *mask = (uint8_t *)calloc((size_t)mw * (size_t)mh, 1);
            if (mask) {
                for (int y = s->minY; y <= s->maxY; y++) {
                    const int32_t *rowC = comp + (size_t)y * (size_t)W;
                    uint8_t *rowM = mask + (size_t)(y - s->minY) * (size_t)mw;
                    for (int x = s->minX; x <= s->maxX; x++) {
                        if (rowC[x] == i) rowM[x - s->minX] = 1;
                    }
                }
                size_t maxPts = 8192;
                CGPoint *trace = (CGPoint *)malloc(sizeof(CGPoint) * maxPts);
                size_t traced = trace ? CPM_trace_contour(mask, mw, mh, trace, maxPts) : 0;
                if (trace && traced >= 5) {
                    uint8_t *keepArr = (uint8_t *)calloc(traced, 1);
                    double useEps = eps;
                    size_t simplified = 0;
                    if (keepArr) {
                        keepArr[0] = 1;
                        keepArr[traced - 1] = 1;
                        CPM_douglas_peucker(trace, 0, traced - 1, useEps, keepArr);
                        for (size_t p = 0; p < traced; p++) if (keepArr[p]) simplified++;
                        /* enforce the vertex budget by growing epsilon */
                        while (simplified > (size_t)cfg.maxPolygonVertices && useEps < MAX(bw, bh)) {
                            useEps *= 1.4;
                            for (size_t p = 0; p < traced; p++) keepArr[p] = 0;
                            keepArr[0] = 1; keepArr[traced - 1] = 1;
                            CPM_douglas_peucker(trace, 0, traced - 1, useEps, keepArr);
                            simplified = 0;
                            for (size_t p = 0; p < traced; p++) if (keepArr[p]) simplified++;
                        }
                        if (simplified >= 3 && simplified <= (size_t)MAX(3, cfg.maxPolygonVertices)) {
                            CGPoint center = CGPointMake(s->minX + bw * 0.5, s->minY + bh * 0.5);
                            double cosT = cos(-theta), sinT = sin(-theta);
                            double minA = 1e9, maxA = -1e9, minB2 = 1e9, maxB2 = -1e9;
                            for (size_t p = 0; p < traced; p++) {
                                if (!keepArr[p]) continue;
                                double ax = (trace[p].x - center.x) * cosT - (trace[p].y - center.y) * sinT;
                                double ay = (trace[p].x - center.x) * sinT + (trace[p].y - center.y) * cosT;
                                minA = MIN(minA, ax); maxA = MAX(maxA, ax);
                                minB2 = MIN(minB2, ay); maxB2 = MAX(maxB2, ay);
                            }
                            double spanA = MAX(1e-6, maxA - minA);
                            double spanB = MAX(1e-6, maxB2 - minB2);
                            double midA = (minA + maxA) * 0.5, midB = (minB2 + maxB2) * 0.5;
                            contourCentre = center;
                            centreAlong = midA; centrePerp = midB;
                            NSMutableArray<NSValue *> *verts = [NSMutableArray arrayWithCapacity:simplified];
                            for (size_t p = 0; p < traced && verts.count < (NSUInteger)MAX(3, cfg.maxPolygonVertices); p++) {
                                if (!keepArr[p]) continue;
                                double ax = (trace[p].x - center.x) * cosT - (trace[p].y - center.y) * sinT;
                                double ay = (trace[p].x - center.x) * sinT + (trace[p].y - center.y) * cosT;
                                [verts addObject:[NSValue valueWithCGPoint:CGPointMake((ax - midA) / spanA,
                                                                                         (ay - midB) / spanB)]];
                            }
                            if (verts.count >= 3) {
                                localVerts = verts;
                                vertexCount = verts.count;
                                extentAlong = spanA;
                                extentPerp = spanB;
                                contourAngleForRect = theta;
                            } else {
                                centreAlong = 0; centrePerp = 0;
                            }
                        }
                    }
                    free(keepArr);
                    (void)useEps;
                }
                free(trace);
                free(mask);
            }
        }

        /*
         * Discriminators, all cheap and stable on downscaled art:
         *   fill          area / bbox area          (1.0 rect, 0.785 disk, 0.5 triangle)
         *   ellipseFill   area / inscribed-ellipse  (1.0 disk, 1.273 rect, 2.0 triangle)
         * The perimeter-based circularity is kept for the debug log only: edge-pixel
         * counts are a poor fit for thin/rotated shapes.
         */
        double ellipseFill = area / MAX(1e-6, M_PI * 0.25 * bw * bh);
        BOOL axisAligned = fill > 0.86 && aspect < 1.35;
        CPMShapeType kind = CPMShapeTypeSquare;
        double width = bw, height = bh, rotation = 0;
        if (aspect >= 4.0 && fill < 0.62) {
            kind = CPMShapeTypeLine;
            width = hypot(bw, bh);
            height = MAX(1.0, 2.0 * area / MAX(1.0, width));
            rotation = (bw >= bh) ? (atan2(bh, bw) * 180.0 / M_PI) : (90.0 - atan2(bw, bh) * 180.0 / M_PI);
            if (!cfg.allowRotation) { rotation = 0; width = MAX(bw, bh); height = MIN(bw, bh); }
        } else if (ellipseFill < 1.12 && aspect < 1.3 && !axisAligned) {
            kind = CPMShapeTypeCircle;
            width = MAX(bw, bh); height = width;
            rotation = 0;
        } else if (vertexCount == 3 && fill < 0.72) {
            kind = CPMShapeTypeTriangle;
            width = extentAlong; height = extentPerp;
            rotation = cfg.allowRotation ? contourAngleForRect * 180.0 / M_PI : 0;
        } else if (axisAligned) {
            kind = CPMShapeTypeSquare;
            width = bw; height = bh; rotation = 0;
        } else if (localVerts) {
            kind = CPMShapeTypePolygon;
            width = extentAlong; height = extentPerp;
            rotation = cfg.allowRotation ? contourAngleForRect * 180.0 / M_PI : 0;
        } else {
            kind = CPMShapeTypeSquare;
            width = bw; height = bh; rotation = 0;
        }
        if (kind == CPMShapeTypeCircle) rotation = 0;
        if (!cfg.allowRotation && kind != CPMShapeTypeLine) {
            rotation = 0;
        }
        if (!axisAligned && !localVerts) {
            /* rotated blob without a usable contour: fit the PCA box */
            double cosT = fabs(cos(theta)), sinT = fabs(sin(theta));
            double projA = bw * cosT + bh * sinT;
            double projB = bw * sinT + bh * cosT;
            width = MAX(1.0, projA);
            height = MAX(1.0, projB);
            if (cfg.allowRotation) rotation = theta * 180.0 / M_PI;
        }

        uint8_t cr = (uint8_t)MIN(255.0, (double)s->sumR / area + 0.5);
        uint8_t cg = (uint8_t)MIN(255.0, (double)s->sumG / area + 0.5);
        uint8_t cb = (uint8_t)MIN(255.0, (double)s->sumB / area + 0.5);
        uint8_t ca = cfg.keepAlpha ? (uint8_t)MIN(255.0, (double)s->sumA / area + 0.5) : 255;

        double shapeX = cx, shapeY = cy;
        if (localVerts && kind != CPMShapeTypeSquare) {
            double cosT = cos(contourAngleForRect), sinT = sin(contourAngleForRect);
            shapeX = contourCentre.x + centreAlong * cosT - centrePerp * sinT;
            shapeY = contourCentre.y + centreAlong * sinT + centrePerp * cosT;
        }
        CPMVinylShape *shape = [[CPMVinylShape alloc] initWithType:kind
                                                          position:CGPointMake(shapeX, shapeY)
                                                             scale:CGSizeMake(MAX(1.0, width), MAX(1.0, height))
                                                          rotation:CPMNormalizeAngle(rotation)
                                                             color:[UIColor colorWithRed:cr / 255.0
                                                                                    green:cg / 255.0
                                                                                     blue:cb / 255.0
                                                                                    alpha:1.0]
                                                           opacity:ca / 255.0];
        shape.areaPixels = area;
        (void)circularity;    /* debug aid: see the comment above */
        shape.zOrder = (NSInteger)emitted;
        shape.polygonVertices = localVerts;
        covered += s->area;
        [shapes addObject:shape];
        emitted++;
        if ((emitted & 0x0F) == 0) {
            [self reportProgress:0.7 + 0.25 * ((double)emitted / (double)MAX((NSUInteger)1, keptCandidates))
                           stage:@"building stickers"];
        }
    }
    if (cancelled) {
        free(comp); free(stats); free(labelMap);
        free(bucketLabel); free(classes); free(hist); free(buf);
        if (error) *error = CPMDecomposerError(CPMShapeDecomposerErrorCancelled, @"cancelled");
        return nil;
    }

    if (droppedBySize) {
        [warnings addObject:[NSString stringWithFormat:@"%lu tiny shape%@ below the area threshold were skipped",
                                                      (unsigned long)droppedBySize, droppedBySize == 1 ? @"" : @"s"]];
    }
    if (droppedByBudget) {
        [warnings addObject:[NSString stringWithFormat:@"%lu shape%@ dropped to fit the %ld-layer budget",
                                                      (unsigned long)droppedByBudget, droppedByBudget == 1 ? @"" : @"s",
                                                      (long)cfg.maxShapes]];
    }
    if (!exactColorMatch) {
        [warnings addObject:[NSString stringWithFormat:@"colors quantized to %lu class%@ (%@ distance)",
                                                      (unsigned long)classCount, classCount == 1 ? @"" : @"es",
                                                      cfg.distanceSpace == CPMColorDistanceSpaceSRGB ? @"sRGB" :
                                                      cfg.distanceSpace == CPMColorDistanceSpaceHueChroma ? @"hue/chroma" : @"Lab"]];
    }

    CPMShapeDecompositionResult *result = [[CPMShapeDecompositionResult alloc] init];
    result.shapes = shapes;
    NSMutableArray<UIColor *> *palette = [NSMutableArray array];
    for (NSUInteger c = 0; c < classCount; c++) {
        if (!classes[c].used) continue;
        CPMColorPoint p = classes[c].centroid;
        [palette addObject:[UIColor colorWithRed:p.r / 255.0 green:p.g / 255.0 blue:p.b / 255.0 alpha:p.a / 255.0]];
    }
    result.palette = palette;
    result.warnings = warnings;
    result.processingTime = [NSDate date].timeIntervalSinceReferenceDate - started;
    result.inputPixelCount = (NSUInteger)(W * H);
    result.foregroundPixelCount = (NSUInteger)foreground;
    result.coverageRatio = (CGFloat)((double)covered / (double)foreground);
    result.droppedShapeCount = droppedBySize + droppedByBudget;
    result.exactColorMatch = exactColorMatch;
    result.workingSize = CGSizeMake(W, H);

    free(comp); free(stats); free(labelMap);
    free(bucketLabel); free(classes); free(hist); free(buf);
    return result;
}

@end

#pragma mark - rasterization

/**
 * Draws `image` into a freshly allocated RGBA8 buffer, cropped to `roiRect` (which may
 * be CGRectNull for "the whole image") and downscaled so the longest side is at most
 * `maxDim`. Alpha is un-premultiplied so semi-transparent edges keep their color.
 * The caller frees *outBuffer.
 */
static BOOL CPMRenderImageToRGBA(UIImage *image, CGRect roiRect, NSInteger maxDim, BOOL keepAlpha,
                                 uint8_t **outBuffer, int *outW, int *outH, size_t *outRowBytes) {
    *outBuffer = NULL;
    if (!image) return NO;
    CGSize full = image.size;
    if (full.width < 1 || full.height < 1) return NO;

    CGRect roi = CGRectIsNull(roiRect) || CGRectIsEmpty(roiRect)
        ? CGRectMake(0, 0, full.width, full.height)
        : CGRectIntersection(roiRect, CGRectMake(0, 0, full.width, full.height));
    if (roi.size.width < 1 || roi.size.height < 1) return NO;

    NSInteger cap = MAX(64, maxDim);
    CGFloat scale = MIN(1.0, (CGFloat)cap / MAX(roi.size.width, roi.size.height));
    int w = (int)floor(roi.size.width * scale);
    int h = (int)floor(roi.size.height * scale);
    if (w < 2) w = 2;
    if (h < 2) h = 2;

    size_t rowBytes = ((size_t)w * 4 + 63) & ~(size_t)63;
    uint8_t *buf = (uint8_t *)calloc(rowBytes * (size_t)h, 1);
    if (!buf) return NO;

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!cs) cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf, (size_t)w, (size_t)h, 8, rowBytes, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) {
        if (cs) CGColorSpaceRelease(cs);
        free(buf);
        return NO;
    }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    if (!keepAlpha) {
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
    }
    /* CoreGraphics is origin-bottom; the vinyl model is y-down like UIKit. */
    CGContextTranslateCTM(ctx, 0, h);
    CGContextScaleCTM(ctx, 1, -1);
    CGImageRef cg = image.CGImage;
    if (cg) {
        CGRect src = CGRectMake(roi.origin.x / full.width * (CGFloat)CGImageGetWidth(cg),
                                roi.origin.y / full.height * (CGFloat)CGImageGetHeight(cg),
                                roi.size.width / full.width * (CGFloat)CGImageGetWidth(cg),
                                roi.size.height / full.height * (CGFloat)CGImageGetHeight(cg));
        CGImageRef sub = CGImageCreateWithImageInRect(cg, src);
        if (sub) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), sub);
            CGImageRelease(sub);
        }
    }
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);

    if (keepAlpha) {
        for (int y = 0; y < h; y++) {
            uint8_t *row = buf + (size_t)y * rowBytes;
            for (int x = 0; x < w; x++) {
                uint8_t *px = row + (size_t)x * 4;
                uint16_t a = px[3];
                if (a == 0) { px[0] = px[1] = px[2] = 0; continue; }
                if (a < 255) {
                    px[0] = (uint8_t)MIN(255, (px[0] * 255 + a / 2) / a);
                    px[1] = (uint8_t)MIN(255, (px[1] * 255 + a / 2) / a);
                    px[2] = (uint8_t)MIN(255, (px[2] * 255 + a / 2) / a);
                }
            }
        }
    }
    *outBuffer = buf;
    *outW = w;
    *outH = h;
    *outRowBytes = rowBytes;
    return YES;
}
