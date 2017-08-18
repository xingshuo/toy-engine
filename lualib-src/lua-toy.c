#include "toy.h"
#include "toy_server.h"
#include "toy_env.h"
#include "toy_timer.h"
#include "lua-seri.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

static int
traceback (lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg)
        luaL_traceback(L, L, msg, 1);
    else {
        lua_pushliteral(L, "(no error message)");
    }
    return 1;
}

static int
_cb(struct toy_context* ctx, int type, uint32_t session, const void * msg, size_t sz) {
    lua_State *L = ctx->L;
    int trace = 1;
    lua_settop(L, 0);
    lua_pushcfunction(L, traceback);
    lua_rawgetp(L, LUA_REGISTRYINDEX, _cb);
    lua_pushinteger(L, type);
    lua_pushinteger(L, session);
    lua_pushlightuserdata(L, (void *)msg);
    lua_pushinteger(L,sz);
    int r = lua_pcall(L, 4, 0 , trace);
    if (r == LUA_OK) {
        return 0;
    }
    switch (r) {
    case LUA_ERRRUN:
        fprintf(stderr, "lua call error %s\n", lua_tostring(L,-1));
        break;
    case LUA_ERRMEM:
        fprintf(stderr, "lua memory error \n");
        break;
    case LUA_ERRERR:
        fprintf(stderr, "lua error in error\n");
        break;
    case LUA_ERRGCMM:
        fprintf(stderr, "lua gc error\n");
        break;
    };

    lua_pop(L,1);

    return 0;
}

static int
lcallback(lua_State *L) {
    struct toy_context* ctx = toy_server_get_context();
    luaL_checktype(L,1,LUA_TFUNCTION);
    lua_settop(L,1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, _cb);
    toy_callback(ctx, _cb);
    return 0;
}

static int
lgetenv(lua_State *L) {
    const char * key = luaL_checkstring(L,1);
    const char * value = toy_getenv(key);
    if (value) {
        lua_pushstring(L, value);
        return 1;
    }
    return 0;
}

static int
lsetenv(lua_State *L) {
    const char * key = luaL_checkstring(L,1);
    const char * value = luaL_checkstring(L,2);
    toy_setenv(key,value);
    return 0;
}

static int
ltimeout(lua_State *L) {
    int ti = luaL_checkinteger(L,1);
    uint32_t session = luaL_checkinteger(L,2);
    toy_timeout(ti, session);
    return 0;
}

static int
lpackstring(lua_State *L) {
    luaseri_pack(L);
    char * str = (char *)lua_touserdata(L, -2);
    int sz = lua_tointeger(L, -1);
    lua_pushlstring(L, str, sz);
    toy_free(str);
    return 1;
}

static int
ltostring(lua_State *L) {
    if (lua_isnoneornil(L,1)) {
        return 0;
    }
    char * msg = lua_touserdata(L,1);
    int sz = luaL_checkinteger(L,2);
    lua_pushlstring(L,msg,sz);
    return 1;
}

static int
ltrash(lua_State *L) {
    int t = lua_type(L,1);
    switch (t) {
    case LUA_TSTRING: {
        break;
    }
    case LUA_TLIGHTUSERDATA: {
        void * msg = lua_touserdata(L,1);
        luaL_checkinteger(L,2);
        toy_free(msg);
        break;
    }
    default:
        luaL_error(L, "toy.trash invalid param %s", lua_typename(L,t));
    }

    return 0;
}

LUAMOD_API int
luaopen_ltoy(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "callback", lcallback },
        { "setenv", lsetenv},
        { "getenv", lgetenv},
        { "timeout", ltimeout},
        { "pack", luaseri_pack },
        { "unpack", luaseri_unpack },
        { "packstring", lpackstring },
        { "tostring", ltostring },
        { "trash" , ltrash },
        { NULL, NULL },
    };
    luaL_newlibtable(L, l);
    luaL_setfuncs(L,l,0);
    return 1;
}