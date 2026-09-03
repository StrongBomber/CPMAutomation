#ifndef _CPMSTUB_IOKITLIB_H
#define _CPMSTUB_IOKITLIB_H
#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDDevice *IOHIDDeviceRef;
typedef struct __IOHIDService *IOHIDServiceRef;
typedef struct __IOHIDManager *IOHIDManagerRef;
typedef uint32_t IOHIDEventField;
typedef uint32_t IOHIDEventType;
typedef uint32_t IOHIDEventOptions;
typedef void (*IOHIDValueCallback)(void *context, IOHIDDeviceRef device, void *service, IOHIDEventRef event);
CFTypeRef IOHIDDeviceGetProperty(IOHIDDeviceRef device, CFStringRef key);
void IOHIDDeviceSetInputValueMatching(IOHIDDeviceRef device, CFDictionaryRef matching);
void IOHIDDeviceRegisterInputValueCallback(IOHIDDeviceRef device, IOHIDValueCallback callback, void *context);
int IOHIDDeviceOpen(IOHIDDeviceRef device, IOOptionBits options);
IOHIDDeviceRef IOHIDDeviceCreate(CFAllocatorRef allocator, io_service_t service);
void IOHIDDeviceScheduleWithRunLoop(IOHIDDeviceRef device, CFRunLoopRef runLoop, CFStringRef runLoopMode);
#endif
