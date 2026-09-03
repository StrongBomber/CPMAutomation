#ifndef _CPMSTUB_IOLLEVENT_H
#define _CPMSTUB_IOLLEVENT_H
enum {
  kIOHIDEventTypeNull = 0,
  kIOHIDEventTypeKeyboard = 1,
  kIOHIDEventTypeDigitizer = 11
};
enum {
  kIOHIDDigitizerTransducerTypeHand = 0,
  kIOHIDDigitizerTransducerTypeBody = 1,
  kIOHIDDigitizerTransducerTypeFinger = 2,
  kIOHIDDigitizerTransducerTypePencil = 3
};
enum {
  kIOHIDEventFieldDigitizerIsDisplayIntegrated = 0x000B0000,
  kIOHIDEventFieldDigitizerIndex = 0x000B0000 + 0x100,
  kIOHIDEventFieldDigitizerIdentifier = 0x000B0000 + 0x200,
  kIOHIDEventFieldDigitizerState = 0x000B0000 + 0x300,
  kIOHIDEventFieldDigitizerX = 0x000B0000 + 0x500,
  kIOHIDEventFieldDigitizerY = 0x000B0000 + 0x600,
  kIOHIDEventFieldDigitizerZ = 0x000B0000 + 0x700
};
enum {
  kIOHIDEventFieldKeyboardUsagePage = 0x00010000,
  kIOHIDEventFieldKeyboardUsage = 0x00010100,
  kIOHIDEventFieldKeyboardDown = 0x00010200
};
#define NX_DEVICELCTLKEYMASK 1
#endif
