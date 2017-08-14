#include "toy.h"
#include "toy_env.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <assert.h>

struct toy_env {
    lua_State *L;
};

static struct toy_env *E = NULL;

const char *
toy_getenv(const char*key) {
    lua_State *L = E->L;
    lua_getglobal(L, key);
    const char * result = lua_tostring(L, -1);
    lua_pop(L, 1);
    return result;
}

void
toy_setenv(const char *key, const char *value) {
    lua_State *L = E->L;
    lua_getglobal(L, key);
    assert(lua_isnil(L, -1));
    lua_pop(L,1);
    lua_pushstring(L,value);
    lua_setglobal(L,key); 
}

void
toy_env_init() {
    E = toy_malloc(sizeof(*E));
    E->L = luaL_newstate();
}