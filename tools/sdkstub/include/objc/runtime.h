#ifndef _CPMSTUB_OBJC_RUNTIME_H
#define _CPMSTUB_OBJC_RUNTIME_H
#ifdef __OBJC__
#import <objc/objc.h>
#endif
#include <stddef.h>
typedef struct objc_method *Method;
typedef struct objc_ivar *Ivar;
typedef struct objc_property *objc_property_t;

const char *class_getName(Class cls);
Class object_getClass(id obj);
Class object_setClass(id obj, Class cls);
const char *sel_getName(SEL sel);
SEL sel_registerName(const char *str);
SEL sel_getUid(const char *str);
BOOL class_respondsToSelector(Class cls, SEL sel);
BOOL class_addMethod(Class cls, SEL sel, IMP imp, const char *types);
Method class_getInstanceMethod(Class cls, SEL sel);
Method class_getClassMethod(Class cls, SEL sel);
IMP method_getImplementation(Method m);
IMP method_setImplementation(Method m, IMP imp);
void method_exchangeImplementations(Method m1, Method m2);
Ivar class_getInstanceVariable(Class cls, const char *name);
Ivar *class_copyIvarList(Class cls, unsigned int *outCount);
ptrdiff_t ivar_getOffset(Ivar ivar);
const char *ivar_getName(Ivar ivar);
Ivar class_copyIvarList_unused(void);

Class objc_getClass(const char *name);
Class objc_lookUpClass(const char *name);
void *objc_getProtocol(const char *name);
#endif
