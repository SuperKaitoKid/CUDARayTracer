#ifndef	CORNELLSTATE_H
#define CORNELLSTATE_H

#include <SFML/Graphics.hpp>
#include <cuda_runtime.h>

#include "Core/States/StateFactory.h"
#include "Core/States/StateManager.h"
#include "States/TraceState.cuh"

#include "Core/GeneralTypedef.h"
#include "Core/cutil.h"
#include "Core/cutil_inline_runtime.h"

#include "Scene/Materials.h"
#include "Scene/SceneObjects.h"
#include "Scene/Camera.h"

#include "PathTracer.cuh"



class CornellState : public StateFactory<CornellState, State>, public TraceState
{
	public:
		/// Function that should be called to instantiate the class.
		static State* createInternal(StateManager *sm, sf::RenderWindow *rw)
		{
			return new CornellState(sm, rw);
		};

		void end();

	private:
		void setUpScene();

	protected:
		CornellState(StateManager* sm, sf::RenderWindow* window) : TraceState(sm, window){};
		CornellState(const CornellState& other) : TraceState(other){};
		CornellState& operator =(const State& other){ return *this; };
};

#endif // CORNELLSTATE_H