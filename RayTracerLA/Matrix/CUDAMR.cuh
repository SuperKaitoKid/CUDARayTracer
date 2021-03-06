#ifndef CUDAMR_H
#define CUDAMR_H

#include <SFML/Graphics.hpp>

#include "device_launch_parameters.h"
#include "cuda_runtime.h"
#include "vector_types.h"
#include "Core/CUDADef.h"
#include "Core/GeneralTypedef.h"

CUDA_MFUNCTION void addCUDAMR(float* mA, float* mB, uint vectorSize);
CUDA_MFUNCTION void subCUDAMR(float* mA, float* mB, uint vectorSize);
CUDA_MFUNCTION void multCUDAMR(float* mA, float* mB, float* result, uint matrixDim);

__global__ void kernelAddCUDAMR(float* mA, float* mB, uint vectorSize);
__global__ void kernelSubCUDAMR(float* mA, float* mB, uint vectorSize);
__global__ void kernelMultCUDAMR(float* mA, float* mB, float* result, uint matrixDim);

namespace mat
{
	/**
	* Class to extended by any matrix or vector related functions.
	* Allows the class to work with CUDA.
	*/
	class CUDAMR
	{
		public:

			bool setValue(float values[], uint size);

			/**
			* Copies the value from GPU to CPU memory.
			*/
			void copyGPUValue();

			/*
			* Copies CPU value to GPU. Allocation of GPU is required.
			*/
			void copyValueToGPU();

			/**
			* Call this function when you want to allocate memory into the GPU.
			* Mainly used internally. Returns false if space already allocated.
			* Short answer to our slowness problem. Nothing too complicated like a
			* memory manager.
			*/
			bool allocateGPUMemory();

			/**
			* For whatever reason, perhaps a melt down, use this to delete allocation
			* in GPU. Returns false if internal ptr is null.
			*/
			bool deallocateGPUMemory();

			void add(CUDAMR* value);

			void sub(CUDAMR* value);

			// This represents A in Ax = b
			void mult(CUDAMR* value, CUDAMR* result);

			/* Operator Overloading */
			friend std::ostream& operator<<(std::ostream& os, const CUDAMR& obj);

		protected:
			CUDAMR(uint x, uint y);

			virtual ~CUDAMR();


			// Pointer to 1D array storing all the matrix data.
			// Converted to 2D within functions.
			float* value;
			// Pointer to allocation in GPU. Null by default.
			float* d_value;

			// Stores the byte size of the allocated space for reference.
			size_t byteSize;

			// Represents the number of elements inside the array.
			sf::Vector2u size;
	};

}

#endif // CUDAMR_H