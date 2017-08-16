#include "toy.h"

#include "toy_mq.h"
#include "toy_socket.h"
#include "socket_server.h"

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

static struct socket_server * SOCKET_SERVER = NULL;

void 
toy_socket_init() {
    SOCKET_SERVER = socket_server_create();
}

static void
forward_message(int type, bool padding, struct socket_message * result) {
    struct toy_socket_message *sm;
    size_t sz = sizeof(*sm);
    if (padding) {
        if (result->data) {
            size_t msg_sz = strlen(result->data);
            if (msg_sz > 128) {
                msg_sz = 128;
            }
            sz += msg_sz;
        } else {
            result->data = "";
        }
    }
    sm = (struct toy_socket_message *)toy_malloc(sz);
    sm->type = type;
    sm->id = result->id;
    sm->ud = result->ud;
    if (padding) {
        sm->buffer = NULL;
        memcpy(sm+1, result->data, sz - sizeof(*sm));
    } else {
        sm->buffer = result->data;
    }

    struct toy_message message;
    message.data = sm;
    message.sz = sz | ((size_t)PTYPE_SOCKET << MESSAGE_TYPE_SHIFT);
    message.session = result->opaque;
    toy_mq_push(&message);
}

int
toy_socket_poll() {
    struct socket_server *ss = SOCKET_SERVER;
    assert(ss);
    struct socket_message result;
    int type = socket_server_poll(ss, &result, NULL);
    // DO NOT use any ctrl command (socket_server_close , etc. ) in this thread.
    switch (type) {
    case SOCKET_EXIT:
        return 0;
    case SOCKET_DATA:
        //printf("message(%lu) [id=%d] size=%d\n",result.opaque,result.id, result.ud);
        forward_message(TOY_SOCKET_TYPE_DATA, false, &result);
        //free(result.data);
        break;
    case SOCKET_CLOSE:
        printf("close(%lu) [id=%d]\n",result.opaque,result.id);
        forward_message(TOY_SOCKET_TYPE_CLOSE, false, &result);
        break;
    case SOCKET_OPEN:
        printf("open(%lu) [id=%d] %s\n",result.opaque,result.id,result.data);
        forward_message(TOY_SOCKET_TYPE_CONNECT, true, &result);
        break;
    case SOCKET_ERROR:
        printf("error(%lu) [id=%d]\n",result.opaque,result.id);
        forward_message(TOY_SOCKET_TYPE_ERROR, true, &result);
        break;
    case SOCKET_ACCEPT:
        printf("accept(%lu) [id=%d %s] from [%d]\n",result.opaque, result.ud, result.data, result.id);
        forward_message(TOY_SOCKET_TYPE_ACCEPT, true, &result);
        break;
    default:
        printf("unknow socket message type %d.\n", type);
        return -1;
    }
    return 1;
}

int 
toy_socket_listen(uint32_t opaque, const char *host, int port, int backlog) {
    return socket_server_listen(SOCKET_SERVER, opaque, host, port, backlog);
}

void 
toy_socket_start(uint32_t opaque, int id) {
    socket_server_start(SOCKET_SERVER, opaque, id);
}

void 
toy_socket_close(uint32_t opaque, int id) {
    socket_server_close(SOCKET_SERVER, opaque, id);
}

void
toy_socket_nodelay(int id) {
    socket_server_nodelay(SOCKET_SERVER, id);
}

int
toy_socket_send(int id, void *buffer, int sz) {
    return socket_server_send(SOCKET_SERVER, id, buffer, sz);
}

int
toy_socket_connect(uint32_t opaque, const char *host, int port) {
    return socket_server_connect(SOCKET_SERVER, opaque , host, port);
}

void
toy_socket_exit() {
    socket_server_exit(SOCKET_SERVER);
}