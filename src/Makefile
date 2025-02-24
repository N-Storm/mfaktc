# configure path to CUDA Toolkit
CUDA_DIR = /usr/local/cuda
CUDA_INCLUDE = -I$(CUDA_DIR)/include/
CUDA_LIB = -L$(CUDA_DIR)/lib64/

# compiler settings for .c files (CPU)
CC = gcc
CFLAGS = -Wall -Wextra -O3 $(CUDA_INCLUDE) -malign-double
CFLAGS_EXTRA_SIEVE = -funroll-all-loops

# compiler settings for .cu files (GPU)
NVCC = nvcc
NVCCFLAGS = $(CUDA_INCLUDE) --ptxas-options=-v

# generate code for various compute capabilities
# don't try "arch=compute_1x,code=sm_1x". WON'T WORK! Stay with mfaktc 0.21 for CC 1.1, 1.2 and 1.3 GPUs.
# NVCCFLAGS += --generate-code arch=compute_20,code=sm_20 # CC 2.x GPUs will use this code, one code fits all!
# NVCCFLAGS += --generate-code arch=compute_30,code=sm_30 # all CC 3.x GPUs _COULD_ use this code
# NVCCFLAGS += --generate-code arch=compute_35,code=sm_35 # but CC 3.5 (3.2?) _CAN_ use funnel shift which is useful for mfaktc
# NVCCFLAGS += --generate-code arch=compute_50,code=sm_50 # CC 5.x GPUs (Maxwell) will use this code
NVCCFLAGS += -arch=all -O3

# pass some options to the C host compiler (e.g. gcc on Linux)
NVCCFLAGS += --compiler-options=-Wall

# Linker
LD = gcc
LDFLAGS = -fPIC $(CUDA_LIB) -lcudart_static -lm -lstdc++

INSTALL = install

##############################################################################

CSRC  = sieve.c timer.c parse.c read_config.c mfaktc.c checkpoint.c \
	signal_handler.c output.c crc.c
CUSRC = tf_96bit.cu tf_barrett96.cu tf_barrett96_gs.cu gpusieve.cu \
        cuda_basic_stuff.cu

COBJS  = $(CSRC:.c=.o)
CUOBJS = $(CUSRC:.cu=.o) tf_75bit.o

##############################################################################

all: ../mfaktc ../mfaktc.ini

../mfaktc : $(COBJS) $(CUOBJS)
	$(LD) $^ -o $@ $(LDFLAGS)

clean :
	rm -f *.o *~

sieve.o : sieve.c
	$(CC) $(CFLAGS) $(CFLAGS_EXTRA_SIEVE) -c $< -o $@

tf_75bit.o : tf_96bit.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@ -DSHORTCUT_75BIT

%.o : %.cu
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

../%.ini : %.ini
	$(INSTALL) -m 644 $< ..

.PHONY: all clean
