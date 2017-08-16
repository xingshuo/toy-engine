#include "toy.h"
#include "toy_env.h"
#include "toy_mq.h"
#include "toy_server.h"

static struct toy_context* C = NULL;

static void
dispatch_message(struct toy_message* msg) {
    int type = msg->sz >> MESSAGE_TYPE_SHIFT;
    size_t sz = msg->sz & MESSAGE_TYPE_MASK;
    C->cb(C, type, msg->session, msg->data, sz);
}

static void*
l_alloc (void *ud, void *ptr, size_t osize, size_t nsize) {
    if (nsize == 0) {
        toy_free(ptr);
        return NULL;
    }
    else
        return toy_realloc(ptr, nsize);
}

struct toy_context*
toy_server_get_context() {
    return C;
}

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

static const char *
optstring(const char *key, const char * str) {
    const char * ret = toy_getenv(key);
    if (ret == NULL) {
        return str;
    }
    return ret;
}

static int
launch(lua_State *L) {
    lua_gc(L, LUA_GCSTOP, 0);
    luaL_openlibs(L);

    const char *path = optstring("lua_path","./lualib/?.lua");
    lua_pushstring(L, path);
    lua_setglobal(L, "LUA_PATH");
    const char *cpath = optstring("lua_cpath","./luaclib/?.so");
    lua_pushstring(L, cpath);
    lua_setglobal(L, "LUA_CPATH");

    lua_pushcfunction(L, traceback);
    assert(lua_gettop(L) == 1);

    const char * loader = "./lualib/bootstrap.lua";
    
    int r = luaL_loadfile(L,loader);
    if (r != LUA_OK) {
        fprintf(stderr, "Can't load %s : %s\n", loader, lua_tostring(L, -1));
        return 1;
    }
    const char * start = toy_getenv("start");
    assert(start);
    lua_pushstring(L, start);
    r = lua_pcall(L,1,0,1);
    if (r != LUA_OK) {
        fprintf(stderr, "lua loader error : %s\n", lua_tostring(L, -1));
        return 1;
    }
    lua_settop(L,0);
    lua_gc(L, LUA_GCRESTART, 0);

    return 0;
}

int
toy_server_init() {
    struct toy_context *c = toy_malloc(sizeof(*c));
    c->L = lua_newstate(l_alloc, NULL);
    C = c;
    int err = launch(C->L);
    if (err) {
        fprintf(stderr, "init cb error");
        return 1;
    }
    return 0;
}

int
toy_server_dispatch_msg(int n) {
    struct toy_message msg;
    int total = 0;
    if (n <= 0) { //dispatch all
        while (toy_mq_pop(&msg)) {
            dispatch_message(&msg);
            total++;
        }
        return total;
    }else {
        while (total < n && toy_mq_pop(&msg)) {
            dispatch_message(&msg);
            total++;
        }
        return total;
    }
}

void toy_callback(struct toy_context * ctx, toy_cb cb) {
    ctx->cb = cb;
}