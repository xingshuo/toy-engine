#include "toy.h"
#include "toy_socket.h"

#include <lua.h>
#include <lauxlib.h>

#include <sys/socket.h>
#include <arpa/inet.h>

#define BACKLOG 32

static void
concat_table(lua_State *L, int index, void *buffer, size_t tlen) {
    char *ptr = buffer;
    int i;
    for (i=1;lua_geti(L, index, i) != LUA_TNIL; ++i) {
        size_t len;
        const char * str = lua_tolstring(L, -1, &len);
        if (str == NULL || tlen < len) {
            break;
        }
        memcpy(ptr, str, len);
        ptr += len;
        tlen -= len;
        lua_pop(L,1);
    }
    if (tlen != 0) {
        toy_free(buffer);
        luaL_error(L, "Invalid strings table");
    }
    lua_pop(L,1);
}

static size_t
count_size(lua_State *L, int index) {
    size_t tlen = 0;
    int i;
    for (i=1;lua_geti(L, index, i) != LUA_TNIL; ++i) {
        size_t len;
        luaL_checklstring(L, -1, &len);
        tlen += len;
        lua_pop(L,1);
    }
    lua_pop(L,1);
    return tlen;
}

static void *
get_buffer(lua_State *L, int index, int *sz) {
    void *buffer;
    switch(lua_type(L, index)) {
        const char * str;
        size_t len;
    case LUA_TUSERDATA:
    case LUA_TLIGHTUSERDATA:
        buffer = lua_touserdata(L,index);
        *sz = luaL_checkinteger(L,index+1);
        break;
    case LUA_TTABLE:
        // concat the table as a string
        len = count_size(L, index);
        buffer = toy_malloc(len);
        concat_table(L, index, buffer, len);
        *sz = (int)len;
        break;
    default:
        str =  luaL_checklstring(L, index, &len);
        buffer = toy_malloc(len);
        memcpy(buffer, str, len);
        *sz = (int)len;
        break;
    }
    return buffer;
}

static int
llisten(lua_State *L) {
    const char * host = luaL_checkstring(L,1);
    int port = luaL_checkinteger(L,2);
    int backlog = luaL_optinteger(L,3,BACKLOG);
    int id = toy_socket_listen(host, port, backlog);
    if (id < 0) {
        return luaL_error(L, "Listen error");
    }

    lua_pushinteger(L,id);
    return 1;
}

static int
lstart(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    toy_socket_start(id);
    return 0;
}

static int
lclose(lua_State *L) {
    int id = luaL_checkinteger(L,1);
    toy_socket_close(id);
    return 0;
}

static int
lnodelay(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    toy_socket_nodelay(id);
    return 0;
}

static int
lsend(lua_State *L) {
    int id = luaL_checkinteger(L, 1);
    int sz = 0;
    void *buffer = get_buffer(L, 2, &sz);
    int err = toy_socket_send(id, buffer, sz);
    lua_pushboolean(L, !err);
    return 1;
}


LUAMOD_API int
luaopen_socketdriver(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "listen", llisten },
        { "start", lstart },
        { "close", lclose },
        { "nodelay", lnodelay },
        { "send", lsend },
        { NULL, NULL },
    };
    luaL_newlib(L,l);
    luaL_setfuncs(L,l,0);

    return 1;
}