#ifndef LIBRAKUDO_H_
#define LIBRAKUDO_H_

#include "moarembed.h"

#ifdef _WIN32
#define LIBRAKUDO_IMPORT __declspec(dllimport)
#else
#define LIBRAKUDO_IMPORT
#endif

LIBRAKUDO_IMPORT void librakudo_init(MoarAPI *api, MoarVM *vm);
LIBRAKUDO_IMPORT void librakudo_run(int argc, char **argv);

#endif
