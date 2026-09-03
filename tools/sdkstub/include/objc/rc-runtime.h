#ifndef _CPMSTUB_OBJC_RC_H
#define _CPMSTUB_OBJC_RC_H
void *objc_loadWeak(void *location);
void *objc_storeWeak(void *location, void *obj);
void objc_retain(void *obj);
void objc_release(void *obj);
void *objc_retainAutoreleasedReturnValue(void *obj);
void *objc_unsafeClaimAutoreleasedReturnValue(void *obj);
void objc_destroyWeak(void *location);
id objc_autoreleaseReturnValue(id obj);
#endif
