#include "udf.h"
DEFINE_CG_MOTION(velocity,dt,vel,omega,time,dtime)
{
	// int f, w, A;
	//f = 5;
	// w = 2 * 3.14 * f;
	// A = 0.005;
	double pi = 3.1415926;
	double amplitude = 0.01;
	double frequency = 10.0;
	// vel[2] = 2 * 3.14 * 5 * 0.005 * cos(2 * 3.14 * 5 * time);
	vel[0] = 2 * pi * frequency * amplitude * cos(2 * pi * frequency * time);
}
