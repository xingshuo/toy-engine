#include "toy.h"
#include "toy_env.h"
#include "toy_mq.h"
#include "toy_timer.h"
#include "toy_socket.h"
#include "toy_server.h"

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <assert.h>
#include <string.h>


static int EXIT = 0;
static void
handle_int(int signal) {
    if (signal == SIGINT) {
        EXIT = 1;
        toy_socket_exit();
    }
}

#define CHECK_ABORT if (EXIT==1) break;

static void
create_thread(pthread_t *thread, void *(*start_routine) (void *), void *arg) {
    if (pthread_create(thread,NULL, start_routine, arg)) {
        fprintf(stderr, "Create thread failed");
        exit(1);
    }
}

static void*
thread_timer(void* p) {
    while (1) {
        toy_updatetime();
        CHECK_ABORT
        usleep(2500);
    }
    return NULL;
}

static void*
thread_socket(void* p) {
    while (1) {
        int r = toy_socket_poll();
        if (r == 0) {
            break;
        }
        CHECK_ABORT
    }
    return NULL;
}

static void*
thread_worker(void* p) {
    while (1) {
        if (!toy_server_dispatch_msg(0)) {
            usleep(2500);
        }
        CHECK_ABORT
    }
    return NULL;
}

int sigign() {
    struct sigaction sa;
    sa.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &sa, 0);

    struct sigaction sb;
    sb.sa_handler = &handle_int;
    sb.sa_flags = SA_RESTART;
    sigfillset(&sb.sa_mask);
    sigaction(SIGINT, &sb, NULL);
    return 0;
}

static const char * load_config = "\
    local result = {}\n\
    local function getenv(name) return assert(os.getenv(name), [[os.getenv() failed: ]] .. name) end\n\
    local sep = package.config:sub(1,1)\n\
    local current_path = [[.]]..sep\n\
    local function include(filename)\n\
        local last_path = current_path\n\
        local path, name = filename:match([[(.*]]..sep..[[)(.*)$]])\n\
        if path then\n\
            if path:sub(1,1) == sep then    -- root\n\
                current_path = path\n\
            else\n\
                current_path = current_path .. path\n\
            end\n\
        else\n\
            name = filename\n\
        end\n\
        local f = assert(io.open(current_path .. name))\n\
        local code = assert(f:read [[*a]])\n\
        code = string.gsub(code, [[%$([%w_%d]+)]], getenv)\n\
        f:close()\n\
        assert(load(code,[[@]]..filename,[[t]],result))()\n\
        current_path = last_path\n\
    end\n\
    setmetatable(result, { __index = { include = include } })\n\
    local config_name = ...\n\
    include(config_name)\n\
    setmetatable(result, nil)\n\
    return result\n\
";

static void
_init_env(lua_State *L) {
    lua_pushnil(L);  /* first key */
    while (lua_next(L, -2) != 0) {
        int keyt = lua_type(L, -2);
        if (keyt != LUA_TSTRING) {
            fprintf(stderr, "Invalid config table\n");
            exit(1);
        }
        const char * key = lua_tostring(L,-2);
        if (lua_type(L,-1) == LUA_TBOOLEAN) {
            int b = lua_toboolean(L,-1);
            toy_setenv(key,b ? "true" : "false" );
        } else {
            const char * value = lua_tostring(L,-1);
            if (value == NULL) {
                fprintf(stderr, "Invalid config table key = %s\n", key);
                exit(1);
            }
            toy_setenv(key,value);
        }
        lua_pop(L,1);
    }
    lua_pop(L,1);
}

int
main(int argc, char* argv[]) {
    const char * config_file = NULL ;
    if (argc > 1) {
        config_file = argv[1];
    } else {
        fprintf(stderr, "Need a config file.\n");
        return 1;
    }
    sigign();
    toy_env_init();
    
    struct lua_State *L = luaL_newstate();
    luaL_openlibs(L);   // link lua lib
    
    int err =  luaL_loadbufferx(L, load_config, strlen(load_config), "=[toy-engine config]", "t");
    assert(err == LUA_OK);
    lua_pushstring(L, config_file);

    err = lua_pcall(L, 1, 1, 0);
    if (err) {
        fprintf(stderr,"%s\n",lua_tostring(L,-1));
        lua_close(L);
        return 1;
    }
    _init_env(L);
    lua_close(L);

    toy_mq_init();
    toy_timer_init();
    toy_socket_init();
    if (toy_server_init()) {
        exit(1);
        return 1;
    }
    
    pthread_t pid[3];
    create_thread(&pid[0], thread_socket, NULL);
    create_thread(&pid[1], thread_worker, NULL);
    create_thread(&pid[2], thread_timer, NULL);
    int i;
    for (i=0;i<3;i++) {
        pthread_join(pid[i], NULL); 
    }
    fprintf(stderr,"process exit!\n");
    return 0;
}