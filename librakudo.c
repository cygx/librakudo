/* TODO: error handling! */

#include "moarembed.h"

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT
#endif

EXPORT void librakudo_init(MoarAPI *api, MoarVM *vm);
EXPORT void librakudo_run(int argc, char **argv);

#if 0
static const unsigned char nqp[] = {
    "x<--[|]--"
};
#endif

void librakudo_init(MoarAPI *api, MoarVM *vm) {
    (void)api, (void)vm;
#if 0
   api->add_virtual_file(vm, "nqp.moarvm", nqp, sizeof nqp);
#endif
}

void librakudo_run(int argc, char **argv) {
    const char *moardll, *nqpdll;
    void *nqplib;
    void (* libnqp_init)(MoarAPI *, MoarVM *);

    MoarAPI api;
    MoarVM *vm;

    if((moardll = getenv("MOARDLL")) == NULL)
        moardll = "D:/dev/p6/mingw32/bin/moar.dll";

    if((nqpdll = getenv("NQPDLL")) == NULL)
        nqpdll = "D:/dev/p6/mingw32/bin/nqp.dll";

    MoarAPI_load(&api, moardll);
    if(api.version < 1)
        return;

    nqplib = MVM_embed_dlopen(nqpdll);
    if(!nqplib) return;

    libnqp_init = (void (*)(MoarAPI *, MoarVM *))MVM_embed_dlsym(
        nqplib, "libnqp_init");
    if(!libnqp_init) return;

    vm = api.create();
    libnqp_init(&api, vm);
    librakudo_init(&api, vm);

    api.set_clargs(vm, argc - 1, argv + 1);
    api.set_exec_name(vm, argv[0]);
    api.set_prog_name(vm, "perl6");
    api.run_file(vm, "perl6.moarvm");
    api.exit(vm);
}
