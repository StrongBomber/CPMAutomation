/**
 * CPMUICalibration.h
 *
 * Two jobs, both about turning numbers into taps and back:
 *
 *  1. UI anchors — where the vinyl editor's controls (shape list, colour picker,
 *     R/G/B / scale / rotate sliders, joystick, confirm/cancel) sit on screen. The
 *     compiled-in table comes from Resources/cpm_ui_anchors.json via
 *     tools/cpm_anchors.py (Core/CPMAnchorsDefault.h): the dylib is injected into the
 *     game's bundle, so a JSON shipped inside this tweak could never be read at runtime.
 *     A user-verified profile stored in UserDefaults overrides it.
 *
 *  2. The vinyl canvas — the on-screen rectangle the painted surface maps onto, so an
 *     image-space point can be turned into a screen point (and back, for previews).
 *
 * Anchor coordinates are *reference points* (see CPM_ANCHOR_REFERENCE_WIDTH/HEIGHT) and
 * are scaled independently on X and Y onto the actual screen; the canvas rect lives in
 * real screen points and is what the ROI editor writes.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPMUIElementType) {
    CPMUIElementTypeAddShape = 0,       // creates a sticker (VinylsEditor CreateSticker)
    CPMUIElementTypeShapeSelector = 1,  // square/circle/triangle/text row (stickersWidget)
    CPMUIElementTypeColorPicker = 2,    // opens the colour grid (ChangeColor)
    CPMUIElementTypeRedSlider = 3,
    CPMUIElementTypeGreenSlider = 4,
    CPMUIElementTypeBlueSlider = 5,
    CPMUIElementTypeScaleSlider = 6,
    CPMUIElementTypeRotateSlider = 7,
    CPMUIElementTypeMoveJoystick = 8,   // JoystickNGUI
    CPMUIElementTypeConfirmButton = 9,  // SaveVinyl
    CPMUIElementTypeCancelButton = 10,  // CleanStuff / DeleteStickers
    CPMUIElementTypeLayerListView = 11, // stickersScrollBar: picks the layer to edit
    CPMUIElementTypeZoomControl = 12,
    CPMUIElementTypeCount = 13,
};

FOUNDATION_EXPORT NSString *CPMUIElementTypeName(CPMUIElementType type);

@interface CPMUIElementAnchor : NSObject <NSCopying>

@property (nonatomic, assign) CPMUIElementType elementType;
/// All geometry below is in *reference* points, origin top-left, y down.
@property (nonatomic, assign) CGPoint center;
@property (nonatomic, assign) CGSize size;
/// Slider track ends (reference points). Ignored for non-sliders.
@property (nonatomic, assign) CGFloat sliderMinX;
@property (nonatomic, assign) CGFloat sliderMaxX;
@property (nonatomic, assign) CGFloat sliderMinY;
@property (nonatomic, assign) CGFloat sliderMaxY;
/// NGUI's UISlider.mInverted: value 1 sits at the *left* end.
@property (nonatomic, assign) BOOL inverted;
@property (nonatomic, copy, nullable) NSString *displayName;
@property (nonatomic, assign) BOOL isValid;

@property (nonatomic, readonly) BOOL isSlider;
@property (nonatomic, readonly) CGRect referenceFrame;

/// 0…1 along the track → the point a finger has to sit on.
- (CGPoint)referencePointForValue:(CGFloat)value;
- (CGFloat)valueForReferencePoint:(CGPoint)point;
- (BOOL)containsReferencePoint:(CGPoint)point;

- (NSDictionary<NSString *, id> *)toDictionary;
+ (nullable instancetype)anchorFromDictionary:(NSDictionary<NSString *, id> *)dict;

@end

@interface CPMUICalibration : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *calibrationID;
@property (nonatomic, assign, readonly) CGSize referenceScreenSize;
@property (nonatomic, assign, readonly) CGSize screenSize;
/// reference size / screen size — below 1 the reference art is being upscaled.
@property (nonatomic, assign, readonly) CGFloat scaleFactor;
@property (nonatomic, assign, readonly) BOOL isLandscape;
@property (nonatomic, copy, readonly) NSArray<CPMUIElementAnchor *> *anchors;
/// Screen rect of the painted surface. CGRectNull = derived from the screen size.
@property (nonatomic, assign) CGRect canvasRect;
/// YES once the user has dragged the canvas / anchors themselves.
@property (nonatomic, assign) BOOL userVerified;
/// NO when the profile's orientation does not match the screen: taps would be meaningless.
@property (nonatomic, readonly) BOOL isUsableForCurrentScreen;

/// The compiled-in table (CPMAnchorsDefault.h) scaled to `screenSize`.
+ (instancetype)defaultCalibration;
+ (instancetype)defaultCalibrationForScreenSize:(CGSize)screenSize;
/// From a previously saved / exported profile.
+ (instancetype)calibrationFromJSON:(NSDictionary<NSString *, id> *)json;
- (NSDictionary<NSString *, id> *)toJSON;

- (nullable CPMUIElementAnchor *)anchorForType:(CPMUIElementType)type;
- (void)setAnchor:(CPMUIElementAnchor *)anchor forType:(CPMUIElementType)type;
- (void)shiftAllAnchorsBy:(CGPoint)delta;
/// Nudges one anchor; the ROI editor's fine-tune buttons use this.
- (void)shiftAnchorForType:(CPMUIElementType)type by:(CGPoint)delta;

#pragma mark space conversions

- (CGPoint)screenPointForReferencePoint:(CGPoint)referencePoint;
- (CGRect)screenRectForReferenceRect:(CGRect)referenceRect;
- (CGPoint)referencePointForScreenPoint:(CGPoint)screenPoint;

/// Image (decomposer) space → screen points. `imageSize` is the ROI the shapes were
/// produced from, in working pixels; the fit is aspect-preserving inside canvasRect.
- (CGPoint)mappedPositionFromImagePosition:(CGPoint)imagePosition imageSize:(CGSize)imageSize;
- (CGRect)mappedRectFromImageRect:(CGRect)imageRect imageSize:(CGSize)imageSize;
/// Screen → image space (previews, hit-testing the overlay).
- (CGPoint)imagePositionForScreenPoint:(CGPoint)screenPoint imageSize:(CGSize)imageSize;

#pragma mark diagnostics / persistence

/// Multi-line, user-facing: what is guessed, what is missing, what does not fit.
- (NSString *)validationReport;
- (void)saveToUserDefaults;
+ (nullable instancetype)loadFromUserDefaults;
+ (nullable instancetype)loadFromUserDefaultsForID:(nullable NSString *)calibrationID;
+ (void)clearSavedCalibration;

@end

NS_ASSUME_NONNULL_END
