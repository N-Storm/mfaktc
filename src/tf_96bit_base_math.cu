/*
This file is part of mfaktc.
Copyright (C) 2009, 2010, 2011, 2012, 2017, 2018, 2019
                                            Oliver Weihe (o.weihe@t-online.de)
                                            George Woltman (woltman@alum.mit.edu)

mfaktc is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

mfaktc is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
                                
You should have received a copy of the GNU General Public License
along with mfaktc.  If not, see <http://www.gnu.org/licenses/>.
*/

__device__ static int cmp_ge_96(int96 a, int96 b)
/* checks if a is greater or equal than b */
{
    if (a.d2 == b.d2) {
        // clang-format off
        if(a.d1 == b.d1) return(a.d0 >= b.d0);
        else             return(a.d1 >  b.d1);
  }
  else                   return(a.d2 >  b.d2);
    // clang-format on
}

__device__ static void shl_96(int96 *a)
/* shiftleft a one bit */
{
    a->d0 = __add_cc(a->d0, a->d0);
    a->d1 = __addc_cc(a->d1, a->d1);
    a->d2 = __addc(a->d2, a->d2);
}

__device__ static void shl_192(int192 *a)
/* shiftleft a one bit */
{
    a->d0 = __add_cc(a->d0, a->d0);
    a->d1 = __addc_cc(a->d1, a->d1);
    a->d2 = __addc_cc(a->d2, a->d2);
    a->d3 = __addc_cc(a->d3, a->d3);
    a->d4 = __addc_cc(a->d4, a->d4);
#ifndef SHORTCUT_75BIT
    a->d5 = __addc(a->d5, a->d5);
#endif
}

__device__ static void sub_96(int96 *res, int96 a, int96 b)
/* a must be greater or equal b!
res = a - b */
{
    res->d0 = __sub_cc(a.d0, b.d0);
    res->d1 = __subc_cc(a.d1, b.d1);
    res->d2 = __subc(a.d2, b.d2);
}

__device__ static void mul_96(int96 *res, int96 a, int96 b)
/* res = a * b (only lower 96 bits of the result) */
{
//#if (__CUDA_ARCH__ >= MAXWELL)
#if (__CUDA_ARCH__ >= 9999)
    asm volatile("{\n\t"
                 ".reg .u16 a0, a1, a2, a3, a4, a5;\n\t"
                 ".reg .u16 b0, b1, b2, b3, b4, b5;\n\t"
                 ".reg .u32 t0, t1, t2;\n\t"

                 "mov.b32          {a0,a1}, %3;\n\t"
                 "mov.b32          {a2,a3}, %4;\n\t"
                 "mov.b32          {a4,a5}, %5;\n\t"

                 "mov.b32          {b0,b1}, %6;\n\t"
                 "mov.b32          {b2,b3}, %7;\n\t"
                 "mov.b32          {b4,b5}, %8;\n\t"

                 "mul.wide.u16     %0, a0, b1;\n\t"
                 "mul.wide.u16     %1, a0, b3;\n\t"
                 "mul.wide.u16     %2, a0, b5;\n\t"

                 "mul.wide.u16     t0, a1, b0;\n\t"
                 "mul.wide.u16     t1, a1, b2;\n\t"
                 "mul.wide.u16     t2, a1, b4;\n\t"
                 "add.cc.u32       %0, %0, t0;\n\t"
                 "addc.cc.u32      %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mul.wide.u16     t1, a2, b1;\n\t"
                 "mul.wide.u16     t2, a2, b3;\n\t"
                 "add.cc.u32       %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mul.wide.u16     t1, a3, b0;\n\t"
                 "mul.wide.u16     t2, a3, b2;\n\t"
                 "add.cc.u32       %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mad.wide.u16     %2, a4, b1, %2;\n\t"

                 "mad.wide.u16     %2, a5, b0, %2;\n\t"

                 "shf.l.clamp.b32  %2, %1, %2, 16;\n\t"
                 "shf.l.clamp.b32  %1, %0, %1, 16;\n\t"
                 "shf.l.clamp.b32  %0,  0, %0, 16;\n\t"

                 "mul.wide.u16     t0, a0, b0;\n\t"
                 "mul.wide.u16     t1, a0, b2;\n\t"
                 "mul.wide.u16     t2, a0, b4;\n\t"
                 "add.cc.u32       %0, %0, t0;\n\t"
                 "addc.cc.u32      %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mul.wide.u16     t1, a1, b1;\n\t"
                 "mul.wide.u16     t2, a1, b3;\n\t"
                 "add.cc.u32       %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mul.wide.u16     t1, a2, b0;\n\t"
                 "mul.wide.u16     t2, a2, b2;\n\t"
                 "add.cc.u32       %1, %1, t1;\n\t"
                 "addc.u32         %2, %2, t2;\n\t"

                 "mad.wide.u16     %2, a3, b1, %2;\n\t"

                 "mad.wide.u16     %2, a4, b0, %2;\n\t"
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2), "r"(b.d0), "r"(b.d1), "r"(b.d2));
#elif (__CUDA_ARCH__ >= FERMI) &&                                                                                 \
    (CUDART_VERSION >= 4010) /* multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1 */
    asm volatile("{\n\t"
                 "mul.lo.u32    %0, %3, %6;\n\t" /* (a.d0 * b.d0).lo */

                 "mul.hi.u32    %1, %3, %6;\n\t" /* (a.d0 * b.d0).hi */
                 "mad.lo.cc.u32 %1, %4, %6, %1;\n\t" /* (a.d1 * b.d0).lo */

                 "mul.lo.u32    %2, %5, %6;\n\t" /* (a.d2 * b.d0).lo */
                 "madc.hi.u32   %2, %4, %6, %2;\n\t" /* (a.d1 * b.d0).hi */

                 "mad.lo.cc.u32 %1, %3, %7, %1;\n\t" /* (a.d0 * b.d1).lo */
                 "madc.hi.u32   %2, %3, %7, %2;\n\t" /* (a.d0 * b.d1).hi */

                 "mad.lo.u32    %2, %3, %8, %2;\n\t" /* (a.d0 * b.d2).lo */

                 "mad.lo.u32    %2, %4, %7, %2;\n\t" /* (a.d1 * b.d1).lo */
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2), "r"(b.d0), "r"(b.d1), "r"(b.d2));
#else
    // clang-format off
    res->d0 = __umul32  (a.d0, b.d0);

    res->d1 = __add_cc(__umul32hi(a.d0, b.d0), __umul32  (a.d1, b.d0));
    res->d2 = __addc  (__umul32  (a.d2, b.d0), __umul32hi(a.d1, b.d0));
  
    res->d1 = __add_cc(res->d1,                __umul32  (a.d0, b.d1));
    res->d2 = __addc  (res->d2,                __umul32hi(a.d0, b.d1));
    // clang-format on

    res->d2 += __umul32(a.d0, b.d2);

    res->d2 += __umul32(a.d1, b.d1);
#endif
}

// __device__ static void mul_96_192(int192 *res, int96 a, int96 b)
/* res = a * b */
/*
{
    res->d0 = __umul32(a.d0, b.d0);
    res->d1 = __umul32hi(a.d0, b.d0);
    res->d2 = __umul32(a.d2, b.d0);
    res->d3 = __umul32hi(a.d2, b.d0);

    res->d1 = __add_cc(res->d1, __umul32(a.d1, b.d0));
    res->d2 = __addc_cc(res->d2, __umul32hi(a.d1, b.d0));
    res->d3 = __addc_cc(res->d3, __umul32(a.d2, b.d1));
    res->d4 = __addc(0, 0);

    res->d1 = __add_cc(res->d1, __umul32(a.d0, b.d1));
    res->d2 = __addc_cc(res->d2, __umul32hi(a.d0, b.d1));
    res->d3 = __addc_cc(res->d3, __umul32(a.d1, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d1, b.d2));
    res->d5 = __addc(0, 0);

    res->d2 = __add_cc(res->d2, __umul32(a.d0, b.d2));
    res->d3 = __addc_cc(res->d3, __umul32hi(a.d0, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32(a.d2, b.d2));
    res->d5 = __addc(res->d5, __umul32hi(a.d2, b.d2));

    res->d2 = __add_cc(res->d2, __umul32(a.d1, b.d1));
    res->d3 = __addc_cc(res->d3, __umul32hi(a.d1, b.d1));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d2, b.d1));
    res->d5 = __addc(res->d5, 0);
}
*/

__device__ static void mul_96_192_no_low2(int192 *res, int96 a, int96 b)
/*
res ~= a * b
res.d0 and res.d1 are NOT computed. Carry from res.d1 to res.d2 is ignored,
too. So the digits res.d{2-5} might differ from mul_96_192(). In
mul_96_192() are two carries from res.d1 to res.d2. So ignoring the digits
res.d0 and res.d1 the result of mul_96_192_no_low() is 0 to 2 lower than
of mul_96_192().
 */
{
#if (__CUDA_ARCH__ >= FERMI) &&                                                                                   \
    (CUDART_VERSION >= 4010) /* multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1 */
    asm volatile("{\n\t"
                 "mul.lo.u32      %0, %6, %7;\n\t" /* (a.d2 * b.d0).lo */
                 "mul.hi.u32      %1, %6, %7;\n\t" /* (a.d2 * b.d0).hi */

                 "mad.hi.cc.u32   %0, %5, %7, %0;\n\t" /* (a.d1 * b.d0).hi */
                 "madc.lo.cc.u32  %1, %6, %8, %1;\n\t" /* (a.d2 * b.d1).lo */
                 "addc.u32        %2,  0,  0;\n\t"

                 "mad.hi.cc.u32   %0, %4, %8, %0;\n\t" /* (a.d0 * b.d1).hi */
                 "madc.lo.cc.u32  %1, %5, %9, %1;\n\t" /* (a.d1 * b.d2).lo */
                 "madc.hi.cc.u32  %2, %5, %9, %2;\n\t" /* (a.d1 * b.d2).hi */
                 "addc.u32        %3,  0,  0;\n\t"

                 "mad.lo.cc.u32   %0, %4, %9, %0;\n\t" /* (a.d0 * b.d2).lo */
                 "madc.hi.cc.u32  %1, %4, %9, %1;\n\t" /* (a.d0 * b.d2).hi */
                 "madc.lo.cc.u32  %2, %6, %9, %2;\n\t" /* (a.d2 * b.d2).lo */
                 "madc.hi.u32     %3, %6, %9, %3;\n\t" /* (a.d2 * b.d2).hi */

                 "mad.lo.cc.u32   %0, %5, %8, %0;\n\t" /* (a.d1 * b.d1).lo */
                 "madc.hi.cc.u32  %1, %5, %8, %1;\n\t" /* (a.d1 * b.d1).hi */
                 "madc.hi.cc.u32  %2, %6, %8, %2;\n\t" /* (a.d2 * b.d1).lo */
                 "addc.u32        %3, %3,  0;\n\t"
                 "}"
                 : "=r"(res->d2), "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2), "r"(b.d0), "r"(b.d1), "r"(b.d2));
#else
    res->d2 = __umul32(a.d2, b.d0);
    res->d3 = __umul32hi(a.d2, b.d0);

    // clang-format off
    res->d2 = __add_cc(res->d2, __umul32hi(a.d1, b.d0));
    res->d3 = __addc_cc(res->d3, __umul32(a.d2, b.d1));
    res->d4 = __addc(0, 0);

    res->d2 = __add_cc(res->d2, __umul32hi(a.d0, b.d1));
    res->d3 = __addc_cc(res->d3, __umul32(a.d1, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d1, b.d2));
    res->d5 = __addc(0, 0);

    res->d2 = __add_cc(res->d2, __umul32(a.d0, b.d2));
    res->d3 = __addc_cc(res->d3, __umul32hi(a.d0, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32(a.d2, b.d2));
    res->d5 = __addc(res->d5, __umul32hi(a.d2, b.d2));

    res->d2 = __add_cc(res->d2, __umul32(a.d1, b.d1));
    res->d3 = __addc_cc(res->d3, __umul32hi(a.d1, b.d1));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d2, b.d1));
    res->d5 = __addc(res->d5, 0);
    // clang-format on
#endif
}

__device__ static void mul_96_192_no_low3(int192 *res, int96 a, int96 b)
/*
res ~= a * b
res.d0, res.d1 and res.d2 are NOT computed. Carry to res.d3 is ignored,
too. So the digits res.d{3-5} might differ from mul_96_192(). In
mul_96_192() are four carries from res.d2 to res.d3. So ignoring the digits
res.d0, res.d1 and res.d2 the result of mul_96_192_no_low() is 0 to 4 lower
than of mul_96_192().
 */
{
#if (__CUDA_ARCH__ >= FERMI) &&                                                                                   \
    (CUDART_VERSION >= 4010) /* multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1 */
    asm volatile("{\n\t"
                 "mul.hi.u32      %0, %5, %6;\n\t" /* (a.d2 * b.d0).hi */
                 "mad.lo.cc.u32   %0, %5, %7, %0;\n\t" /* (a.d2 * b.d1).lo */
                 "addc.u32        %1,  0,  0;\n\t"

                 "mad.lo.cc.u32   %0, %4, %8, %0;\n\t" /* (a.d1 * b.d2).lo */
                 "madc.hi.u32     %1, %5, %7, %1;\n\t" /* (a.d2 * b.d1).hi */

                 "mad.hi.cc.u32   %0, %3, %8, %0;\n\t" /* (a.d0 * b.d2).hi */
                 "madc.lo.cc.u32  %1, %5, %8, %1;\n\t" /* (a.d2 * b.d2).lo */
                 "madc.hi.u32     %2, %5, %8,  0;\n\t" /* (a.d2 * b.d2).hi */

                 "mad.hi.cc.u32   %0, %4, %7, %0;\n\t" /* (a.d1 * b.d1).hi */
                 "madc.hi.cc.u32  %1, %4, %8, %1;\n\t" /* (a.d1 * b.d2).hi */
                 "addc.u32        %2, %2,  0;\n\t"
                 "}"
                 : "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2), "r"(b.d0), "r"(b.d1), "r"(b.d2));
#else
    res->d3 = __umul32hi(a.d2, b.d0);

    // clang-format off
    res->d3 = __add_cc (res->d3, __umul32  (a.d2, b.d1));
    res->d4 = __addc   (      0,                      0);
  
    res->d3 = __add_cc (res->d3, __umul32  (a.d1, b.d2));
    res->d4 = __addc   (res->d4, __umul32hi(a.d1, b.d2)); // no carry propagation to d5 needed: 0xFFFF.FFFF * 0xFFFF.FFFF + 0xFFFF.FFFF      + 0xFFFF.FFFE      = 0xFFFF.FFFF.FFFF.FFFE
                                                          //                       res->d4|d3 = (a.d1 * b.d2).hi|lo       + (a.d2 * b.d1).lo + (a.d2 * b.d0).hi

    res->d3 = __add_cc (res->d3, __umul32hi(a.d0, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32  (a.d2, b.d2));
    res->d5 = __addc   (      0, __umul32hi(a.d2, b.d2));

    res->d3 = __add_cc (res->d3, __umul32hi(a.d1, b.d1));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d2, b.d1));
    res->d5 = __addc   (res->d5,                      0);
    // clang-format on
#endif
}

__device__ static void mul_96_192_no_low3_special(int192 *res, int96 a, int96 b)
/*
res ~= a * b
res.d0, res.d1 and res.d2 are NOT computed. Carry to res.d3 is partially ignored,
mul_96_192_no_low3_special differs from mul_96_192_no_low3 in that two partial
results from res.d2 are added together to generate up to one carry into res.d3.
So the digits res.d{3-5} might differ from mul_96_192(). In mul_96_192() are
three more possible carries from res.d2 to res.d3. So ignoring the digits
res.d0, res.d1 and res.d2 the result of mul_96_192_no_low() is 0 to 3 lower
than of mul_96_192().
*/
{
#if (__CUDA_ARCH__ >= FERMI) &&                                                                                   \
    (CUDART_VERSION >= 4010) /* multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1 */
    asm volatile("{\n\t"
                 ".reg .u32 d2;\n\t"

                 "mul.lo.u32      d2, %5, %6;\n\t" /* (a.d2 * b.d0).lo */
                 "mul.hi.u32      %0, %5, %6;\n\t" /* (a.d2 * b.d0).hi */
                 "mad.lo.cc.u32   %0, %5, %7, %0;\n\t" /* (a.d2 * b.d1).lo */
                 "addc.u32        %1,  0,  0;\n\t"

                 "mad.lo.cc.u32   d2, %4, %7, d2;\n\t" /* (a.d1 * b.d1).lo */
                 "madc.lo.cc.u32  %0, %4, %8, %0;\n\t" /* (a.d1 * b.d2).lo */
                 "madc.hi.u32     %1, %5, %7, %1;\n\t" /* (a.d2 * b.d1).hi */

                 "mad.hi.cc.u32   %0, %3, %8, %0;\n\t" /* (a.d0 * b.d2).hi */
                 "madc.lo.cc.u32  %1, %5, %8, %1;\n\t" /* (a.d2 * b.d2).lo */
                 "madc.hi.u32     %2, %5, %8,  0;\n\t" /* (a.d2 * b.d2).hi */

                 "mad.hi.cc.u32   %0, %4, %7, %0;\n\t" /* (a.d1 * b.d1).hi */
                 "madc.hi.cc.u32  %1, %4, %8, %1;\n\t" /* (a.d1 * b.d2).hi */
                 "addc.u32        %2, %2,  0;\n\t"
                 "}"
                 : "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2), "r"(b.d0), "r"(b.d1), "r"(b.d2));
#else
    unsigned int t1;

    t1      = __umul32(a.d2, b.d0);
    res->d3 = __umul32hi(a.d2, b.d0);

    // clang-format off
    res->d3 = __add_cc (res->d3, __umul32  (a.d2, b.d1));
    res->d4 = __addc   (      0,                      0);
  
    t1      = __add_cc (     t1, __umul32  (a.d1, b.d1));
    res->d3 = __addc_cc(res->d3, __umul32  (a.d1, b.d2));
    res->d4 = __addc   (res->d4, __umul32hi(a.d1, b.d2)); // no carry propagation to d5 needed: 0xFFFF.FFFF * 0xFFFF.FFFF + 0xFFFF.FFFF      + 0xFFFF.FFFE      + 1             = 0xFFFF.FFFF.FFFF.FFFF
                                                          //                       res->d4|d3 = (a.d1 * b.d2).hi|lo       + (a.d2 * b.d1).lo + (a.d2 * b.d0).hi + carry from t1

    res->d3 = __add_cc (res->d3, __umul32hi(a.d0, b.d2));
    res->d4 = __addc_cc(res->d4, __umul32  (a.d2, b.d2));
    res->d5 = __addc   (      0, __umul32hi(a.d2, b.d2));

    res->d3 = __add_cc (res->d3, __umul32hi(a.d1, b.d1));
    res->d4 = __addc_cc(res->d4, __umul32hi(a.d2, b.d1));
    res->d5 = __addc   (res->d5,                      0);
    // clang-format on
#endif
}

__device__ static void square_96_192(int192 *res, int96 a)
/* res = a^2
assuming that a is < 2^95 (a.d2 < 2^31)! */
{
#if (__CUDA_ARCH__ >= COMPUTE_CAPABILITY_PASCAL) && (__CUDA_ARCH__ < VOLTA)
    asm volatile("{\n\t"
                 ".reg .u16 a0, a1, a2, a3, a4, a5;\n\t" /* 16 bits of input each, FIXME: a5 not needed */
                 ".reg .u32 s0, s1, s2, s3, s4, s5;\n\t"
                 ".reg .u32 t0, t1, t2, t3, t4, t5;\n\t"
                 ".reg .u32 t;\n\t"

                 "mov.b32         {a0,a1}, %6;\n\t"
                 "mov.b32         {a2,a3}, %7;\n\t"
                 "mov.b32         {a4,a5}, %8;\n\t"

                 "mul.wide.u16    %0, a0, a1;\n\t"
                 "mul.wide.u16    %1, a0, a3;\n\t"
                 "mul.wide.u16    %2, a0, a5;\n\t"
                 "mul.wide.u16    %3, a2, a5;\n\t"
                 "mul.wide.u16    %4, a4, a5;\n\t"

                 "mul.wide.u16    t1, a1, a2;\n\t"
                 "mul.wide.u16    t2, a1, a4;\n\t"
                 "add.cc.u32      %1, %1, t1;\n\t"
                 "addc.cc.u32     %2, %2, t2;\n\t"
                 "addc.u32        %3, %3,  0;\n\t" // no futher carry needed: (2^16-1)^2, can take 2^17 carries!

                 "mul.wide.u16    t2, a2, a3;\n\t"
                 "mul.wide.u16    t3, a3, a4;\n\t"
                 "add.cc.u32      %2, %2, t2;\n\t"
                 "addc.cc.u32     %3, %3, t3;\n\t"
                 "addc.u32        %4, %4,  0;\n\t" // no futher carry needed: (2^16-1)^2, can take 2^17 carries!

                 "shf.l.clamp.b32 %5, %4,  0, 17;\n\t" // shiftleft partial sum by 16 bits *AND* multiply by two
                 "shf.l.clamp.b32 %4, %3, %4, 17;\n\t"
                 "shf.l.clamp.b32 %3, %2, %3, 17;\n\t"
                 "shf.l.clamp.b32 %2, %1, %2, 17;\n\t"
                 "shf.l.clamp.b32 %1, %0, %1, 17;\n\t"
                 "shf.l.clamp.b32 %0,  0, %0, 17;\n\t"
                 /*      
                 "mul.wide.u16   s2, a0, a4;\n\t"
                 "mul.wide.u16   s3, a1, a5;\n\t"
                 "mul.wide.u16   s4, a3, a5;\n\t"

                 "mul.wide.u16   t1, a0, a2;\n\t"
                 "mul.wide.u16   t2, a1, a3;\n\t"
                 "mul.wide.u16   t3, a2, a4;\n\t"

                 "add.cc.u32     t2, t2, s2;\n\t"
                 "addc.cc.u32    t3, t3, s3;\n\t"
                 "addc.u32       t4,  0, s4;\n\t"
      
                 "add.cc.u32     %1, %1, t1;\n\t"
                 "addc.cc.u32    %2, %2, t2;\n\t"
                 "addc.cc.u32    %3, %3, t3;\n\t"
                 "addc.cc.u32    %4, %4, t4;\n\t"
                 "addc.u32       %5, %5,  0;\n\t"

                 "add.cc.u32     %1, %1, t1;\n\t"
                 "addc.cc.u32    %2, %2, t2;\n\t"
                 "addc.cc.u32    %3, %3, t3;\n\t"
                 "addc.cc.u32    %4, %4, t4;\n\t"
                 "addc.u32       %5, %5,  0;\n\t"
                 */

                 "mul.wide.u16   s2, a0, a4;\n\t"
                 "mul.wide.u16   s3, a1, a5;\n\t"
                 "mul.wide.u16   s4, a3, a5;\n\t" // on input a5 is limited to (2^15)-1 thus s4 <= ((2^16)-1) * ((2^15)-1 ) = 2147385345

                 "mul.wide.u16   t1, a0, a2;\n\t"
                 "mul.wide.u16   t2, a1, a3;\n\t"
                 "mul.wide.u16   t3, a2, a4;\n\t"

                 "add.cc.u32     t2, t2, s2;\n\t"
                 "addc.cc.u32    t3, t3, s3;\n\t"
                 "addc.u32       t4,  0, s4;\n\t" // t4 <= 2147385345 + 1 = 2147385346 < (2^31) -1

                 "add.cc.u32     t1, t1, t1;\n\t"
                 "addc.cc.u32    t2, t2, t2;\n\t"
                 "addc.cc.u32    t3, t3, t3;\n\t"
                 "addc.u32       t4, t4, t4;\n\t" // no carry to t5 because t4 of above

                 "add.cc.u32     %1, %1, t1;\n\t"
                 "addc.cc.u32    %2, %2, t2;\n\t"
                 "addc.cc.u32    %3, %3, t3;\n\t"
                 "addc.cc.u32    %4, %4, t4;\n\t"
                 "addc.u32       %5, %5,  0;\n\t"

                 "mul.wide.u16   t0, a0, a0;\n\t"
                 "mul.wide.u16   t1, a1, a1;\n\t"
                 "mul.wide.u16   t2, a2, a2;\n\t"
                 "mul.wide.u16   t3, a3, a3;\n\t"
                 "mul.wide.u16   t4, a4, a4;\n\t"
                 "mul.wide.u16   t5, a5, a5;\n\t"
                 "add.cc.u32     %0, %0, t0;\n\t"
                 "addc.cc.u32    %1, %1, t1;\n\t"
                 "addc.cc.u32    %2, %2, t2;\n\t"
                 "addc.cc.u32    %3, %3, t3;\n\t"
                 "addc.cc.u32    %4, %4, t4;\n\t"
                 "addc.u32       %5, %5, t5;\n\t"
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
                 // multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1
#elif (__CUDA_ARCH__ >= FERMI) && (CUDART_VERSION >= 4010)
             asm("{\n\t"
                 ".reg .u32 a2;\n\t"

                 "mul.lo.u32      %0, %6, %6;\n\t" /* (a.d0 * a.d0).lo */
                 "mul.lo.u32      %1, %6, %7;\n\t" /* (a.d0 * a.d1).lo */
                 "mul.hi.u32      %2, %6, %7;\n\t" /* (a.d0 * a.d1).hi */

                 "add.cc.u32      %1, %1, %1;\n\t" /* 2 * (a.d0 * a.d1).lo */
                 "addc.cc.u32     %2, %2, %2;\n\t" /* 2 * (a.d0 * a.d1).hi */
                 "madc.hi.cc.u32  %3, %7, %7, 0;\n\t" /* (a.d1 * a.d1).hi */
                 /* highest possible value for next instruction: mul.lo.u32 (N, N) is 0xFFFFFFF9
                    this occurs for N = {479772853, 1667710795, 2627256501, 3815194443}
                    We'll use this knowledge later to avoid some two carry steps to %5 */
                 "madc.lo.u32     %4, %8, %8, 0;\n\t" /* (a.d2 * a.d2).lo */
                 /* %4 <= 0xFFFFFFFA => no carry to %5 needed! */

                 "add.u32         a2, %8, %8;\n\t" /* a2 = 2 * a.d2
                                                      a is < 2^95 so a.d2 is < 2^31 */

                 "mad.hi.cc.u32   %1, %6, %6, %1;\n\t" /* (a.d0 * a.d0).hi */
                 "madc.lo.cc.u32  %2, %7, %7, %2;\n\t" /* (a.d1 * a.d1).lo */
                 "madc.lo.cc.u32  %3, %7, a2, %3;\n\t" /* 2 * (a.d1 * a.d2).lo */
                 "addc.u32        %4, %4,  0;\n\t" /* %4 <= 0xFFFFFFFB => not carry to %5 needed, see above! */

                 "mad.lo.cc.u32   %2, %6, a2, %2;\n\t" /* 2 * (a.d0 * a.d2).lo */
                 "madc.hi.cc.u32  %3, %6, a2, %3;\n\t" /* 2 * (a.d0 * a.d2).hi */
                 "madc.hi.cc.u32  %4, %7, a2, %4;\n\t" /* 2 * (a.d1 * a.d2).hi */
                 "madc.hi.u32     %5, %8, %8, 0;\n\t" /* (a.d2 * a.d2).hi */
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
#else
    asm volatile("{\n\t"
                 ".reg .u32 a2, t1;\n\t"

                 "mul.lo.u32      %0, %6, %6;\n\t" /* (a.d0 * a.d0).lo */
                 "mul.lo.u32      %1, %6, %7;\n\t" /* (a.d0 * a.d1).lo */
                 "mul.hi.u32      %2, %6, %7;\n\t" /* (a.d0 * a.d1).hi */

                 "add.cc.u32      %1, %1, %1;\n\t" /* 2 * (a.d0 * a.d1).lo */
                 "addc.cc.u32     %2, %2, %2;\n\t" /* 2 * (a.d0 * a.d1).hi */
                 "mul.hi.u32      t1, %7, %7;\n\t" /* (a.d1 * a.d1).hi */
                 "addc.cc.u32     %3, t1,  0;\n\t"
                 /* highest possible value for next instruction: mul.lo.u32 (N, N) is 0xFFFFFFF9
                    this occurs for N = {479772853, 1667710795, 2627256501, 3815194443}
                    We'll use this knowledge later to avoid some two carry steps to %5 */
                 "mul.lo.u32      t1, %8, %8;\n\t" /* (a.d2 * a.d2).lo */
                 "addc.u32        %4, t1,  0;\n\t" /* %4 <= 0xFFFFFFFA => no carry to %5 needed! */

                 "add.u32         a2, %8, %8;\n\t" /* a2 = 2 * a.d2
                                                      a is < 2^95 so a.d2 is < 2^31 */

                 "mul.hi.u32      t1, %6, %6;\n\t" /* (a.d0 * a.d0).hi */
                 "add.cc.u32      %1, %1, t1;\n\t"
                 "mul.lo.u32      t1, %7, %7;\n\t" /* (a.d1 * a.d1).lo */
                 "addc.cc.u32     %2, %2, t1;\n\t"
                 "mul.lo.u32      t1, %7, a2;\n\t" /* 2 * (a.d1 * a.d2).lo */
                 "addc.cc.u32     %3, %3, t1;\n\t"
                 "addc.u32        %4, %4,  0;\n\t" /* %4 <= 0xFFFFFFFB => not carry to %5 needed, see above! */

                 "mul.lo.u32      t1, %6, a2;\n\t" /* 2 * (a.d0 * a.d2).lo */
                 "add.cc.u32      %2, %2, t1;\n\t"
                 "mul.hi.u32      t1, %6, a2;\n\t" /* 2 * (a.d0 * a.d2).hi */
                 "addc.cc.u32     %3, %3, t1;\n\t"
                 "mul.hi.u32      t1, %7, a2;\n\t" /* 2 * (a.d1 * a.d2).hi */
                 "addc.cc.u32     %4, %4, t1;\n\t"
                 "mul.hi.u32      t1, %8, %8;\n\t" /* (a.d2 * a.d2).hi */
                 "addc.u32        %5, t1,  0;\n\t"
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4), "=r"(res->d5)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
#endif
}

__device__ static void square_96_160(int192 *res, int96 a)
/* res = a^2
this is a stripped down version of square_96_192, it doesn't compute res.d5
and is a little bit faster.
For correct results a must be less than 2^80 (a.d2 less than 2^16) */
{
#if (__CUDA_ARCH__ >= COMPUTE_CAPABILITY_PASCAL) && (__CUDA_ARCH__ < VOLTA)
    asm volatile("{\n\t"
                 ".reg .u16 a0, a1, a2, a3, a4, a5;\n\t" /* 16 bits of input each, FIXME: a5 not needed */
                 ".reg .u32 s0, s1, s2, s3, s4;\n\t"
                 ".reg .u32 t0, t1, t2, t3, t4;\n\t"
                 ".reg .u32 t;\n\t"

                 "mov.b32         {a0,a1}, %5;\n\t"
                 "mov.b32         {a2,a3}, %6;\n\t"
                 "mov.b32         {a4,a5}, %7;\n\t"

                 /*
                 "mul.wide.u16    %0, a0, a0;\n\t"    // max value: (2^16-1)^2, can take 2^17 carries!
                 "mul.wide.u16    %1, a1, a1;\n\t"
                 "mul.wide.u16    %2, a2, a2;\n\t"
                 "mul.wide.u16    %3, a3, a3;\n\t"
                 "mul.wide.u16    %4, a4, a4;\n\t"

                 "mul.wide.u16    t0, a0, a4;\n\t"
                 "add.cc.u32      %2, %2, t0;\n\t"
                 "addc.u32        %3, %3,  0;\n\t"
                 "add.cc.u32      %2, %2, t0;\n\t"
                 "addc.u32        %3, %3,  0;\n\t"

                 "mul.wide.u16    t0, a0, a2;\n\t"
                 "mul.wide.u16    t1, a1, a3;\n\t"
                 "mul.wide.u16    t2, a2, a4;\n\t"
                 "add.cc.u32      %1, %1, t0;\n\t"
                 "addc.cc.u32     %2, %2, t1;\n\t"
                 "addc.cc.u32     %3, %3, t2;\n\t"
                 "addc.u32        %4, %4,  0;\n\t"
                 "add.cc.u32      %1, %1, t0;\n\t"
                 "addc.cc.u32     %2, %2, t1;\n\t"
                 "addc.cc.u32     %3, %3, t2;\n\t"
                 "addc.u32        %4, %4,  0;\n\t"

                 "mul.wide.u16    s0, a0, a1;\n\t"
                 "mul.wide.u16    s1, a0, a3;\n\t"
                 "mul.wide.u16    s2, a2, a3;\n\t"
                 "mul.wide.u16    s3, a3, a4;\n\t"
                 // "add.cc.u32      s0, s0, s0;\n\t"
                 // "addc.cc.u32     s1, s1, s1;\n\t"
                 // "addc.cc.u32     s2, s2, s2;\n\t"
                 // "addc.cc.u32     s3, s3, s3;\n\t"
                 // "addc.u32        s4,  0,  0;\n\t"

                 "mul.wide.u16    t0, a1, a2;\n\t"
                 "mul.wide.u16    t1, a1, a4;\n\t"
                 // "add.cc.u32      t0, t0, t0;\n\t"
                 // "addc.cc.u32     t1, t1, t1;\n\t"
                 // "addc.u32        t2,  0,  0;\n\t"
                 "add.cc.u32      s1, s1, t0;\n\t"
                 "addc.cc.u32     s2, s2, t1;\n\t"
                 // "addc.cc.u32     s3, s3,  0;\n\t"
                 // "addc.u32        s4,  0,  0;\n\t"
                 "addc.u32        s3, s3,  0;\n\t"

                 // "shf.l.clamp.b32 t4, s3, s4, 16;\n\t"
                 // "shf.l.clamp.b32 t3, s2, s3, 16;\n\t"
                 // "shf.l.clamp.b32 t2, s1, s2, 16;\n\t"
                 // "shf.l.clamp.b32 t1, s0, s1, 16;\n\t"
                 // "shf.l.clamp.b32 t0,  0, s0, 16;\n\t"

                 "shf.l.clamp.b32 t4, s3,  0, 17;\n\t"
                 "shf.l.clamp.b32 t3, s2, s3, 17;\n\t"
                 "shf.l.clamp.b32 t2, s1, s2, 17;\n\t"
                 "shf.l.clamp.b32 t1, s0, s1, 17;\n\t"
                 "shf.l.clamp.b32 t0,  0, s0, 17;\n\t"

                 // "add.cc.u32      %0, %0, t0;\n\t"
                 // "addc.cc.u32     %1, %1, t1;\n\t"
                 // "addc.cc.u32     %2, %2, t2;\n\t"
                 // "addc.cc.u32     %3, %3, t3;\n\t"
                 // "addc.u32        %4, %4, t4;\n\t"

                 "add.cc.u32      %0, %0, t0;\n\t"
                 "addc.cc.u32     %1, %1, t1;\n\t"
                 "addc.cc.u32     %2, %2, t2;\n\t"
                 "addc.cc.u32     %3, %3, t3;\n\t"
                 "addc.u32        %4, %4, t4;\n\t"
                 */

                 "mul.wide.u16    %0, a0, a1;\n\t"
                 "mul.wide.u16    %1, a0, a3;\n\t"
                 "mul.wide.u16    %2, a2, a3;\n\t"
                 "mul.wide.u16    %3, a3, a4;\n\t"
                 "mul.wide.u16    s1, a1, a2;\n\t"
                 "mul.wide.u16    s2, a1, a4;\n\t"
                 "add.cc.u32      %1, %1, s1;\n\t"
                 "addc.cc.u32     %2, %2, s2;\n\t"
                 "addc.u32        %3, %3,  0;\n\t" // no futher carry needed: (2^16-1)^2, can take 2^17 carries!

                 "shf.l.clamp.b32 %4, %3,  0, 17;\n\t" // shiftleft partial sum by 16 bits *AND* multiply by two
                 "shf.l.clamp.b32 %3, %2, %3, 17;\n\t"
                 "shf.l.clamp.b32 %2, %1, %2, 17;\n\t"
                 "shf.l.clamp.b32 %1, %0, %1, 17;\n\t"
                 "shf.l.clamp.b32 %0,  0, %0, 17;\n\t"

                 "mul.wide.u16    s1, a0, a2;\n\t"
                 "mul.wide.u16    s2, a0, a4;\n\t"
                 "mul.wide.u16     t, a1, a3;\n\t"
                 "mul.wide.u16    s3, a2, a4;\n\t"
                 "add.cc.u32      s2, s2,  t;\n\t"
                 "addc.u32        s3, s3,  0;\n\t" // no futher carry needed: (2^16-1)^2, can take 2^17 carries!
                 "add.cc.u32      %1, %1, s1;\n\t"
                 "addc.cc.u32     %2, %2, s2;\n\t"
                 "addc.cc.u32     %3, %3, s3;\n\t"
                 "addc.u32        %4, %4,  0;\n\t"
                 "add.cc.u32      %1, %1, s1;\n\t"
                 "addc.cc.u32     %2, %2, s2;\n\t"
                 "addc.cc.u32     %3, %3, s3;\n\t"
                 "addc.u32        %4, %4,  0;\n\t"

                 /*
                 "add.cc.u32      %0, %0, %0;\n\t"
                 "addc.cc.u32     %1, %1, %1;\n\t"
                 "addc.cc.u32     %2, %2, %2;\n\t"
                 "addc.cc.u32     %3, %3, %3;\n\t"
                 "addc.u32        %4, %4, %4;\n\t"
                 */

                 "mul.wide.u16    s0, a0, a0;\n\t"
                 "mul.wide.u16    s1, a1, a1;\n\t"
                 "mul.wide.u16    s2, a2, a2;\n\t"
                 "mul.wide.u16    s3, a3, a3;\n\t"
                 "mul.wide.u16    s4, a4, a4;\n\t"
                 "add.cc.u32      %0, %0, s0;\n\t"
                 "addc.cc.u32     %1, %1, s1;\n\t"
                 "addc.cc.u32     %2, %2, s2;\n\t"
                 "addc.cc.u32     %3, %3, s3;\n\t"
                 "addc.u32        %4, %4, s4;\n\t"

                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
#elif (__CUDA_ARCH__ >= FERMI) &&                                                                                 \
    (CUDART_VERSION >= 4010) /* multiply-add with carry is not available on CC 1.x devices and before CUDA 4.1 */
    asm volatile("{\n\t"
                 ".reg .u32 a2;\n\t"

                 "mul.lo.u32     %0, %5, %5;\n\t" /* (a.d0 * a.d0).lo */
                 "mul.lo.u32     %1, %5, %6;\n\t" /* (a.d0 * a.d1).lo */
                 "mul.hi.u32     %2, %5, %6;\n\t" /* (a.d0 * a.d1).hi */

                 "add.u32        a2, %7, %7;\n\t" /* shl(a.d2) */

                 "add.cc.u32     %1, %1, %1;\n\t" /* 2 * (a.d0 * a.d1).lo */
                 "addc.cc.u32    %2, %2, %2;\n\t" /* 2 * (a.d0 * a.d1).hi */
                 "madc.hi.u32    %3, %5, a2, 0;\n\t" /* 2 * (a.d0 * a.d2).hi */
                 /* %3 (res.d3) has some space left because a2 is < 2^17 */

                 "mad.hi.cc.u32  %1, %5, %5, %1;\n\t" /* (a.d0 * a.d0).hi */
                 "madc.lo.cc.u32 %2, %6, %6, %2;\n\t" /* (a.d1 * a.d1).lo */
                 "madc.hi.cc.u32 %3, %6, %6, %3;\n\t" /* (a.d1 * a.d1).hi */
                 "madc.lo.u32    %4, %7, %7, 0;\n\t" /* (a.d2 * a.d2).lo */

                 "mad.lo.cc.u32  %2, %5, a2, %2;\n\t" /* 2 * (a.d0 * a.d2).lo */
                 "madc.lo.cc.u32 %3, %6, a2, %3;\n\t" /* 2 * (a.d1 * a.d2).lo */
                 "madc.hi.u32    %4, %6, a2, %4;\n\t" /* 2 * (a.d1 * a.d2).hi */
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
#else
    asm volatile("{\n\t"
                 ".reg .u32 a2, t1;\n\t"

                 "mul.lo.u32     %0, %5, %5;\n\t" /* (a.d0 * a.d0).lo */
                 "mul.lo.u32     %1, %5, %6;\n\t" /* (a.d0 * a.d1).lo */
                 "mul.hi.u32     %2, %5, %6;\n\t" /* (a.d0 * a.d1).hi */

                 "add.u32        a2, %7, %7;\n\t" /* shl(a.d2) */

                 "add.cc.u32     %1, %1, %1;\n\t" /* 2 * (a.d0 * a.d1).lo */
                 "addc.cc.u32    %2, %2, %2;\n\t" /* 2 * (a.d0 * a.d1).hi */
                 "mul.hi.u32     t1, %5, a2;\n\t" /* 2 * (a.d0 * a.d2).hi */
                 "addc.u32       %3, t1,  0;\n\t" /* %3 (res.d3) has some space left because a2 is < 2^17 */

                 "mul.hi.u32     t1, %5, %5;\n\t" /* (a.d0 * a.d0).hi */
                 "add.cc.u32     %1, %1, t1;\n\t"
                 "mul.lo.u32     t1, %6, %6;\n\t" /* (a.d1 * a.d1).lo */
                 "addc.cc.u32    %2, %2, t1;\n\t"
                 "mul.hi.u32     t1, %6, %6;\n\t" /* (a.d1 * a.d1).hi */
                 "addc.cc.u32    %3, %3, t1;\n\t"
                 "mul.lo.u32     t1, %7, %7;\n\t" /* (a.d2 * a.d2).lo */
                 "addc.u32       %4, t1,  0;\n\t"

                 "mul.lo.u32     t1, %5, a2;\n\t" /* 2 * (a.d0 * a.d2).lo */
                 "add.cc.u32     %2, %2, t1;\n\t"
                 "mul.lo.u32     t1, %6, a2;\n\t" /* 2 * (a.d1 * a.d2).lo */
                 "addc.cc.u32    %3, %3, t1;\n\t"
                 "mul.hi.u32     t1, %6, a2;\n\t" /* 2 * (a.d1 * a.d2).hi */
                 "addc.u32       %4, %4, t1;\n\t"
                 "}"
                 : "=r"(res->d0), "=r"(res->d1), "=r"(res->d2), "=r"(res->d3), "=r"(res->d4)
                 : "r"(a.d0), "r"(a.d1), "r"(a.d2));
#endif
}
