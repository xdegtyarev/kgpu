/* This work is licensed under the terms of the GNU GPL, version 2.  See
 * the GPL-COPYING file in the top-level directory.
 *
 * Copyright (c) 2010-2011 University of Utah and the Flux Group.
 * All rights reserved.
 *
 *
 * P and Q disk computing function, mostly derived from the kernel:
 * /lib/raid6/int.uc
 * Support x86_64 only.
 *
 * To be included by others.
 */

#define NBYTES(x) ((x) * 0x0101010101010101UL)
#define NSIZE  8
#define NSHIFT 3

#define SHLBYTE(v) (((v)<<1)&NBYTES(0xfe))
#define MASK(v) { u64 vv = (v)&NBYTES(0x80); (vv<<1)-(vv>>7);}

/*
 * @disks: number of disks, p and q included
 * @dsize: unit size, or a stripe?
 * @data: disk data 
 */
__kernel__ void raid6_pq(int disks, unsigend long dsize, u8 *data)
{
    u64 *d = (u64*)data;
    int z0, offset64, step64, tid;

    u64 wd0, wq0, wp0;
    
    tid = blockDim.x*blockIdx.x+threadIdx.x;
    step64 = dsize/sizeof(u64);
    z0 = disks-3;
    offset64 = step64*z0+tid;
    
    wq0 = wp0 = d[offset64];
    for (offset64 -= step64; offset64>=0; offset64 -=step64) {
	wd0 = d[offset64];
	wp0 ^= wd0;
	wq0 = SHLBYTE(wq0) ^ (MASK(wq0)&NBYTES(0x1d)) ^ wd0;
    }
    d[step64*(z0+1)+tid] = wp0;
    d[step64*(z0+2)+tid] = wq0;    
}

/*
 * Fixed number of disks version
 * Naming: _fdx, where x is the number of disks, including p and q.
 *
 * shared memory seems not a necessary trick because every datum is
 * accessed only once.
 *
 */
__kernel__ void raid6_pq_fd6(int disks, unsigend long dsize, u8 *data)
{
    u64 *d = (u64*)data;
    int z0, offset64, step64, tid;

    u64 wq0, wp0;

    __shared__ u64 dsk[4][THREAD_PER_BLOCK];

    tid = blockDim.x*blockIdx.x+threadIdx.x;
    step64 = dsize/sizeof(u64);
    offset64 = step64*3+tid;
    
    // __syncthreads();
    for (z0=3; z0>=0; z0--) {
	dsk[z0][threadIdx.x] = d[offset64];
	offset64 -= step64;
    }
    
    wq0 = wp0 = dsk[3][threadIdx.x];
    for (z0=2; z0>=0; z0--) {
	wp0 ^= dsk[z0][threadIdx.x];
	wq0 =
	    SHLBYTE(wq0) ^ (MASK(wq0)&NBYTES(0x1d)) ^ dsk[z0][threadIdx.x];
    }
    d[step64*4+tid] = wp0;
    d[step64*5+tid] = wq0;    
}