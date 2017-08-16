CC = gcc
SHARED = -fPIC --shared
TOY_LIBS = -lpthread -lm -ldl -lrt
EXPORT = -Wl,-E
LUA_CLIB_PATH = ./luaclib
TOY_BUILD_PATH = .
CFLAGS = -g -O0 -Wall -I$(LUA_INC)

LUA_SRC_PATH = 3rd/lua53
LUA_STATICLIB = $(LUA_SRC_PATH)/src/liblua.a
LUA_LIB = $(LUA_STATICLIB)
LUA_INC = $(LUA_SRC_PATH)/src

LUA_CLIB = ltoy socketdriver netpack

TOY_SRC = toy_main.c toy_env.c toy_mq.c toy_timer.c toy_socket.c socket_server.c toy_server.c

all: \
	$(TOY_BUILD_PATH)/toy \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

$(LUA_STATICLIB) :
	cd $(LUA_SRC_PATH) && $(MAKE) CC='$(CC) -std=gnu99' linux

$(TOY_BUILD_PATH)/toy : $(foreach v, $(TOY_SRC), toy-src/$(v)) $(LUA_LIB)
	$(CC) $(CFLAGS) -o $@ $^ -Itoy-src $(EXPORT) $(TOY_LIBS)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/ltoy.so : lualib-src/lua-toy.c lualib-src/lua-seri.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Itoy-src -Ilualib-src

$(LUA_CLIB_PATH)/socketdriver.so : lualib-src/lua-socket.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Itoy-src

$(LUA_CLIB_PATH)/netpack.so : lualib-src/lua-netpack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -Itoy-src -o $@ 

clean:
	rm -f $(TOY_BUILD_PATH)/toy $(LUA_CLIB_PATH)/*.so

cleanall: clean
	cd $(LUA_SRC_PATH) && $(MAKE) clean