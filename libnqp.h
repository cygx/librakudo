#ifndef LIBNQP_H_
#define LIBNQP_H_

#include "moarembed.h"

#ifdef _WIN32
#define LIBNQP_IMPORT __declspec(dllimport)
#else
#define LIBNQP_IMPORT
#endif

LIBNQP_IMPORT void libnqp_init(MoarAPI *api, MoarVM *vm);
LIBNQP_IMPORT void libnqp_run(int argc, char **argv);

#endif
