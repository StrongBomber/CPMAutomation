/* Minimal CoreFoundation for the offline type-check harness (see tools/README.md). */
#ifndef _CPMSTUB_CF_H
#define _CPMSTUB_CF_H
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/cdefs.h>
#include <os/availability.h>

#define CF_EXTERN_C_BEGIN
#define CF_EXTERN_C_END
#define CF_EXPORT extern
#define CF_INLINE static inline
#define CF_AVAILABLE(...)
#define CF_CLASS_AVAILABLE(...)
#define CF_ENUM_AVAILABLE(...)
#define NS_ENUM(_type, _name) _type _name; enum
#define NS_OPTIONS(_type, _name) _type _name; enum
#define NS_CLOSED_ENUM(_type, _name) _type _name; enum
#define CF_ENUM(_type, _name) _type _name; enum
#define CF_OPTIONS(_type, _name) _type _name; enum
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define NS_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")

typedef unsigned char UInt8;   typedef signed char SInt8;
typedef unsigned short UInt16; typedef signed short SInt16;
typedef unsigned int UInt32;   typedef signed int SInt32;
typedef unsigned long long UInt64; typedef signed long long SInt64;
typedef unsigned char Boolean;
typedef float Float32; typedef double Float64;
typedef double CFTimeInterval;
typedef double CFAbsoluteTime;
typedef signed long CFIndex;
typedef unsigned long CFOptionFlags;
typedef struct __CFString *CFStringRef;
typedef struct __CFString *CFMutableStringRef;
typedef struct __CFArray *CFArrayRef;
typedef struct __CFArray *CFMutableArrayRef;
typedef struct __CFDictionary *CFDictionaryRef;
typedef struct __CFDictionary *CFMutableDictionaryRef;
typedef struct __CFSet *CFSetRef;
typedef struct __CFSet *CFMutableSetRef;
typedef struct __CFData *CFDataRef;
typedef struct __CFData *CFMutableDataRef;
typedef struct __CFError *CFErrorRef;
typedef struct __CFURL *CFURLRef;
typedef struct __CFRunLoop *CFRunLoopRef;
typedef struct __CFRunLoopSource *CFRunLoopSourceRef;
typedef struct __CFRunLoopObserver *CFRunLoopObserverRef;
typedef struct __CFRunLoopTimer *CFRunLoopTimerRef;
typedef struct __CFMachPort *CFMachPortRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef const void *CFTypeRef;
typedef struct __CFRange { CFIndex location; CFIndex length; } CFRange;
typedef struct { UInt32 hi; UInt32 lo; } AbsoluteTime;

extern CFAllocatorRef kCFAllocatorDefault;
extern CFAllocatorRef kCFAllocatorNull;

CFTypeRef CFRetain(CFTypeRef cf);
void CFRelease(CFTypeRef cf);
CFTypeRef CFAutorelease(CFTypeRef cf);
CFIndex CFGetRetainCount(CFTypeRef cf);
bool CFEqual(CFTypeRef cf1, CFTypeRef cf2);
uintptr_t CFHash(CFTypeRef cf);
CFStringRef CFCopyDescription(CFTypeRef cf);

CFIndex CFStringGetLength(CFStringRef theString);
const char *CFStringGetCStringPtr(CFStringRef theString, UInt32 encoding);
Boolean CFStringGetCString(CFStringRef theString, char *buffer, CFIndex bufferSize, UInt32 encoding);
CFStringRef CFStringCreateWithCString(CFAllocatorRef alloc, const char *cStr, UInt32 encoding);
CFMutableStringRef CFStringCreateMutable(CFAllocatorRef alloc, CFIndex maxLength);
void CFStringAppend(CFMutableStringRef theString, CFStringRef appendix);
#define kCFStringEncodingUTF8 0x08000100u
#define kCFStringEncodingASCII 0x0600
#define kCFNotFound (-1L)

CFArrayRef CFArrayCreate(CFAllocatorRef allocator, const void **values, CFIndex numValues, const void *callBacks);
CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const void *callBacks);
CFIndex CFArrayGetCount(CFArrayRef theArray);
const void *CFArrayGetValueAtIndex(CFArrayRef theArray, CFIndex idx);
void CFArrayAppendValue(CFMutableArrayRef theArray, const void *value);
Boolean CFArrayContainsValue(CFArrayRef theArray, CFRange range, const void *value);

CFDictionaryRef CFDictionaryCreate(CFAllocatorRef allocator, const void **keys, const void **values, CFIndex numValues, const void *keyCallBacks, const void *valueCallBacks);
CFMutableDictionaryRef CFDictionaryCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const void *keyCallBacks, const void *valueCallBacks);
CFIndex CFDictionaryGetCount(CFDictionaryRef theDict);
const void *CFDictionaryGetValue(CFDictionaryRef theDict, const void *key);
void CFDictionarySetValue(CFMutableDictionaryRef theDict, const void *key, const void *value);
void CFDictionaryRemoveValue(CFMutableDictionaryRef theDict, const void *key);

CFMutableSetRef CFSetCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const void *callBacks);
CFIndex CFSetGetCount(CFSetRef theSet);
void CFSetAddValue(CFMutableSetRef theSet, const void *value);

CFDataRef CFDataCreate(CFAllocatorRef allocator, const UInt8 *bytes, CFIndex length);
const UInt8 *CFDataGetBytePtr(CFDataRef theData);
CFIndex CFDataGetLength(CFDataRef theData);

CFTimeInterval CFAbsoluteTimeGetCurrent(void);
CFStringRef CFErrorCopyDescription(CFErrorRef err);
#endif
