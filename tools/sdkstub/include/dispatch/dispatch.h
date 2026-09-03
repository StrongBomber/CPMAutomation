/* Minimal dispatch for the offline type-check harness. */
#ifndef _CPMSTUB_DISPATCH_H
#define _CPMSTUB_DISPATCH_H
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <os/availability.h>
#include <CoreFoundation/CoreFoundation.h>

#define DISPATCH_EXTERN extern
#define DISPATCH_EXPORT extern
#define DISPATCH_CLASS_TEMPL
#define NS_FORMAT_FUNCTION(a,b) __attribute__((format(printf,a,b)))
#define __QOS_CLASS_AVAILABLE(...)

typedef void *dispatch_object_t;
typedef struct dispatch_queue_s *dispatch_queue_t;
typedef struct dispatch_queue_attr_s *dispatch_queue_attr_t;
typedef struct dispatch_group_s *dispatch_group_t;
typedef struct dispatch_semaphore_s *dispatch_semaphore_t;
typedef struct dispatch_source_s *dispatch_source_t;
typedef struct dispatch_data_s *dispatch_data_t;
typedef struct dispatch_io_s *dispatch_io_t;
typedef struct dispatch_once_gate_s { long val; } dispatch_once_t;
typedef uint64_t dispatch_time_t;
typedef uint64_t NSEC_PER_SEC_T;
typedef void (*dispatch_function_t)(void *);
typedef void (^dispatch_block_t)(void);

#define DISPATCH_TIME_NOW (0ull)
#define DISPATCH_TIME_FOREVER (~0ull)

#define DISPATCH_QUEUE_SERIAL ((dispatch_queue_attr_t)0)
#define DISPATCH_QUEUE_CONCURRENT ((dispatch_queue_attr_t)1)
typedef long dispatch_qos_class_t;
typedef long qos_class_t;
#define DISPATCH_QUEUE_PRIORITY_HIGH 2
#define DISPATCH_QUEUE_PRIORITY_DEFAULT 0
#define DISPATCH_QUEUE_PRIORITY_LOW 20
#define DISPATCH_QUEUE_PRIORITY_BACKGROUND 1000

#define DISPATCH_DATA_DESTRUCTOR_DEFAULT NULL

dispatch_queue_t dispatch_get_main_queue(void);
dispatch_queue_t dispatch_get_global_queue(long identifier, unsigned long flags);
dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr);
void dispatch_retain(dispatch_object_t object);
void dispatch_release(dispatch_object_t object);
dispatch_time_t dispatch_time(dispatch_time_t base, int64_t delta);
dispatch_time_t dispatch_walltime(const struct timespec *when, int64_t delta);
void dispatch_sync(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_after(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_sync_f(dispatch_queue_t queue, void *ctx, dispatch_function_t work);
void dispatch_async_f(dispatch_queue_t queue, void *ctx, dispatch_function_t work);
void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);
void dispatch_once_f(dispatch_once_t *predicate, void *ctx, dispatch_function_t work);
dispatch_group_t dispatch_group_create(void);
void dispatch_group_enter(dispatch_group_t group);
void dispatch_group_leave(dispatch_group_t group);
int64_t dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout);
void dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
void dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
dispatch_semaphore_t dispatch_semaphore_create(long value);
long dispatch_semaphore_signal(dispatch_semaphore_t dsema);
long dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout);
dispatch_block_t dispatch_block_create(unsigned long flags, dispatch_block_t block);
void dispatch_block_cancel(dispatch_block_t block);
void dispatch_main(void);
void dispatch_suspend(dispatch_object_t object);
void dispatch_resume(dispatch_object_t object);
#define DISPATCH_BLOCK_CANCELABLE (1UL<<1)
#endif

#ifndef QOS_CLASS_UTILITY
enum { QOS_CLASS_USER_INTERACTIVE = 0x21, QOS_CLASS_USER_INITIATED = 0x19,
       QOS_CLASS_DEFAULT = 0x15, QOS_CLASS_UTILITY = 0x11, QOS_CLASS_BACKGROUND = 0x09 };
#endif
