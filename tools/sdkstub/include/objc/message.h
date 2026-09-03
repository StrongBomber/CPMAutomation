#ifndef _CPMSTUB_OBJC_MESSAGE_H
#define _CPMSTUB_OBJC_MESSAGE_H
#ifdef __OBJC__
#import <objc/objc.h>
#endif
#import <objc/runtime.h>
id objc_msgSend(id self, SEL op, ...);
void objc_msgSend_stret(void *lpAddr, id self, SEL op, ...);
double objc_msgSend_fpret(id self, SEL op, ...);
id objc_msgSendSuper(void *structp, SEL op, ...);
IMP object_getMethodImplementation(id obj, SEL sel);
IMP class_getMethodImplementation(Class cls, SEL sel);
typedef id (*CPMSendIMP)(id, SEL, ...);
typedef void (*CPMVoidIMP)(id, SEL, ...);
#endif
