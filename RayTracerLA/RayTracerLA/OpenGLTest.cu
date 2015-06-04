#include "OpenGLTest.cuh"

__global__ void createGPUTexture(uchar4* result, unsigned int imageWidth, unsigned int imageHeight)
{
	unsigned int tx = threadIdx.x;
	unsigned int ty = threadIdx.y;
	unsigned int bw = blockDim.x;
	unsigned int bh = blockDim.y;
	unsigned int u = (bw * blockIdx.x) + tx;
	unsigned int v = (bh * blockIdx.y) + ty;
	
	unsigned int index = (v * imageWidth) + u;

	result[index] = make_uchar4(255.0f, 255.f, 25.0f, 255.0f);
}
__global__ void wow(uchar4* pos, unsigned int width, unsigned int height, float time)
{
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	unsigned int x = index%width;
	unsigned int y = index / width;

	if (index < width*height) {
		unsigned char r = (x + (int)time) & 0xff;
		unsigned char g = (y + (int)time) & 0xff;
		unsigned char b = ((x + y) + (int)time) & 0xff;

		// Each thread writes one pixel location in the texture (textel)
		pos[index] = make_uchar4(r,g,b, 255.0f);
	}
}

void OpenGLTest::renderScene()
{
	glBindFramebuffer(GL_FRAMEBUFFER, glfbo);
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(60.0, (GLdouble)windowSize.x/ (GLdouble)windowSize.y, 0.1, 10.0);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glTranslatef(0.0f, 0.0f, -3.0f);

	glViewport(0, 0, windowSize.x, windowSize.y);

	glEnable(GL_LIGHTING);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LESS);

	glBegin(GL_TRIANGLES);
	glColor3f(0.1, 0.2, 0.3);
	glVertex3f(0, 0, 0);
	glVertex3f(1, 0, 0);
	glVertex3f(0, 1, 0);
	glEnd();

	glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void OpenGLTest::drawFrame()
{
	glBindTexture(GL_TEXTURE_2D, glFinalTexture);
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_LIGHTING);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glPushAttrib(GL_VIEWPORT_BIT);
	glViewport(0, 0, windowSize.x, windowSize.y);
	glBegin(GL_QUADS);
	glTexCoord2f(0.0, 0.0); glVertex3f(-1.0, -1.0, 0.5);
	glTexCoord2f(1.0, 0.0); glVertex3f(1.0, -1.0, 0.5);
	glTexCoord2f(1.0, 1.0); glVertex3f(1.0, 1.0, 0.5);
	glTexCoord2f(0.0, 1.0); glVertex3f(-1.0, 1.0, 0.5);
	glEnd();

	glPopAttrib();

	glMatrixMode(GL_PROJECTION);
	glPopMatrix();

	glDisable(GL_TEXTURE_2D);
}

texture<uchar4, cudaTextureType2D, cudaReadModeElementType>cudaTexRef;

void OpenGLTest::createFrame(float time)
{

	cudaArray* cudaTexArraySource;
	cudaArray* cudaTexArrayResult;

	cudaGraphicsResource_t resources[2] = { cudaRenderTexture, cudaFinalTexture};
	cudaGraphicsMapResources(2, resources);
	
	cutilSafeCall(cudaGraphicsSubResourceGetMappedArray(&cudaTexArraySource, cudaRenderTexture, 0, 0));
	cutilSafeCall(cudaGraphicsSubResourceGetMappedArray(&cudaTexArrayResult, cudaFinalTexture, 0, 0));
	cutilSafeCall(cudaBindTextureToArray(cudaTexRef, cudaTexArraySource));

	//Check that the created buffer is large enought.
	size_t bufferSize = windowSize.x*windowSize.y*sizeof(uchar4);
	if (bufferSize != cudaAllocResultTexture_size)
	{
		if (cudaAllocResultTexture != nullptr)
		{
			cutilSafeCall(cudaFree(cudaAllocResultTexture));
		}
		cudaAllocResultTexture_size = bufferSize;
		cutilSafeCall(cudaMalloc(&cudaAllocResultTexture, bufferSize));
	}

	int BLOCK_SIZE = 16;
	size_t blocksW = (size_t)ceilf(windowSize.x / (float)BLOCK_SIZE);
	size_t blocksH = (size_t)ceilf(windowSize.y / (float)BLOCK_SIZE);
	dim3 gridDim(blocksW, blocksH, 1);
	dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE, 1);

	// Run code here.
	//createGPUTexture << <gridDim, blockDim>> >(cudaAllocResultTexture, windowSize.x, windowSize.y);
	wow << <(windowSize.x*windowSize.y)/256, 256 >> >(cudaAllocResultTexture, windowSize.x, windowSize.y, time);
	cutilSafeCall(cudaMemcpyToArray(cudaTexArrayResult, 0, 0, cudaAllocResultTexture, bufferSize, cudaMemcpyDeviceToDevice));

	// Unmap mapping to PBO so that OpenGL can access.
	cutilSafeCall(cudaUnbindTexture(cudaTexRef));
	cutilSafeCall(cudaGraphicsUnmapResources(2, resources));
}

void OpenGLTest::setupMatrix()
{
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrtho(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glPushAttrib(GL_VIEWPORT_BIT);
	glViewport(0,0, windowSize.x, windowSize.y); 
	//glOrtho(0.0, windowSize.x, windowSize.y, 0.0, -1.0, 1.0);
}

void OpenGLTest::setupCUDA()
{
	cudaGLSetGLDevice(0);
}

void OpenGLTest::setupOpenGL()
{
	glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
	glDisable(GL_DEPTH_TEST);

	// Setup the viewport
	glViewport(0, 0, windowSize.x, windowSize.y);

	// Setup the projection matrix
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	gluPerspective(60.0, (GLdouble)windowSize.x / (GLdouble)windowSize.y, 0.1, 1.0);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
}

void OpenGLTest::resize(int width, int height)
{
	windowSize.x = width;
	windowSize.y = height;
	createTexture(glRenderTexture, windowSize.x, windowSize.y);
	createDepthBuffer(this->gldbo, windowSize.x, windowSize.y);
	createFrameBuffer(this->glfbo, glRenderTexture, gldbo);

	createTexture(glFinalTexture, windowSize.x, windowSize.y);

	createCUDAResource(this->cudaRenderTexture, glRenderTexture, cudaGraphicsMapFlagsReadOnly);
	createCUDAResource(this->cudaFinalTexture, glFinalTexture, cudaGraphicsMapFlagsWriteDiscard);
}

void OpenGLTest::createDepthBuffer(GLuint& depthBuffer, unsigned int width, unsigned int height)
{
	// Delete the existing depth buffer if there is one.
	deleteDepthBuffer(depthBuffer);

	glGenRenderbuffers(1, &depthBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, depthBuffer);

	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, width, height);

	// Unbind the depth buffer
	glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

void OpenGLTest::deleteDepthBuffer(GLuint& depthBuffer)
{
	if (depthBuffer != 0)
	{
		glDeleteRenderbuffers(1, &depthBuffer);
		depthBuffer = 0;
	}
}

void OpenGLTest::createPBO(GLuint& bufferID, size_t size)
{
	// Make sure the buffer doesn't already exist
	deletePBO(bufferID);

	glGenBuffers(1, &bufferID);
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, bufferID);
	glBufferData(GL_PIXEL_UNPACK_BUFFER, size, NULL, GL_STREAM_DRAW);

	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
}

void OpenGLTest::deletePBO(GLuint& bufferID)
{
	if (bufferID != 0)
	{
		glDeleteBuffers(1, &bufferID);
		bufferID = 0;
	}
}

void OpenGLTest::createFrameBuffer(GLuint& framebuffer, GLuint colorAttachment0, GLuint depthAttachment)
{
	// Delete the existing framebuffer if it exists.
	deleteFrameBuffer(framebuffer);

	glGenFramebuffers(1, &framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorAttachment0, 0);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthAttachment);

	// Check to see if the frame buffer is valid
	GLenum fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if (fboStatus != GL_FRAMEBUFFER_COMPLETE)
	{
		std::cerr << "ERROR: Incomplete framebuffer status." << std::endl;
	}

	// Unbind the frame buffer
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void OpenGLTest::deleteFrameBuffer(GLuint& framebuffer)
{
	if (framebuffer != 0)
	{
		glDeleteFramebuffers(1, &framebuffer);
		framebuffer = 0;
	}
}

// Create a texture resource for rendering to.
void OpenGLTest::createTexture(GLuint& texture, unsigned int width, unsigned int height)
{
	// Make sure we don't already have a texture defined here
	deleteTexture(texture);

	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);

	// set basic parameters
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

	// Create texture data (4-component unsigned byte)
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

	// Unbind the texture
	glBindTexture(GL_TEXTURE_2D, 0);
}

void OpenGLTest::deleteTexture(GLuint& texture)
{
	if (texture != 0)
	{
		glDeleteTextures(1, &texture);
		texture = 0;
	}
}

void OpenGLTest::createCUDAResource(cudaGraphicsResource_t& cudaResource, GLuint GLtexture, cudaGraphicsMapFlags mapFlags)
{
	// Map the GL texture resource with the CUDA resource
	cudaGraphicsGLRegisterImage(&cudaResource, GLtexture, GL_TEXTURE_2D, mapFlags);
}

void OpenGLTest::deleteCUDAResource(cudaGraphicsResource_t& cudaResource)
{
	if (cudaResource != 0)
	{
		cudaGraphicsUnregisterResource(cudaResource);
		cudaResource = 0;
	}
}
