#ifndef _CPMSTUB_OBJC_OBJC_H
#define _CPMSTUB_OBJC_OBJC_H
#include <stdbool.h>
#include <sys/cdefs.h>
#include <os/availability.h>

#ifdef __OBJC__
@class NSString;
#else
@class NSString;
#endif

#ifndef OBJC_BOOL_DEFINED
#define OBJC_BOOL_DEFINED 1
#if defined(__cplusplus)
typedef bool BOOL;
#define YES true
#define NO false
#else
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
#endif
#endif

#if !defined(__OBJC_GC__)
#define __strong
#define __weak
#define __autoreleasing
#define __unsafe_unretained
#endif

typedef struct objc_object { Class isa; } *id;
typedef struct objc_selector *SEL;
typedef struct objc_class *Class;
typedef id (*IMP)(id, SEL, ...);
typedef void (*IMP_void)(id, SEL, ...);

#ifndef nil
/* `nil` must convert to any pointer type (NSError **, id, C pointers) exactly like a
 * null pointer constant does in a real build — ((id)0) would break `error:nil`. */
#ifndef nil
#define nil 0
#endif
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

#define OBJC_NEW_CONSTANTS 1

typedef enum {
    OBJC_ASSOCIATION_ASSIGN = 0,
    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1,
    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,
    OBJC_ASSOCIATION_RETAIN = 0x301,
    OBJC_ASSOCIATION_COPY = 0x303
} objc_AssociationPolicy;

typedef struct _NSZone NSZone;

@protocol NSObject
- (BOOL)respondsToSelector:(SEL)aSelector;
- (BOOL)conformsToProtocol:(void *)aProtocol;
- (Class)class;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)isMemberOfClass:(Class)aClass;
- (NSString *)description;
@end
@protocol NSCopying
- (id)copyWithZone:(NSZone *)zone;
@end
@protocol NSMutableCopying
- (id)mutableCopyWithZone:(NSZone *)zone;
@end
@protocol NSCoding
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
@end
#endif
