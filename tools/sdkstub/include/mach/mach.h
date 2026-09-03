#ifndef _CPMSTUB_MACH_H
#define _CPMSTUB_MACH_H
#include <stdint.h>
#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
typedef int kern_return_t;
#define KERN_SUCCESS 0
typedef unsigned int mach_port_t;
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_iterator_t;
typedef uint32_t *io_name_t;
typedef char io_string_t[128];
typedef uint32_t IOItemCount;
typedef uint32_t IOOptionBits;
typedef uint32_t IOOptionBits_unused;
typedef uint64_t IOAsyncReference64;
typedef uintptr_t vm_address_t;
typedef unsigned long vm_size_t;
typedef unsigned long vm_offset_t;
extern mach_port_t mach_task_self_(void);
kern_return_t vm_read_overwrite(mach_port_t target_task, vm_address_t address, vm_size_t size,
                                vm_address_t data, vm_size_t *outsize);
#define mach_task_self() mach_task_self_()
kern_return_t IOObjectRelease(io_object_t object);
kern_return_t IOObjectRetain(io_object_t object);
io_object_t IOIteratorNext(io_iterator_t iterator);
void IOIteratorReset(io_iterator_t iterator);
kern_return_t IORegistryEntryCreateCFProperties(io_object_t entry, void *properties, CFAllocatorRef allocator, IOOptionBits options);
CFTypeRef IORegistryEntryCreateCFProperty(io_object_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
#define kIOMainPortDefault 0
#define kIOMasterPortDefault 0
#endif
