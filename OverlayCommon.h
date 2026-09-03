/**
 * OverlayTweak — shared macros, version, UserDefaults keys.
 * Extended for Car Parking Multiplayer (CPM) Image-to-Vinyl Automation.
 */

#ifndef OverlayCommon_h
#define OverlayCommon_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define OLLog(fmt, ...) NSLog(@"[OverlayTweak] " fmt, ##__VA_ARGS__)
#define CPM_LOG(fmt, ...) NSLog(@"[CPM-Automation] " fmt, ##__VA_ARGS__)

static NSString * const kOLVersion = @"2.1.0-CPM-Automation";

/* ==========================================================================
 * Original OverlayTweak UserDefaults keys
 * ========================================================================== */
static NSString * const kDefaultsOpacity        = @"overlay_opacity";
static NSString * const kDefaultsPositionX      = @"overlay_position_x";
static NSString * const kDefaultsPositionY      = @"overlay_position_y";
static NSString * const kDefaultsScale          = @"overlay_scale";
static NSString * const kDefaultsRotation       = @"overlay_rotation";
static NSString * const kDefaultsImageBookmark  = @"overlay_image_data"; /* legacy */
static NSString * const kDefaultsIsLocked       = @"overlay_is_locked";
static NSString * const kDefaultsOverlayVisible = @"overlay_visible";
static NSString * const kDefaultsMenuX          = @"overlay_menu_x";
static NSString * const kDefaultsMenuY          = @"overlay_menu_y";
static NSString * const kDefaultsMenuHidden     = @"overlay_menu_hidden";
static NSString * const kDefaultsFlipH          = @"overlay_flip_h";
static NSString * const kDefaultsFlipV          = @"overlay_flip_v";
static NSString * const kDefaultsContentMode    = @"overlay_content_mode";
static NSString * const kDefaultsWelcomeShown   = @"overlay_welcome_shown";
static NSString * const kDefaultsHasOpacity     = @"overlay_has_opacity";
static NSString * const kDefaultsSizeMode       = @"overlay_size_mode";   /* 0 = follow image, 1 = custom */
static NSString * const kDefaultsCustomWidth    = @"overlay_custom_w";
static NSString * const kDefaultsCustomHeight   = @"overlay_custom_h";
static NSString * const kDefaultsShowsBorder    = @"overlay_shows_border";
static NSString * const kDefaultsShowsGrid      = @"overlay_shows_grid";
static NSString * const kDefaultsPitch          = @"overlay_pitch";
static NSString * const kDefaultsYaw            = @"overlay_yaw";
static NSString * const kDefaultsCropL          = @"overlay_crop_l";
static NSString * const kDefaultsCropR          = @"overlay_crop_r";
static NSString * const kDefaultsCropT          = @"overlay_crop_t";
static NSString * const kDefaultsCropB          = @"overlay_crop_b";
static NSString * const kDefaultsWarpPts        = @"overlay_warp_pts";

/* ==========================================================================
 * CPM Automation UserDefaults keys
 * ========================================================================== */
static NSString * const kCPMDefaultsUIAnchors     = @"cpm_ui_anchors";
static NSString * const kCPMDefaultsAutoDrawActive = @"cpm_autodraw_active";
static NSString * const kCPMDefaultsAutoDrawPaused = @"cpm_autodraw_paused";
static NSString * const kCPMDefaultsLayerLimit    = @"cpm_layer_limit";
static NSString * const kCPMDefaultsTouchDelay    = @"cpm_touch_delay_ms";
static NSString * const kCPMDefaultsReferenceImage = @"cpm_reference_image";
static NSString * const kCPMDefaultsROIRect       = @"cpm_roi_rect";
static NSString * const kCPMDefaultsCalibrationVersion = @"cpm_calibration_version";
static NSString * const kCPMDefaultsLastSessionShapes = @"cpm_last_session_shapes";
static NSString * const kCPMDefaultsEmergencyStop = @"cpm_emergency_stop";
static NSString * const kCPMDefaultsPreviewOnly     = @"cpm_preview_only";
/* The canvas rect the ROI was drawn on lives inside the calibration blob
 * (CPMUICalibration -saveToUserDefaults), so it deliberately has no key here. */
static NSString * const kCPMDefaultsAutoSave        = @"cpm_autosave_vinyl";

/* ==========================================================================
 * CPM Automation — shared enums live with their module (single definition!)
 *
 *   CPMShapeType               -> Core/CPMVinylShape.h
 *   CPMColorQuantizationMethod -> Core/CPMShapeDecomposer.h
 *   CPMAutomationStep          -> Core/CPMExecutionController.h
 *   CPMUIElementType           -> Core/CPMUICalibration.h
 *   IL2CPP layout / enums      -> Core/CPMGameLayout.h (generated from dump.cs)
 *
 * v2.0 declared a second copy of several of these here; a duplicate
 * `CPMShapeTypeSquare` in the same translation unit is a hard compile error,
 * which is exactly why `make` was failing. They are imported instead.
 * ========================================================================== */
#import "CPMVinylShape.h"
#import "CPMShapeDecomposer.h"
#import "CPMExecutionController.h"
#import "CPMUICalibration.h"
#import "CPMGameLayout.h"

/* ==========================================================================
 * CPM Vinyl Editor model (read from dump.cs, see cpm_il2cpp_layout.json)
 *
 * A CPM "vinyl" is not a vector shape: the editor's StickerItem is a textured
 * quad with position / scale / euler angles / colour / draw order, grouped per
 * VinylsType (Car = 1, Plate = 2, Clan = 3, Window = 4). Every layer we emit
 * is therefore a coloured quad, which is what the game can actually place.
 * ========================================================================== */
typedef NS_ENUM(NSInteger, CPMScreenOrientation) {
    CPMScreenOrientationPortrait = 0,
    CPMScreenOrientationLandscapeLeft = 1,
    CPMScreenOrientationLandscapeRight = 2,
    CPMScreenOrientationPortraitUpsideDown = 3
};

/* ==========================================================================
 * Scalar helpers shared by the CPM modules (there is no `clamp()` in C).
 * ========================================================================== */
__attribute__((unused)) static inline CGFloat CPMClamp(CGFloat v, CGFloat lo, CGFloat hi) {
    return (v < lo) ? lo : (v > hi ? hi : v);
}

__attribute__((unused)) static inline CGFloat CPMMapRange(CGFloat v, CGFloat inLo, CGFloat inHi, CGFloat outLo, CGFloat outHi) {
    if (inHi == inLo) return outLo;
    return outLo + (v - inLo) / (inHi - inLo) * (outHi - outLo);
}

/// Wrap an angle in degrees into [0, 360).
__attribute__((unused)) static inline CGFloat CPMNormalizeAngle(CGFloat deg) {
    CGFloat r = fmod(deg, 360.0);
    return r < 0 ? r + 360.0 : r;
}

/// Shortest signed difference between two angles, in degrees (-180...180].
__attribute__((unused)) static inline CGFloat CPMAngleDelta(CGFloat from, CGFloat to) {
    return CPMNormalizeAngle(to - from + 180.0) - 180.0;
}

__attribute__((unused)) static inline uint32_t CPMPackRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    /* Matches VinylData.color (UnityEngine.Color32 packed as RGBA bytes). */
    uint32_t R = (uint32_t)CPMClamp(r, 0, 255);
    uint32_t G = (uint32_t)CPMClamp(g, 0, 255);
    uint32_t B = (uint32_t)CPMClamp(b, 0, 255);
    uint32_t A = (uint32_t)CPMClamp(a, 0, 255);
    return (R << 24) | (G << 16) | (B << 8) | A;
}

#endif /* OverlayCommon_h */
