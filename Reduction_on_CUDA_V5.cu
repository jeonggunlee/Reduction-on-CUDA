#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <stdlib.h>

typedef unsigned long long uint64_t;

#define RT 1000 // Kernel repeats 1000 times

void initData(uint64_t *data, uint64_t data_len);
void printData(uint64_t *data, uint64_t data_len, float using_time);
__global__ void reduce_v5(uint64_t *data_gpu);



int main(){
	
	/*--Init Data on Host Momory-------*/
	uint64_t data_len = 1024;
	uint64_t *data = (uint64_t *) malloc(sizeof(uint64_t) * data_len);
	initData(data, data_len);


	/*--Init CUDA Environment----*/
	int threads_num = 1024;
	int blocks_num = 1;
	dim3 threads, blocks;
	threads.x = threads_num;
	blocks.x = blocks_num;
	cudaSetDevice(0);
	

	/*--Load Data from Host to Device---*/
	uint64_t * data_gpu;
	cudaMalloc((uint64_t**)&data_gpu, sizeof(uint64_t) * data_len);
	cudaMemcpy(data_gpu, data, sizeof(uint64_t) * data_len, cudaMemcpyHostToDevice);

	/*--Run CUDA Kernel--*/
	float using_time = 0.0;
	cudaEvent_t start, stop;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start, 0);

	// repeating 1000 times
	for(int i = 0; i < RT; i++){
		reduce_v5<<<blocks, threads>>>(data_gpu);
	}

	cudaEventRecord(stop, 0);
	cudaEventSynchronize(start);
	cudaEventSynchronize(stop);
	cudaEventElapsedTime(&using_time, start, stop);

	/*--Store Data from Device to Host--*/
	cudaMemcpy(data, data_gpu, sizeof(uint64_t) * 1, cudaMemcpyDeviceToHost);
	printData(data, 1, using_time);
	
	
	return 0;
}



void initData(uint64_t *data, uint64_t data_len){
	for(uint64_t i = 0; i < data_len; i++){
		data[i] = i;
	}
}


void printData(uint64_t *data, uint64_t data_len, float using_time){
	printf("\n-----Reduction Result (version 4)----\n");
	printf("\n0+1+2+3+...+1023 = ");
	uint64_t count = 0;
	for(uint64_t i = 0; i < data_len; i++){
		count ++;
		if(count % 11 == 0) printf("\n");
		printf("%llu",data[i]/RT);
	}
	printf("\n\nusing time (repeating %d times): %f(ms)\n", RT, using_time);
	printf("\n\n-----The End--------\n\n");
}


__global__ void reduce_v5(uint64_t *data_gpu){
	int tid = threadIdx.x;

	// load one-time coputation data into shared memory
	__shared__ uint64_t data[512];
	if(tid < 512){
		data[tid] = data_gpu[tid] + data_gpu[tid + 512];
	}
	__syncthreads();

	// reduction
	if(tid < 256){
		data[tid] += data[tid + 256];
	}
	__syncthreads();

	if(tid < 128){
		data[tid] += data[tid + 128];
	}
	__syncthreads();

	if(tid < 64){
		data[tid] += data[tid + 64];
	}
	__syncthreads();

	if(tid < 32){
		data[tid] += data[tid + 32];
		data[tid] += data[tid + 16];
		data[tid] += data[tid + 8];
		data[tid] += data[tid + 4];
		data[tid] += data[tid + 2];
		data[tid] += data[tid + 1];
	}

	// write root node (data[0]) back
	if(tid == 0){
		data_gpu[tid] = data[tid];
	}
}