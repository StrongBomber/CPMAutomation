/* Minimal Foundation for the offline type-check harness (tools/README-cpm-check.md).
 * Signatures mirror the real iOS SDK closely enough to catch ARC / selector /
 * nullability mistakes; this is NOT used for shipping builds. */
#ifndef _CPMSTUB_FOUNDATION_H
#define _CPMSTUB_FOUNDATION_H

#ifndef FOUNDATION_EXPORT
#define FOUNDATION_EXPORT extern
#define FOUNDATION_IMPORT extern
#define FOUNDATION_DECLARE_NO_EXPORT
#define FOUNDATION_EXTERN extern
#define OBJC_EXPORT extern
#endif

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <stdarg.h>
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <objc/objc.h>
#include <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <os/availability.h>

#ifdef __OBJC__

#define NS_SWIFT_NAME(...)
#define NS_REQUIRES_SUPER
#define NS_DESIGNATED_INITIALIZER
#define NS_UNAVAILABLE
#define NS_CLASS_AVAILABLE_IOS(...)
#define NS_EXTENSION_UNAVAILABLE(...)
#if defined(__has_attribute) && __has_attribute(format)
#define NS_FORMAT_FUNCTION(f,a) __attribute__((format(__NSString__,f,a)))
#else
#define NS_FORMAT_FUNCTION(f,a)
#endif
#define CF_FORMAT_FUNCTION(f,a) __attribute__((format(printf,f,a)))
#define NS_RETURNS_RETAINED
#define NS_CONSUMED
typedef unsigned short unichar;
typedef struct _NSZone NSZone;
#ifndef NSZoneDefault
#define NSZoneDefault
#endif
typedef unsigned short UTF16Char;
typedef unsigned char UTF8Char;
typedef unsigned int NSStringEncoding;
typedef unsigned int NSDataBase64EncodingOptions;
typedef unsigned int NSDataBase64DecodingOptions;
typedef unsigned int NSJSONWritingOptions;
typedef unsigned int NSJSONReadingOptions;
typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef double NSTimeInterval;
typedef struct _CPMRange { NSUInteger location; NSUInteger length; } NSRange;
typedef enum NSComparisonResult {
    NSOrderedAscending = -1L,
    NSOrderedSame,
    NSOrderedDescending
} NSComparisonResult;

typedef enum NSQualityOfService {
    NSQualityOfServiceUserInteractive = 0x21,
    NSQualityOfServiceUserInitiated = 0x19,
    NSQualityOfServiceUtility = 0x11,
    NSQualityOfServiceBackground = -1,
    NSQualityOfServiceDefault = -1
} NSQualityOfService;

#define NSNotFound ((NSInteger)0x80000000)
#define NSMakeRange(loc, len) ((NSRange){(loc), (len)})
#define NSMaxRange(r) ((r).location + (r).length)

@class NSObject, NSString, NSMutableString, NSNumber, NSValue, NSArray, NSMutableArray,
         NSDictionary, NSMutableDictionary, NSSet, NSMutableSet, NSEnumerator, NSData,
         NSMutableData, NSDate, NSURL, NSError, NSException, NSUUID, NSLocale, NSUserDefaults,
         NSOperation, NSBlockOperation, NSOperationQueue, NSJSONSerialization, NSFileManager,
         NSBundle, NSNotification, NSNotificationCenter, NSCharacterSet, NSDateFormatter,
         NSMapTable, NSPointerArray, NSIndexSet, NSMutableIndexSet, NSTimer, NSThread,
         NSRunLoop, NSProcessInfo, NSDecimalNumber;

typedef struct NSFastEnumerationState {
    unsigned long state;
    id _Nullable *itemsPtr;
    unsigned long *mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id _Nullable * _Nonnull)buffer
                                    count:(NSUInteger)len;
@end

void NSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void NSLogv(NSString *format, va_list args);
NSString *NSLocalizedString(NSString *key, NSString *comment);
id NSAllocateObject(void);
extern NSString *const NSFileReadErrorDomain_unused;
extern NSString *const NSLocalizedDescriptionKey;
extern NSString *const NSLocalizedFailureReasonErrorKey;
extern NSString *const NSLocalizedRecoverySuggestionErrorKey;
extern NSString *const NSFilePathErrorKey;
extern NSString *const NSUnderlyingErrorKey;
#ifndef NSIntegerMax
#define NSIntegerMax    9223372036854775807LL
#define NSIntegerMin    (-9223372036854775807LL - 1)
#define NSUIntegerMax   18446744073709551615UL
#endif
extern const unsigned long long NSEC_PER_SEC;
extern const unsigned long long USEC_PER_SEC;
extern const unsigned long long MSEC_PER_SEC;
extern const unsigned long long NSEC_PER_MSEC;
extern const unsigned long long NSEC_PER_USEC;

@interface NSMethodSignature : NSObject
+ (nullable instancetype)signatureWithObjCTypes:(const char *)objCtypes;
- (NSUInteger)numberOfArguments;
- (const char *)getArgumentTypeAtIndex:(NSUInteger)idx;
- (const char *)methodReturnType;
- (NSUInteger)frameLength;
@end

@interface NSInvocation : NSObject
+ (instancetype)invocationWithMethodSignature:(NSMethodSignature *)sig;
- (NSMethodSignature *)methodSignature;
- (SEL)selector;
- (void)setSelector:(SEL)sel;
- (void)setTarget:(id)target;
- (id)target;
- (void)setArgument:(void *)argument atIndex:(NSUInteger)idx;
- (void)getArgument:(void *)argument atIndex:(NSUInteger)idx;
- (void)setReturnValue:(void *)retLoc;
- (void)getReturnValue:(void *)retLoc;
- (void)invoke;
- (void)invokeWithTarget:(id)target;
@end

@interface NSObject <NSObject>
+ (instancetype)alloc;
+ (instancetype)new;
+ (id)allocWithZone:(void *)zone;
- (instancetype)init;
- (void)dealloc;
- (Class)class;
- (Class)superclass;
- (id)self;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;
- (void)forwardInvocation:(NSInvocation *)anInvocation;
- (id)forwardingTargetForSelector:(SEL)aSelector;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (NSString *)description;
- (NSString *)debugDescription;
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;
- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(id)object;
- (id)performSelector:(SEL)aSelector withObject:(id)o1 withObject:(id)o2;
- (void)willChangeValueForKey:(NSString *)key;
- (void)didChangeValueForKey:(NSString *)key;
- (id)copy;
- (id)mutableCopy;
- (unsigned long)hash;
- (BOOL)isEqual:(id)object;
- (void)observeValueForKeyPath:(NSString *)kp ofObject:(id)object change:(id)change context:(void *)context;
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)kp options:(NSUInteger)opts context:(void *)ctx;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)kp;
@end

@interface NSCoder : NSObject
- (void)encodeInt32:(int32_t)value forKey:(NSString *)key;
- (int32_t)decodeInt32ForKey:(NSString *)key;
@end

@interface NSObject (NSDelayedPerforming)
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(nullable SEL)aSelector object:(nullable id)anArgument;
@end

@interface NSObject (NSCodingShims)
- (instancetype)init NS_REQUIRES_SUPER;
+ (BOOL)supportsSecureCoding;
@end

@interface NSObject (NSKeyValueCodingShims)
- (id)valueForKeyPath:(NSString *)keyPath;
@end

@interface NSString : NSObject <NSCopying, NSMutableCopying>
- (NSUInteger)length;
- (double)doubleValue;
- (float)floatValue;
- (NSInteger)integerValue;
- (BOOL)boolValue;
- (int)intValue;
- (long long)longLongValue;
- (unsigned long long)unsignedLongLongValue;
- (CGRect)CGRectValue;
- (CGPoint)CGPointValue;
- (CGSize)CGSizeValue;
- (CGVector)CGVectorValue;
- (BOOL)isAbsoluteString;
- (unichar)characterAtIndex:(NSUInteger)index;
- (NSString *)substringFromIndex:(NSUInteger)from;
- (NSString *)substringToIndex:(NSUInteger)to;
- (NSString *)substringWithRange:(NSRange)range;
- (BOOL)hasPrefix:(NSString *)str;
- (BOOL)hasSuffix:(NSString *)str;
- (BOOL)containsString:(NSString *)str;
- (BOOL)isEqualToString:(NSString *)aString;
- (NSComparisonResult)compare:(NSString *)aString;
- (NSComparisonResult)caseInsensitiveCompare:(NSString *)aString;
- (NSString *)stringByAppendingString:(NSString *)aString;
- (NSString *)stringByAppendingPathComponent:(NSString *)aComponent;
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target withString:(NSString *)replacement;
- (NSString *)stringByDeletingPathExtension;
- (NSString *)stringByDeletingLastPathComponent;
- (NSString *)pathExtension;
- (NSString *)lastPathComponent;
- (NSString *)lowercaseString;
- (NSString *)uppercaseString;
- (NSString *)stringByTrimmingCharactersInSet:(id)set;
- (NSArray<NSString *> *)componentsSeparatedByString:(NSString *)separator;
- (const char *)UTF8String;
- (BOOL)getCString:(char *)buffer maxLength:(NSUInteger)max;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
+ (instancetype)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString;
+ (instancetype)stringWithCString:(const char *)cstr encoding:(NSStringEncoding)enc;
+ (NSString *)stringWithCharacters:(const unichar *)characters length:(NSUInteger)length;
+ (instancetype)string;
- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange;
- (NSData *)dataUsingEncoding:(NSStringEncoding)encoding;

- (NSRange)rangeOfString:(NSString *)aString;
- (NSRange)rangeOfString:(NSString *)aString options:(NSUInteger)mask;
@end

@interface NSMutableString : NSString
- (void)appendString:(NSString *)aString;
- (void)appendFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
- (void)deleteCharactersInRange:(NSRange)aRange;
- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString;
@end

typedef NSString * NSAttributedStringKey;
OBJC_EXPORT NSAttributedStringKey NSForegroundColorAttributeName;
OBJC_EXPORT NSAttributedStringKey NSFontAttributeName;
OBJC_EXPORT NSAttributedStringKey NSBackgroundColorAttributeName;
OBJC_EXPORT NSAttributedStringKey NSUnderlineStyleAttributeName;

@interface NSAttributedString : NSObject <NSCopying>
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSUInteger length;
- (instancetype)initWithString:(NSString *)str;
- (instancetype)initWithString:(NSString *)str attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(nullable NSRange *)range;
@end

@interface NSMutableAttributedString : NSAttributedString
- (instancetype)initWithString:(NSString *)str;
- (void)appendAttributedString:(NSAttributedString *)attrStr;
- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;
- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;
- (void)removeAttribute:(NSAttributedStringKey)name range:(NSRange)range;
@end

@interface NSNumber : NSObject <NSCopying>
+ (NSNumber *)numberWithChar:(char)value;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithUnsignedInt:(unsigned int)value;
+ (NSNumber *)numberWithLong:(long)value;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber *)numberWithLongLong:(long long)value;
+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value;
+ (NSNumber *)numberWithFloat:(float)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithBool:(BOOL)value;
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
- (char)charValue;
- (unsigned char)unsignedCharValue;
- (short)shortValue;
- (int)intValue;
- (unsigned int)unsignedIntValue;
- (long)longValue;
- (unsigned long)unsignedLongValue;
- (long long)longLongValue;
- (unsigned long long)unsignedLongLongValue;
- (float)floatValue;
- (double)doubleValue;
- (BOOL)boolValue;
- (NSInteger)integerValue;
- (NSUInteger)unsignedIntegerValue;
- (NSString *)stringValue;
@end

@interface NSValue : NSObject <NSCopying>
+ (NSValue *)valueWithBytes:(const void *)value objCType:(const char *)type;
+ (NSValue *)valueWithPointer:(const void *)pointer;
+ (NSValue *)valueWithCGPoint:(CGPoint)point;
+ (NSValue *)valueWithCGSize:(CGSize)size;
+ (NSValue *)valueWithCGRect:(CGRect)rect;
+ (NSValue *)valueWithCGAffineTransform:(CGAffineTransform)t;
+ (NSValue *)valueWithNonretainedObject:(id)anObject;
- (void)getValue:(void *)buffer;
- (void *)pointerValue;
- (id)nonretainedObjectValue;
- (CGPoint)CGPointValue;
- (CGSize)CGSizeValue;
- (CGRect)CGRectValue;
- (CGAffineTransform)CGAffineTransformValue;
- (BOOL)isEqualToValue:(NSValue *)value;
@end

@interface NSEnumerator<ObjectType> : NSObject <NSFastEnumeration>
- (ObjectType)nextObject;
- (NSArray<ObjectType> *)allObjects;
@end

@interface NSArray<ObjectType> : NSObject <NSCopying, NSFastEnumeration>
+ (instancetype)array;
+ (instancetype)arrayWithObject:(ObjectType)anObject;
+ (instancetype)arrayWithObjects:(const ObjectType _Nonnull [])objects count:(NSUInteger)cnt;
+ (instancetype)arrayWithArray:(NSArray<ObjectType> *)array;
- (NSUInteger)count;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;
- (ObjectType)firstObject;
- (ObjectType)lastObject;
- (BOOL)containsObject:(ObjectType)anObject;
- (NSArray<ObjectType> *)arrayByAddingObject:(ObjectType)anObject;
- (NSArray<ObjectType> *)subarrayWithRange:(NSRange)range;
- (NSUInteger)indexOfObject:(ObjectType)anObject;
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSString *)componentsJoinedByString:(NSString *)separator;
- (NSArray *)sortedArrayUsingComparator:(NSComparisonResult (^)(id a, id b))cmptr;
- (NSArray *)sortedArrayUsingSelector:(SEL)comparator;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (instancetype)initWithObjects:(const ObjectType _Nonnull [])objects count:(NSUInteger)cnt;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
@end

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
- (void)removeObjectsInRange:(NSRange)range;
+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)anObject;
- (void)insertObject:(ObjectType)anObject atIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeObject:(ObjectType)anObject;
- (void)removeAllObjects;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)anObject;
- (void)addObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (void)setObject:(ObjectType)anObject atIndexedSubscript:(NSUInteger)idx;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)sortUsingComparator:(NSComparisonResult (^)(ObjectType a, ObjectType b))cmptr;
- (void)sortUsingSelector:(SEL)comparator;
@end

@interface NSDictionary<KeyType, ObjectType> : NSObject <NSCopying, NSFastEnumeration>
+ (instancetype)dictionary;
+ (instancetype)dictionaryWithObject:(ObjectType)object forKey:(KeyType)key;
+ (instancetype)dictionaryWithObjects:(const ObjectType _Nonnull [])objects forKeys:(const KeyType _Nonnull [])keys count:(NSUInteger)cnt;
+ (instancetype)dictionaryWithDictionary:(NSDictionary<KeyType, ObjectType> *)dict;
- (NSUInteger)count;
- (ObjectType)objectForKey:(KeyType)aKey;
- (ObjectType)objectForKeyedSubscript:(KeyType)key;
- (NSArray<KeyType> *)allKeys;
- (NSArray<ObjectType> *)allValues;
- (NSArray *)allKeysForObject:(ObjectType)anObject;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(KeyType key, ObjectType obj, BOOL *stop))block;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (instancetype)initWithObjects:(const ObjectType _Nonnull [])objects forKeys:(const KeyType _Nonnull [])keys count:(NSUInteger)cnt;
@end

@interface NSMutableDictionary<KeyType, ObjectType> : NSDictionary<KeyType, ObjectType>
+ (instancetype)dictionaryWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)setObject:(ObjectType)anObject forKey:(KeyType)aKey;
- (void)setObject:(ObjectType)obj forKeyedSubscript:(KeyType)key;
- (void)removeObjectForKey:(KeyType)aKey;
- (void)removeAllObjects;
- (void)addEntriesFromDictionary:(NSDictionary<KeyType, ObjectType> *)otherDictionary;
@end

@interface NSSet<ObjectType> : NSObject <NSCopying, NSFastEnumeration>
+ (instancetype)set;
+ (instancetype)setWithObject:(ObjectType)anObject;
+ (instancetype)setWithArray:(NSArray<ObjectType> *)array;
+ (instancetype)setWithObjects:(const ObjectType _Nonnull [])objects count:(NSUInteger)cnt;
- (NSUInteger)count;
- (BOOL)containsObject:(ObjectType)anObject;
- (ObjectType)anyObject;
- (ObjectType)member;
- (NSArray<ObjectType> *)allObjects;
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType obj, BOOL *stop))block;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
@end

@interface NSMutableSet<ObjectType> : NSSet<ObjectType>
- (void)addObject:(ObjectType)anObject;
- (void)removeObject:(ObjectType)anObject;
- (void)removeAllObjects;
- (void)unionSet:(NSSet<ObjectType> *)otherSet;
@end

@interface NSData : NSObject <NSCopying>
+ (instancetype)data;
+ (instancetype)dataWithBytes:(const void *)bytes length:(NSUInteger)length;
+ (instancetype)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length;
+ (instancetype)dataWithContentsOfFile:(NSString *)path;
+ (instancetype)dataWithContentsOfURL:(NSURL *)url;
- (NSUInteger)length;
- (const void *)bytes;
- (void)getBytes:(void *)buffer length:(NSUInteger)length;
- (void)getBytes:(void *)buffer;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (NSString *)base64EncodedStringWithOptions:(NSUInteger)options;
- (id)initWithBytes:(const void *)bytes length:(NSUInteger)length;
- (id)initWithContentsOfFile:(NSString *)path;
@end

@interface NSMutableData : NSData
+ (instancetype)dataWithCapacity:(NSUInteger)aNumItems;
+ (instancetype)dataWithLength:(NSUInteger)length;
- (void *)mutableBytes;
- (void)setLength:(NSUInteger)length;
- (void)appendData:(NSData *)otherData;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;
- (void)resetBytesInRange:(NSRange)range;
- (instancetype)initWithLength:(NSUInteger)length;
@end

extern NSString *_Nullable NSStringFromClass(Class _Nullable cls);
extern NSString *NSStringFromCGSize(CGSize size);
extern NSString *NSStringFromCGPoint(CGPoint point);
extern NSString *NSStringFromCGRect(CGRect rect);
extern CGSize CGSizeFromString(NSString *string);
#ifndef NSAssert
#define NSAssert(condition, desc, ...) ((void)0)
#define NSParameterAssert(condition) ((void)0)
#endif
extern Class _Nullable NSClassFromString(NSString *_Nullable name);
extern Protocol *_Nullable NSProtocolFromString(NSString *_Nullable name);
extern SEL _Nullable NSSelectorFromString(NSString *_Nullable name);

typedef NSUInteger NSSearchPathDirectory;
typedef NSUInteger NSSearchPathDomainMask;
enum { NSLibraryDirectory = 15, NSDocumentDirectory = 9, NSCachesDirectory = 13 };
enum { NSUserDomainMask = 1 };
extern NSArray<NSString *> *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory,
                                                                NSSearchPathDomainMask domainMask,
                                                                BOOL expandTilde);


@protocol NSItemProviderReading <NSObject>
+ (nullable id)itemProviderLoadCompletionType:(Class)unreadableType;
@end
@protocol NSItemProviderWriting <NSObject>
@end
@interface NSItemProvider : NSObject
@property (nonatomic, readonly) BOOL hasRegisteredFileTypes;
- (BOOL)canLoadObjectOfClass:(Class)aClass;
- (void)loadObjectOfClass:(Class)classOfType completionHandler:(void (^)(id<NSItemProviderReading> _Nullable object, NSError * _Nullable error))completionHandler;
- (void)loadDataRepresentationForTypeIdentifier:(NSString *)typeIdentifier completionHandler:(void (^)(NSData * _Nullable, NSError * _Nullable))completionHandler;
@end

@interface NSDate : NSObject <NSCopying>
+ (instancetype)date;
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs;
+ (instancetype)dateWithTimeIntervalSince1970:(NSTimeInterval)secs;
+ (instancetype)dateWithTimeInterval:(NSTimeInterval)interval sinceDate:(NSDate *)date;
- (NSTimeInterval)timeIntervalSinceNow;
- (NSTimeInterval)timeIntervalSince1970;
- (NSTimeInterval)timeIntervalSinceReferenceDate;
- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)anotherDate;
- (NSComparisonResult)compare:(NSDate *)anotherDate;
- (BOOL)isEqualToDate:(NSDate *)anotherDate;
- (NSDate *)laterDate:(NSDate *)anotherDate;
@end

@interface NSLocale : NSObject <NSCopying>
+ (instancetype)currentLocale;
@end

@interface NSURL : NSObject <NSCopying>
+ (instancetype)URLWithString:(NSString *)URLString;
+ (instancetype)fileURLWithPath:(NSString *)path;
- (NSString *)path;
- (NSString *)absoluteString;
- (NSString *)lastPathComponent;
- (NSString *)pathExtension;
@end

typedef NSString *NSErrorDomain;

#ifndef NS_ERROR_ENUM
#define NS_ERROR_ENUM(_domain, _name) enum _name : NSInteger _name; enum _name : NSInteger
#endif
#ifndef NS_TYPED_EXTENSIBLE_ENUM
#define NS_TYPED_EXTENSIBLE_ENUM
#define NS_TYPED_ENUM
#endif

@interface NSError : NSObject <NSCopying>
+ (instancetype)errorWithDomain:(NSErrorDomain)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
- (NSInteger)code;
- (NSString *)domain;
- (NSDictionary *)userInfo;
- (NSString *)localizedDescription;
@end

@interface NSException : NSObject
+ (NSException *)exceptionWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userInfo;
- (void)raise;
- (NSString *)name;
- (NSString *)reason;
@end

@interface NSUUID : NSObject <NSCopying>
+ (instancetype)UUID;
- (NSString *)UUIDString;
@end

@interface NSUserDefaults : NSObject
+ (instancetype)standardUserDefaults;
- (id)objectForKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (void)removeObjectForKey:(NSString *)defaultName;
- (NSString *)stringForKey:(NSString *)defaultName;
- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
- (NSData *)dataForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;
- (double)doubleForKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (void)setDouble:(double)value forKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (BOOL)synchronize;
- (void)registerDefaults:(NSDictionary *)registrationDictionary;
- (id)objectForKeyedSubscript:(NSString *)defaultName;
- (void)setObject:(id)value forKeyedSubscript:(NSString *)defaultName;
@end

@interface NSOperation : NSObject
- (void)start;
- (void)cancel;
- (BOOL)isCancelled;
- (BOOL)isFinished;
- (BOOL)isExecuting;
- (BOOL)isAsynchronous;
- (void)setCompletionBlock:(void (^)(void))block;
@end

@interface NSBlockOperation : NSOperation
+ (instancetype)blockOperationWithBlock:(void (^)(void))block;
- (void)addExecutionBlock:(void (^)(void))block;
@end

@interface NSInvocationOperation : NSOperation
- (instancetype)initWithBlock:(void (^)(void))block;
@end

@interface NSOperationQueue : NSObject
+ (instancetype)mainQueue;
- (void)addOperation:(NSOperation *)op;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)cancelAllOperations;
- (void)waitUntilAllOperationsAreFinished;
- (NSUInteger)operationCount;
- (BOOL)isSuspended;
- (void)setSuspended:(BOOL)suspend;
- (NSInteger)maxConcurrentOperationCount;
- (void)setMaxConcurrentOperationCount:(NSInteger)n;
- (NSQualityOfService)qualityOfService;
- (void)setQualityOfService:(NSQualityOfService)qualityOfService;
- (void)setUnderlyingQueue:(dispatch_queue_t)queue;
@end

@interface NSJSONSerialization : NSObject
+ (BOOL)isValidJSONObject:(id)obj;
+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError *_Nullable *_Nullable)error;
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError *_Nullable *_Nullable)error;
+ (id)JSONObjectWithStream:(id)inputStream options:(NSJSONReadingOptions)opt error:(NSError *_Nullable *_Nullable)error;
@end

@interface NSFileManager : NSObject
+ (instancetype)defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError *_Nullable *_Nullable)error;
- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError *_Nullable *_Nullable)error;
- (NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError *_Nullable *_Nullable)error;
- (NSURL *)temporaryDirectory API_AVAILABLE(ios(10.0));
- (NSURL *)URLsForDirectory:(NSUInteger)directory inDomains:(NSUInteger)domainMask;
- (NSArray *)pathsForDirectory:(NSUInteger)directory inDomains:(NSUInteger)domainMask error:(NSError *_Nullable *_Nullable)error;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError *_Nullable *_Nullable)error;
@end

@interface NSBundle : NSObject
+ (instancetype)mainBundle;
+ (instancetype)bundleWithPath:(NSString *)path;
+ (instancetype)bundleForClass:(Class)aClass;
+ (instancetype)bundleWithIdentifier:(NSString *)identifier;
- (NSString *)bundleIdentifier;
- (NSString *)bundlePath;
- (NSString *)resourcePath;
- (NSString *)executablePath;
- (NSString *)objectForInfoDictionaryKey:(NSString *)key;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension inDirectory:(NSString *)subpath;
- (NSURL *)resourceURL;
- (NSDictionary *)infoDictionary;
@end

@interface NSNotification : NSObject <NSCopying>
- (NSString *)name;
- (id)object;
- (NSDictionary *)userInfo;
@end

typedef NSString * NSNotificationName;

@interface NSNotificationCenter : NSObject
+ (instancetype)defaultCenter;
- (void)postNotificationName:(NSString *)aName object:(id)anObject;
- (void)postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
- (void)postNotification:(NSNotification *)notification;
- (id)addObserverForName:(NSNotificationName)name object:(id)obj queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *note))block;
- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(id)anObject;
- (void)removeObserver:(id)observer;
- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(id)anObject;
@end

@interface NSProcessInfo : NSObject
+ (instancetype)processInfo;
- (NSString *)processName;
- (NSArray<NSString *> *)arguments;
- (NSDictionary<NSString *, NSString *> *)environment;
@end

@interface NSCharacterSet : NSObject <NSCopying>
+ (instancetype)whitespaceCharacterSet;
+ (instancetype)newlineCharacterSet;
+ (instancetype)alphanumericCharacterSet;
+ (instancetype)decimalDigitCharacterSet;
+ (instancetype)characterSetWithCharactersInString:(NSString *)aString;
@end

@interface NSDateFormatter : NSObject
- (NSString *)stringFromDate:(NSDate *)date;
- (NSDate *)dateFromString:(NSString *)string;
- (NSString *)dateFormat;
- (void)setDateFormat:(NSString *)format;
@end

@interface NSDecimalNumber : NSNumber
+ (NSDecimalNumber *)decimalNumberWithDouble:(double)value;
@end

@interface NSIndexSet : NSObject <NSCopying>
- (NSUInteger)count;
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)index;
@end

@interface NSMutableIndexSet : NSIndexSet
- (void)addIndex:(NSUInteger)value;
@end

@interface NSTimer : NSObject
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)ui repeats:(BOOL)yesOrNo;
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti block:(void (^)(NSTimer *timer))block repeats:(BOOL)yesOrNo;
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block API_AVAILABLE(ios(10.0));
- (void)invalidate;
- (BOOL)isValid;
- (void)fire;
@end

@interface NSThread : NSObject
+ (NSThread *)currentThread;
+ (NSThread *)mainThread;
+ (BOOL)isMainThread;
+ (void)sleepForTimeInterval:(NSTimeInterval)ti;
+ (void)sleepUntilDate:(NSDate *)date;
@end

@interface NSRunLoop : NSObject
+ (NSRunLoop *)currentRunLoop;
+ (NSRunLoop *)mainRunLoop;
- (void)runUntilDate:(NSDate *)limitDate;
@end

@interface NSMapTable : NSObject
+ (NSMapTable *)strongToWeakObjectsMapTable;
+ (NSMapTable *)weakToWeakObjectsMapTable;
+ (NSMapTable *)strongToStrongObjectsMapTable;
- (id)objectForKey:(id)aKey;
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)removeObjectForKey:(id)aKey;
- (NSEnumerator *)keyEnumerator;
@end

@interface NSPointerArray : NSObject
- (NSUInteger)count;
- (void)addPointer:(void *)pointer;
- (void *)pointerAtIndex:(NSUInteger)index;
- (void)removePointerAtIndex:(NSUInteger)index;
- (void)compact;
@end

@interface NSObject (NSDebugDescriptionAdditions)
@end

#endif /* __OBJC__ */
#endif

/* <sys/param.h> shortcuts that Foundation re-exports. */
#ifndef MAX
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef MIN
#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef ABS
#define ABS(x) (((x) < 0) ? -(x) : (x))
#endif
#ifndef __unused
#define __unused __attribute__((unused))
#endif
