/**
 * CPMIl2CppBridge.h
 *
 * Read-only view into the running game, built on the IL2CPP metadata.
 *
 * The dump.cs-derived tables in CPMGameLayout.{h,m} tell us *where* things live;
 * this bridge resolves the IL2CPP C API at runtime (dlsym, never a hard link) and
 * answers the two questions the automation cannot guess:
 *
 *   - is CPM's vinyl editor actually open right now?          (editorLoaded)
 *   - how many layers may this car take?                      (maxLayers)
 *
 * plus a live offset check, so an offset that moved after a game update is
 * corrected from the running binary instead of blindly trusted.
 *
 * NOTHING here writes to the game: no method calls, no patched code, no memory
 * pokes. The automation still drives CPM through synthesised touches; this is
 * the feedback channel that turns "tap blindly and hope" into "tap, then verify".
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CPMGameLayout.h"

NS_ASSUME_NONNULL_BEGIN

/** One CPM vinyl layer as the game currently holds it (StickerItem). */
@interface CPMStickerReadout : NSObject

@property (nonatomic, assign) CGPoint position;        ///< StickerItem.position (x,y)
@property (nonatomic, assign) CGFloat depth;           ///< StickerItem.position.z
@property (nonatomic, assign) CGSize size;             ///< StickerItem.scale (x,y)
@property (nonatomic, assign) CGFloat rotationDegrees; ///< StickerItem.yAngle
@property (nonatomic, assign) CGFloat red;             ///< _color.r * 255
@property (nonatomic, assign) CGFloat green;
@property (nonatomic, assign) CGFloat blue;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) NSInteger order;         ///< StickerItem.Order
@property (nonatomic, assign) NSInteger index;         ///< StickerItem.stckerIndex
@property (nonatomic, assign) BOOL isText;
@property (nonatomic, copy, nullable) NSString *text;

- (NSString *)summaryString;

@end

/** Snapshot of CPM.Scripts.VinylDrawer.VinylsEditor, refreshed on demand. */
@interface CPMEditorReadout : NSObject

/// YES when the il2cpp C API could be resolved from the host binary.
@property (nonatomic, assign, readonly) BOOL bridgeAvailable;
/// YES when the live field offsets matched the dump the layout was built from.
@property (nonatomic, assign, readonly) BOOL layoutMatchesDump;
/// Number of offsets that differed from dump.cs (already corrected in-memory).
@property (nonatomic, assign, readonly) NSInteger layoutDriftCount;
/// Set when the drift is large enough that the anchors should be re-calibrated.
@property (nonatomic, assign, readonly) BOOL layoutStale;

/// Editor state.
@property (nonatomic, assign, readonly) BOOL editorFound;
@property (nonatomic, assign, readonly) BOOL editorLoaded;
@property (nonatomic, assign, readonly) BOOL hasVinyl;
@property (nonatomic, assign, readonly) BOOL isEditingExisting;
@property (nonatomic, assign, readonly) BOOL isDragging;
@property (nonatomic, assign, readonly) BOOL saved;

@property (nonatomic, assign, readonly) NSInteger layerCount;   ///< _allStickers.Count
@property (nonatomic, assign, readonly) NSInteger maxLayers;    ///< _maxVinylsCount
@property (nonatomic, assign, readonly) NSInteger vinylsType;   ///< _currentVinylsType (CPMGameEVinylsType*)
@property (nonatomic, assign, readonly) NSInteger operation;    ///< _currentOperation  (VinylsEditorOperation)
@property (nonatomic, assign, readonly) NSInteger currentPackedColor; ///< Color32-ish of the selected layer

@property (nonatomic, strong, readonly, nullable) CPMStickerReadout *currentSticker;

/// "il2cpp ok / layout 2 drift / editor open / 41 of 300 layers" — safe for the UI.
@property (nonatomic, copy, readonly) NSString *summaryString;
/// Multi-line detail for the log / the diagnostics row in the panel.
@property (nonatomic, copy, readonly) NSString *detailString;

@end

@interface CPMIl2CppBridge : NSObject

+ (instancetype)sharedBridge;

/// YES once the il2cpp entry points resolved. NO on a stripped build, in which case
/// every consumer must fall back to dump-relative blind operation.
@property (nonatomic, assign, readonly) BOOL isAvailable;
@property (nonatomic, copy, readonly, nullable) NSString *unavailableReason;

/// The generated layout's signature, e.g. dump sha + field coverage.
@property (nonatomic, copy, readonly) NSString *layoutSignature;

/// Cheap: a handful of validated pointer chases. Call on the main thread.
/** VinylsEditor is created by the game's DI container, so read-only mode can only see
 *  the editor *scene* (VinylDrawer._instance / HasVinyl). If the caller already knows
 *  the instance address, setting it here unlocks the per-layer readback used for
 *  closed-loop placement. The tweak never derives this and never writes through it. */
@property (nonatomic, assign) uintptr_t knownEditorInstance;

- (CPMEditorReadout *)refresh;

/// Most recent refresh result (never nil).
@property (nonatomic, strong, readonly) CPMEditorReadout *lastReadout;

/** Live offset for a layout entry, or -1 when unknown. Used by the drift check and
 *  by anything that must survive a game update without a re-dump. */
- (NSInteger)liveOffsetForField:(CPMGameFieldID)field;

/// YES when the game module the class belongs to is loaded (Assembly-CSharp.dll …).
- (BOOL)isClassResolvable:(CPMGameClassID)cls;

/** A one-shot report that is worth pasting into an issue: dump hash, resolved
 *  symbols, offset drift, editor state. */
- (NSString *)diagnosticsReport;

@end

NS_ASSUME_NONNULL_END
