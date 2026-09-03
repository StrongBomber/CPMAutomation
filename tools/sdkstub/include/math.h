#ifndef _CPMSTUB_MATH_H
#define _CPMSTUB_MATH_H
#include <stdint.h>
#define M_PI 3.14159265358979323846
#define M_PI_2 1.57079632679489661923
#define M_E 2.71828182845904523536
#define M_SQRT2 1.41421356237309504880
#define M_1_PI 0.31830988618379067154
#define M_2_PI 0.63661977236758134308
#define M_LN2 0.69314718055994530942
float sqrtf(float); double sqrt(double);
double pow(double, double); float powf(float, float);
double exp(double); float expf(float);
double log(double); double log2(double); double log10(double); float logf(float);
double sin(double); double cos(double); double tan(double);
float sinf(float); float cosf(float); float tanf(float);
double asin(double); double acos(double); double atan(double);
float asinf(float); float acosf(float); float atanf(float);
double atan2(double, double); float atan2f(float, float);
double fabs(double); float fabsf(float);
double floor(double); double ceil(double); double round(double);
float floorf(float); float ceilf(float); float roundf(float);
double fmod(double, double); float fmodf(float, float);
double hypot(double, double); float hypotf(float, float);
double tanh(double); float tanhf(float);
double cbrt(double); float cbrtf(float);
double lgamma(double); double tgamma(double);
double exp2(double); double log1p(double);
long lround(double); long long llround(double);
float hypotf(float, float) __attribute__((const));
double trunc(double); double nearbyint(double);
int isnan(double); int isinf(double); int isfinite(double);
#ifndef INFINITY
#define INFINITY (__builtin_inf())
#endif
#ifndef NAN
#define NAN (__builtin_nan(""))
#endif
#ifndef CGFLOAT_MAX
#define CGFLOAT_MAX 1.7976931348623157e308
#endif
#ifndef NSEC_PER_SEC
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
#define NSEC_PER_USEC 1000ull
#define USEC_PER_SEC 1000000ull
#endif
#endif
