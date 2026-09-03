#ifndef _CPMSTUB_IOHIDLIB_H
#define _CPMSTUB_IOHIDLIB_H
#include <IOKit/IOKitLib.h>
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
enum {
  kIOHIDDeviceTypeUnused = 0
};
#define kIOHIDEventTypeDigitizer 11
#endif
