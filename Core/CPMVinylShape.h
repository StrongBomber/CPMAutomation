/**
 * CPMVinylShape.h
 * One sticker in the shape the game understands.
 *
 * The fields mirror `VinylsEditor.StickerItem` / `VinylData` (see
 * Core/CPMGameLayout.h, generated from dump.cs): a position, a size, an in-plane
 * rotation, two wrap angles for the car body, a color and a stacking order. There is
 * no such thing as a "stroke", an "opacity layer" or a free primitive list in CPM —
 * anything we invent here would silently be thrown away when the stickers are placed,
 * so every property below has a named counterpart in the game's data model.
 *
 * Units:
 *   position/scale  image points (y grows downward), converted to vinyl space by
 *                   -[CPMUICalibration …]; the vertical flip and the editor's
 *                   SCALE_COEF happen there, not here.
 *   components      0…1 (Unity's Color is float RGB, not 0…255)
 *   rotation        degrees around the sticker's own normal (the game's `euler.z`)
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Which shape the game's shape selector has to be set to before this sticker is drawn.
typedef NS_ENUM(NSInteger, CPMShapeType) {
    CPMShapeTypeSquare = 0,     // StickerItem with a quad mesh
    CPMShapeTypeCircle = 1,
    CPMShapeTypeTriangle = 2,
    CPMShapeTypeLine = 3,       // degenerate quad: a long thin sticker
    CPMShapeTypePolygon = 4,    // quad + scaleQuadEuler / mesh vertices
    CPMShapeTypeText = 5,       // StickerItem.isText + text/fontIndex/bold/italic
};

FOUNDATION_EXPORT NSString *CPMShapeTypeName(CPMShapeType type);

@interface CPMVinylShape : NSObject <NSCopying>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) CPMShapeType shapeType;

/// Center of the sticker, image points.
@property (nonatomic, assign) CGPoint position;
/// Size of the sticker, image points (w, h). Always positive.
@property (nonatomic, assign) CGSize scale;
/// In-plane rotation in degrees, clockwise.
@property (nonatomic, assign) CGFloat rotationDegrees;
/// Wrap around the car surface (StickerItem.yAngle / xAngle), degrees.
@property (nonatomic, assign) CGFloat yAngle;
@property (nonatomic, assign) CGFloat xAngle;
/// Depth: distance from the painted surface. 0 = flush.
@property (nonatomic, assign) CGFloat zDepth;
/// Paint order; the game stores this as `Order` (0 … n).
@property (nonatomic, assign) NSInteger zOrder;
@property (nonatomic, assign) BOOL flipX;

@property (nonatomic, assign) CGFloat redComponent;
@property (nonatomic, assign) CGFloat greenComponent;
@property (nonatomic, assign) CGFloat blueComponent;
@property (nonatomic, assign) CGFloat alphaComponent;

/// Convenience views over the four components.
@property (nonatomic, readonly) UIColor *color;
@property (nonatomic, readonly) CGFloat opacity;              // == alphaComponent
@property (nonatomic, readonly) uint32_t packedColorRGBA;     // 0xRRGGBBAA, our own format

/// Polygon outline in the sticker's *local* frame: already un-rotated and normalized
/// to -0.5…0.5 on both axes, so it can be multiplied by `scale` and rotated by
/// `rotationDegrees` to get back to image points. Each NSValue holds a CGPoint.
@property (nonatomic, copy, nullable) NSArray<NSValue *> *polygonVertices;

/// Text stickers only (StickerItem.isText).
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, assign) NSInteger fontIndex;
@property (nonatomic, assign) BOOL bold;
@property (nonatomic, assign) BOOL italic;

/// Area in image pixels², used for ordering and for the coverage report.
@property (nonatomic, assign) CGFloat areaPixels;

- (instancetype)initWithType:(CPMShapeType)type
                    position:(CGPoint)pos
                       scale:(CGSize)size
                    rotation:(CGFloat)rotationDegrees
                       color:(UIColor *)color
                         opacity:(CGFloat)opacity NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

+ (instancetype)squareAtPosition:(CGPoint)pos side:(CGFloat)side
                        rotation:(CGFloat)rotationDegrees color:(UIColor *)color;
+ (instancetype)circleAtPosition:(CGPoint)pos diameter:(CGFloat)diameter
                            color:(UIColor *)color;
+ (instancetype)lineFrom:(CGPoint)startPoint to:(CGPoint)endPoint
                   width:(CGFloat)width color:(UIColor *)color;

/// Axis-aligned bounding box of the (rotated) sticker in image points.
@property (nonatomic, readonly) CGRect bounds;
/// The local polygon, or a generated outline matching `shapeType` when there is none.
- (NSArray<NSValue *> *)outlineInImagePoints;
/// YES when the sticker lies inside `rect` (used by the ROI preview).
- (BOOL)isInsideRect:(CGRect)rect;

- (instancetype)shapeByOffsettingBy:(CGPoint)delta andScalingBy:(CGFloat)factor;
- (instancetype)shapeWithOrder:(NSInteger)order;

/// JSON-safe dictionary (save files, previews, the debug log).
- (NSDictionary<NSString *, id> *)toCPMParametersDictionary;
+ (nullable instancetype)shapeWithDictionary:(NSDictionary<NSString *, id> *)dict;
- (NSString *)debugDescription;

@end

NS_ASSUME_NONNULL_END
