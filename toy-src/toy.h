#ifndef TOY_H
#define TOY_H

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define toy_malloc malloc
#define toy_free free
#define toy_realloc realloc

#define PTYPE_SOCKET 1
#define PTYPE_TIMER 2

struct toy_context;

typedef int (*toy_cb)(struct toy_context * ctx, int type, const void * msg, size_t sz);

struct toy_context {
    lua_State * L; //main thread L
    toy_cb cb;
};

void toy_callback(struct toy_context * ctx, toy_cb cb);

#endif