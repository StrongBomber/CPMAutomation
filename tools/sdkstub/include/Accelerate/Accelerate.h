/* Minimal Accelerate for the offline type-check harness. */
#ifndef _CPMSTUB_ACCELERATE_H
#define _CPMSTUB_ACCELERATE_H
#include <stddef.h>
#include <stdint.h>
#include <math.h>
typedef int vDSP_Stride;
typedef unsigned int vDSP_Length;
typedef int vImage_Error;
typedef struct { size_t rowBytes; void *base; void *data_unused; unsigned long height; unsigned long width; } vImage_Buffer;
void vDSP_vclr(float *dest, vDSP_Stride stride, vDSP_Length count);
void vDSP_vadd(const float *A, vDSP_Stride strideA, const float *B, vDSP_Stride strideB, float *D, vDSP_Stride strideD, vDSP_Length count);
void vDSP_vsub(const float *B, vDSP_Stride strideB, const float *A, vDSP_Stride strideA, float *D, vDSP_Stride strideD, vDSP_Length count);
void vDSP_vmul(const float *A, vDSP_Stride strideA, const float *B, vDSP_Stride strideB, float *D, vDSP_Stride strideD, vDSP_Length count);
void vDSP_vsmsa(const float *A, vDSP_Stride strideA, float scale, float offset, float *D, vDSP_Stride strideD, vDSP_Length count);
void vDSP_sve(const float *A, vDSP_Stride stride, float *result, vDSP_Length count);
void vDSP_maxv(const float *A, vDSP_Stride stride, float *result, vDSP_Length count);
void vDSP_minv(const float *A, vDSP_Stride stride, float *result, vDSP_Length count);
void vDSP_svesq(const float *A, vDSP_Stride stride, float *result, vDSP_Length count);
void vDSP_vthr(const float *A, vDSP_Stride strideA, const float *B, vDSP_Stride strideB, float *D, vDSP_Stride strideD, vDSP_Length count);
#endif
