/**
 * CPMIl2CppBridge.m
 *
 * Read-only IL2CPP introspection. See CPMIl2CppBridge.h for the contract.
 *
 * Implementation rules that keep this safe inside a shipping game:
 *   - the il2cpp C API is resolved with dlsym(); nothing is linked, so the dylib
 *     still loads on builds that strip those symbols;
 *   - every dereference goes through CPMReadBytes(), which asks the kernel whether
 *     the range is mapped (vm_read_overwrite on our own task) — a bad offset can
 *     therefore never SIGSEGV the game;
 *   - no method is ever invoked and no byte outside our own process data is written.
 */
#import "CPMIl2CppBridge.h"
#import "OverlayCommon.h"

#import <dlfcn.h>
#import <mach/mach.h>
#import <string.h>

#pragma mark - il2cpp ABI (opaque pointers only)

typedef void *CPMIl2CppPtr;

typedef CPMIl2CppPtr (*CPMFnDomainGet)(void);
typedef CPMIl2CppPtr (*CPMFnDomainGetAssemblies)(CPMIl2CppPtr domain, size_t *outSize);
typedef CPMIl2CppPtr (*CPMFnAssemblyGetImage)(CPMIl2CppPtr assembly);
typedef const char *(*CPMFnImageGetName)(CPMIl2CppPtr image);
typedef CPMIl2CppPtr (*CPMFnClassFromName)(CPMIl2CppPtr image, const char *namesp, const char *name);
typedef CPMIl2CppPtr (*CPMFnObjectGetClass)(CPMIl2CppPtr obj);
typedef CPMIl2CppPtr (*CPMFnClassGetFieldFromName)(CPMIl2CppPtr klass, const char *name);
typedef size_t (*CPMFnFieldGetOffset)(CPMIl2CppPtr field);
typedef void (*CPMFnFieldStaticGetValue)(CPMIl2CppPtr field, void *value);
typedef const char *(*CPMFnFieldName)(CPMIl2CppPtr field);

@interface CPMIl2CppBridge () {
    uintptr_t _knownEditorInstance;
    CPMFnDomainGet _domainGet;
    CPMFnDomainGetAssemblies _domainGetAssemblies;
    CPMFnAssemblyGetImage _assemblyGetImage;
    CPMFnImageGetName _imageGetName;
    CPMFnClassFromName _classFromName;
    CPMFnObjectGetClass _objectGetClass;
    CPMFnClassGetFieldFromName _classGetFieldFromName;
    CPMFnFieldGetOffset _fieldGetOffset;
    CPMFnFieldStaticGetValue _fieldStaticGetValue;
    CPMFnFieldName _fieldName;
}
@property (nonatomic, assign, readwrite) BOOL isAvailable;
@property (nonatomic, copy, readwrite, nullable) NSString *unavailableReason;
@property (nonatomic, strong, readwrite) CPMEditorReadout *lastReadout;
/// field id -> live offset, only for entries that differ from the dump
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *offsetOverrides;
/// class id -> resolved Il2CppClass* (boxed in NSValue so it survives ARC)
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSValue *> *classCache;
@property (nonatomic, assign) CPMIl2CppPtr domain;
/// 0 until a caller hands us a VinylsEditor* (see header).
@end

#pragma mark - memory-safe reads

/// Copies `len` bytes from base+offset into dst, but only when the kernel says the
/// range is readable. Returns NO instead of crashing on a stale offset.
static BOOL CPMReadBytes(const void *base, NSUInteger offset, void *dst, size_t len) {
    if (!base || !dst || len == 0) return NO;
    vm_address_t src = (vm_address_t)((uintptr_t)base + (uintptr_t)offset);
    vm_size_t out = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), src, (vm_size_t)len,
                                         (vm_address_t)dst, &out);
    return (kr == KERN_SUCCESS && out == (vm_size_t)len);
}

static BOOL CPMReadPointer(const void *base, NSUInteger offset, void **outPtr) {
    uintptr_t raw = 0;
    if (!CPMReadBytes(base, offset, &raw, sizeof(raw))) return NO;
    /* Il2CppObject pointers on arm64 are 8-byte aligned; reject garbage early. */
    if (raw != 0 && (raw & 0x7) != 0) return NO;
    *outPtr = (void *)raw;
    return YES;
}

static BOOL CPMReadInt32(const void *base, NSUInteger offset, int32_t *outValue) {
    return CPMReadBytes(base, offset, outValue, sizeof(int32_t));
}

static BOOL CPMReadUInt8(const void *base, NSUInteger offset, uint8_t *outValue) {
    return CPMReadBytes(base, offset, outValue, sizeof(uint8_t));
}

static BOOL CPMReadFloat(const void *base, NSUInteger offset, CGFloat *outValue) {
    float f = 0;
    if (!CPMReadBytes(base, offset, &f, sizeof(f))) return NO;
    if (outValue) *outValue = (CGFloat)f;
    return YES;
}

static BOOL CPMReadVector3(const void *base, NSUInteger offset, CGFloat out[3]) {
    float v[3] = {0, 0, 0};
    if (!CPMReadBytes(base, offset, v, sizeof(v))) return NO;
    out[0] = v[0]; out[1] = v[1]; out[2] = v[2];
    return YES;
}

static BOOL CPMReadColor(const void *base, NSUInteger offset, CGFloat out[4]) {
    float v[4] = {0, 0, 0, 1};
    if (!CPMReadBytes(base, offset, v, sizeof(v))) return NO;
    out[0] = v[0]; out[1] = v[1]; out[2] = v[2]; out[3] = v[3];
    return YES;
}

/// Il2CppString layout: [klass 0x0][monitor 0x8][length 0x10][utf16 chars 0x14]
static NSString *CPMReadIl2CppString(const void *base, NSUInteger offset) {
    void *str = NULL;
    if (!CPMReadPointer(base, offset, &str) || !str) return nil;
    int32_t length = 0;
    if (!CPMReadBytes(str, 0x10, &length, sizeof(length))) return nil;
    if (length <= 0 || length > 256) return nil;
    unichar buffer[257];
    if (!CPMReadBytes(str, 0x14, buffer, (size_t)length * sizeof(unichar))) return nil;
    return [NSString stringWithCharacters:buffer length:(NSUInteger)length];
}

#pragma mark - CPMStickerReadout

@implementation CPMStickerReadout

- (NSString *)summaryString {
    return [NSString stringWithFormat:@"#%ld order=%ld pos=(%.2f, %.2f) size=(%.2f, %.2f) rot=%.1f%@%@",
            (long)self.index, (long)self.order,
            self.position.x, self.position.y, self.size.width, self.size.height,
            self.rotationDegrees,
            self.isText ? @" text" : @"",
            self.text.length ? [NSString stringWithFormat:@":\"%@\"", self.text] : @""];
}

@end

#pragma mark - CPMEditorReadout

@interface CPMEditorReadout ()
@property (nonatomic, assign, readwrite) BOOL bridgeAvailable;
@property (nonatomic, assign, readwrite) BOOL layoutMatchesDump;
@property (nonatomic, assign, readwrite) NSInteger layoutDriftCount;
@property (nonatomic, assign, readwrite) BOOL layoutStale;
@property (nonatomic, assign, readwrite) BOOL editorFound;
@property (nonatomic, assign, readwrite) BOOL editorLoaded;
@property (nonatomic, assign, readwrite) BOOL hasVinyl;
@property (nonatomic, assign, readwrite) BOOL isEditingExisting;
@property (nonatomic, assign, readwrite) BOOL isDragging;
@property (nonatomic, assign, readwrite) BOOL saved;
@property (nonatomic, assign, readwrite) NSInteger layerCount;
@property (nonatomic, assign, readwrite) NSInteger maxLayers;
@property (nonatomic, assign, readwrite) NSInteger vinylsType;
@property (nonatomic, assign, readwrite) NSInteger operation;
@property (nonatomic, assign, readwrite) NSInteger currentPackedColor;
@property (nonatomic, strong, readwrite, nullable) CPMStickerReadout *currentSticker;
@property (nonatomic, copy, readwrite) NSString *summaryString;
@property (nonatomic, copy, readwrite) NSString *detailString;
@end

@implementation CPMEditorReadout

- (instancetype)init {
    self = [super init];
    if (self) {
        _layerCount = NSNotFound;
        _maxLayers = NSNotFound;
        _vinylsType = CPMGameEVinylsTypeNone;
        _operation = CPMGameEVinylsEditorOperationNone;
        _layoutMatchesDump = YES;
        _summaryString = @"IL2CPP bridge not refreshed";
        _detailString = @"";
    }
    return self;
}

@end

#pragma mark - CPMIl2CppBridge

@implementation CPMIl2CppBridge

+ (instancetype)sharedBridge {
    static CPMIl2CppBridge *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CPMIl2CppBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _offsetOverrides = [NSMutableDictionary dictionary];
        _classCache = [NSMutableDictionary dictionary];
        _lastReadout = [[CPMEditorReadout alloc] init];
        [self resolveSymbols];
    }
    return self;
}

static void *CPMSym(const char *name) {
    void *p = dlsym(RTLD_DEFAULT, name);
    if (!p) {
        void *handle = dlopen("/usr/lib/libil2cpp.dylib", RTLD_LAZY); /* rare, non-fatal */
        if (handle) p = dlsym(handle, name);
    }
    return p;
}

- (void)resolveSymbols {
    _domainGet = (CPMFnDomainGet)CPMSym("il2cpp_domain_get");
    _domainGetAssemblies = (CPMFnDomainGetAssemblies)CPMSym("il2cpp_domain_get_assemblies");
    _assemblyGetImage = (CPMFnAssemblyGetImage)CPMSym("il2cpp_assembly_get_image");
    _imageGetName = (CPMFnImageGetName)CPMSym("il2cpp_image_get_name");
    _classFromName = (CPMFnClassFromName)CPMSym("il2cpp_class_from_name");
    _objectGetClass = (CPMFnObjectGetClass)CPMSym("il2cpp_object_get_class");
    _classGetFieldFromName = (CPMFnClassGetFieldFromName)CPMSym("il2cpp_class_get_field_from_name");
    _fieldGetOffset = (CPMFnFieldGetOffset)CPMSym("il2cpp_field_get_offset");
    _fieldStaticGetValue = (CPMFnFieldStaticGetValue)CPMSym("il2cpp_field_static_get_value");
    _fieldName = (CPMFnFieldName)CPMSym("il2cpp_field_get_name");

    if (!_domainGet || !_classFromName || !_classGetFieldFromName || !_fieldGetOffset) {
        self.isAvailable = NO;
        self.unavailableReason =
            @"il2cpp symbols not exported by the game binary (stripped release build?) — "
             "falling back to dump.cs offsets, no live verification";
        CPM_LOG(@"%@", self.unavailableReason);
        return;
    }
    self.isAvailable = YES;
    self.domain = _domainGet();
    if (_domainGetAssemblies) {
        size_t count = 0;
        _domainGetAssemblies(self.domain, &count);
        CPM_LOG(@"il2cpp bridge online: %d of 10 entry points, %zu assemblies",
                (int)(6 + (_domainGetAssemblies ? 1 : 0) + (_assemblyGetImage ? 1 : 0)
                        + (_imageGetName ? 1 : 0) + (_objectGetClass ? 1 : 0)
                        + (_fieldStaticGetValue ? 1 : 0) + (_fieldName ? 1 : 0)), count);
    } else {
        CPM_LOG(@"il2cpp bridge online (no assembly enumeration)");
    }
}

- (NSString *)layoutSignature {
    return CPMGameLayoutSignature();
}

#pragma mark class / field resolution

- (CPMIl2CppPtr)imageForAssembly:(const char *)assemblyName {
    if (!assemblyName || !_domainGetAssemblies || !_assemblyGetImage) return NULL;
    size_t count = 0;
    CPMIl2CppPtr *assemblies = (CPMIl2CppPtr *)_domainGetAssemblies(self.domain, &count);
    if (!assemblies || count == 0) return NULL;
    for (size_t i = 0; i < count; i++) {
        CPMIl2CppPtr image = _assemblyGetImage(assemblies[i]);
        if (!image) continue;
        const char *name = _imageGetName ? _imageGetName(image) : NULL;
        if (name && strcmp(name, assemblyName) == 0) return image;
    }
    return NULL;
}

- (CPMIl2CppPtr)classForId:(CPMGameClassID)cls {
    NSNumber *key = @(cls);
    NSValue *cached = self.classCache[key];
    if (cached) return cached.pointerValue;
    if (!self.isAvailable) return NULL;

    const char *className = CPMGameLayoutClassName(cls);
    const char *namesp = CPMGameLayoutClassNamespace(cls);
    const char *assembly = CPMGameLayoutClassAssembly(cls);
    if (!className) return NULL;

    CPMIl2CppPtr image = [self imageForAssembly:assembly];
    CPMIl2CppPtr klass = NULL;
    if (image && _classFromName) {
        klass = _classFromName(image, namesp ?: "", className);
    }
    self.classCache[key] = [NSValue valueWithPointer:klass]; /* cache misses too */
    return klass;
}

- (BOOL)isClassResolvable:(CPMGameClassID)cls {
    return [self classForId:cls] != NULL;
}

- (NSUInteger)effectiveOffsetForField:(CPMGameFieldID)field {
    NSNumber *override = self.offsetOverrides[@(field)];
    if (override) return override.unsignedIntegerValue;
    uint32_t dumped = CPMGameLayoutOffset(CPMGameFieldTable[field].cls, field);
    if (dumped == CPMGameOffsetRuntimeOnly || dumped == CPMGameOffsetNone) return NSNotFound;
    return dumped;
}

- (NSInteger)liveOffsetForField:(CPMGameFieldID)field {
    if (field < 0 || field >= CPMGameFieldCount || !self.isAvailable) return -1;
    CPMIl2CppPtr klass = [self classForId:CPMGameFieldTable[field].cls];
    if (!klass) return -1;
    CPMIl2CppPtr info = _classGetFieldFromName(klass, CPMGameFieldTable[field].fieldName);
    if (!info) return -1;
    return (NSInteger)_fieldGetOffset(info);
}

- (CPMIl2CppPtr)staticFieldValueForField:(CPMGameFieldID)field {
    if (field < 0 || field >= CPMGameFieldCount || !self.isAvailable) return NULL;
    if (!_fieldStaticGetValue) return NULL;
    CPMIl2CppPtr klass = [self classForId:CPMGameFieldTable[field].cls];
    if (!klass) return NULL;
    CPMIl2CppPtr info = _classGetFieldFromName(klass, CPMGameFieldTable[field].fieldName);
    if (!info) return NULL;
    void *value = NULL;
    _fieldStaticGetValue(info, &value);
    return value;
}

- (BOOL)staticBoolValueForField:(CPMGameFieldID)field found:(BOOL *)foundOut {
    if (field < 0 || field >= CPMGameFieldCount || !self.isAvailable) return NO;
    if (!_fieldStaticGetValue) return NO;
    CPMIl2CppPtr klass = [self classForId:CPMGameFieldTable[field].cls];
    if (!klass) return NO;
    CPMIl2CppPtr info = _classGetFieldFromName(klass, CPMGameFieldTable[field].fieldName);
    if (!info) return NO;
    uint8_t raw = 0;
    _fieldStaticGetValue(info, &raw);
    if (foundOut) *foundOut = YES;
    return raw != 0;
}

#pragma mark layout drift check

/// Compares every dump-derived offset with the live runtime value and remembers the
/// live one. Returns the number of differing fields.
- (NSInteger)verifyLayout {
    [self.offsetOverrides removeAllObjects];
    if (!self.isAvailable) return 0;
    NSInteger drift = 0;
    for (CPMGameFieldID i = 0; i < CPMGameFieldCount; i++) {
        const CPMGameFieldRecord *rec = &CPMGameFieldTable[i];
        if (rec->isStatic) continue;              /* statics have no instance offset */
        if (rec->offset == CPMGameOffsetRuntimeOnly) continue;
        CPMIl2CppPtr klass = [self classForId:rec->cls];
        if (!klass) continue;
        CPMIl2CppPtr info = _classGetFieldFromName(klass, rec->fieldName);
        if (!info) continue;                       /* renamed/removed: recorded below */
        NSUInteger live = _fieldGetOffset(info);
        if (live != rec->offset) {
            self.offsetOverrides[@(i)] = @(live);
            drift++;
        }
    }
    return drift;
}

#pragma mark refresh

- (CPMEditorReadout *)refresh {
    CPMEditorReadout *out = [[CPMEditorReadout alloc] init];
    out.bridgeAvailable = self.isAvailable;

    NSInteger drift = [self verifyLayout];
    out.layoutDriftCount = drift;
    out.layoutMatchesDump = (drift == 0);
    out.layoutStale = (drift > 3);

    out.editorFound = [self isClassResolvable:CPMGameClassVinylsEditor] || !self.isAvailable;

    /* VinylDrawer._instance is the only stable handle into the vinyl scene: the
     * drawer is created when an editor context exists and torn down when it closes. */
    CPMIl2CppPtr drawer = [self staticFieldValueForField:CPMGameFieldVinylDrawerInstance];
    out.editorLoaded = (drawer != NULL);

    BOOL foundHasVinyl = NO;
    out.hasVinyl = [self staticBoolValueForField:CPMGameFieldVinylsEditorHasVinyl found:&foundHasVinyl];

    /* VinylsEditor itself is DI-created (VContainer) so there is no static handle
     * for it: read-only mode therefore reports editor state only. Callers that
     * already know the instance pointer (pointer scan, cheat-table, ...) can hand
     * it over with -setKnownEditorInstance: to unlock closed-loop verification. */
    CPMIl2CppPtr editor = self.knownEditorInstance ? (void *)self.knownEditorInstance : NULL;

    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"layout: %@\n", CPMGameLayoutSignature()];
    [detail appendFormat:@"drift: %ld offset(s) corrected from the live binary\n", (long)drift];
    [detail appendFormat:@"vinyl drawer instance: %@\n", drawer ? @"live" : @"none (editor closed)"];
    if (!self.isAvailable) {
        [detail appendFormat:@"%@\n", self.unavailableReason ?: @"il2cpp API unavailable"];
    }

    if (editor) {
        NSUInteger off = NSNotFound;
        int32_t count = -1, maxCount = -1;
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorAllStickers];
        CPMIl2CppPtr list = NULL;
        if (off != NSNotFound && CPMReadPointer(editor, off, (void **)&list) && list) {
            count = (int32_t)[self listCountOf:list];
        }
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorMaxVinylsCount];
        if (off != NSNotFound) CPMReadInt32(editor, off, &maxCount);
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorCurrentVinylsType];
        if (off != NSNotFound) {
            uint8_t t = 0;
            if (CPMReadUInt8(editor, off, &t)) out.vinylsType = t;
        }
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorCurrentOperation];
        if (off != NSNotFound) {
            uint8_t op = 0;
            if (CPMReadUInt8(editor, off, &op)) out.operation = op;
        }
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorIsEditingExisting];
        if (off != NSNotFound) {
            uint8_t b = 0;
            if (CPMReadUInt8(editor, off, &b)) out.isEditingExisting = (b != 0);
        }
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorIsDragging];
        if (off != NSNotFound) {
            uint8_t b = 0;
            if (CPMReadUInt8(editor, off, &b)) out.isDragging = (b != 0);
        }
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorSaved];
        if (off != NSNotFound) {
            uint8_t b = 0;
            if (CPMReadUInt8(editor, off, &b)) out.saved = (b != 0);
        }
        if (count >= 0) out.layerCount = count;
        if (maxCount >= 0) out.maxLayers = maxCount;

        CPMIl2CppPtr sticker = NULL;
        off = [self effectiveOffsetForField:CPMGameFieldVinylsEditorCurrentSticker];
        if (off != NSNotFound && CPMReadPointer(editor, off, (void **)&sticker) && sticker) {
            out.currentSticker = [self readSticker:sticker];
        }
    } else {
        [detail appendString:@"editor instance: not reachable read-only (blind mode)\n"];
    }

    out.summaryString = [NSString stringWithFormat:@"il2cpp %@ · yerleşim %@ · katman %@ / %@ · %@",
                         self.isAvailable ? @"✓" : @"yok (sebep: detayda)",
                         out.layoutMatchesDump ? @"✓" : [NSString stringWithFormat:@"%ldΔ kayma", (long)drift],
                         out.layerCount == NSNotFound ? @"?" : [@(out.layerCount) stringValue],
                         out.maxLayers == NSNotFound ? @"?" : [@(out.maxLayers) stringValue],
                         out.editorLoaded ? @"editör açık"
                                          : @"editör örneği bulunamadı — katman limiti senin ayarın"];
    out.detailString = [detail copy];

    self.lastReadout = out;
    return out;
}

/// List`1._size is only knowable at runtime (generic definition), so the count comes
/// from the live class when available; -1 when it cannot be determined.
- (NSInteger)listCountOf:(CPMIl2CppPtr)list {
    if (!list || !self.isAvailable || !_objectGetClass) return -1;
    CPMIl2CppPtr klass = _objectGetClass(list);
    if (!klass) return -1;
    CPMIl2CppPtr info = _classGetFieldFromName(klass, "_size");
    if (!info) return -1;
    NSUInteger off = _fieldGetOffset(info);
    int32_t size = -1;
    if (!CPMReadInt32(list, off, &size)) return -1;
    return size < 0 ? -1 : size;
}

- (CPMStickerReadout *)readSticker:(CPMIl2CppPtr)sticker {
    CPMStickerReadout *r = [[CPMStickerReadout alloc] init];
    if (!sticker) return r;
    CGFloat v[3] = {0, 0, 0};
    NSUInteger off = [self effectiveOffsetForField:CPMGameFieldStickerItemPosition];
    if (off != NSNotFound && CPMReadVector3(sticker, off, v)) {
        r.position = CGPointMake(v[0], v[1]);
        r.depth = v[2];
    }
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemScale];
    if (off != NSNotFound && CPMReadVector3(sticker, off, v)) {
        r.size = CGSizeMake(v[0], v[1]);
    }
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemYAngle];
    if (off != NSNotFound) {
        CGFloat a = 0;
        if (CPMReadFloat(sticker, off, &a)) r.rotationDegrees = a;
    }
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemColor];
    CGFloat col[4] = {0.5, 0.5, 0.5, 1};
    if (off != NSNotFound && CPMReadColor(sticker, off, col)) {
        r.red = col[0] * 255.0;
        r.green = col[1] * 255.0;
        r.blue = col[2] * 255.0;
        r.alpha = col[3];
    }
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemOrder];
    int32_t i32 = 0;
    if (off != NSNotFound && CPMReadInt32(sticker, off, &i32)) r.order = i32;
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemStckerIndex];
    if (off != NSNotFound && CPMReadInt32(sticker, off, &i32)) r.index = i32;
    off = [self effectiveOffsetForField:CPMGameFieldStickerItemIsText];
    uint8_t b = 0;
    if (off != NSNotFound && CPMReadUInt8(sticker, off, &b)) r.isText = (b != 0);
    if (r.isText) {
        off = [self effectiveOffsetForField:CPMGameFieldStickerItemText];
        if (off != NSNotFound) r.text = CPMReadIl2CppString(sticker, off);
    }
    return r;
}

- (NSString *)diagnosticsReport {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"--- CPM IL2CPP diagnostics ---\n"];
    [s appendFormat:@"version: %@\n", kOLVersion];
    [s appendFormat:@"%@ (runtime-only fields: %ld)\n", CPMGameLayoutSignature(),
            (long)CPMGameLayoutRuntimeOnlyFieldCount()];
    [s appendFormat:@"bridge: %@\n", self.isAvailable ? @"resolved" : (self.unavailableReason ?: @"unavailable")];
    NSInteger resolvable = 0;
    for (CPMGameClassID i = 0; i < CPMGameLayoutClassCount(); i++) {
        if ([self isClassResolvable:i]) resolvable++;
    }
    [s appendFormat:@"classes resolvable: %ld of %ld\n", (long)resolvable, (long)CPMGameLayoutClassCount()];
    [s appendFormat:@"%@\n", self.lastReadout.detailString];
    return [s copy];
}

@end
