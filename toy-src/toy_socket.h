#ifndef TOY_SOCKET_H
#define TOY_SOCKET_H

#define TOY_SOCKET_TYPE_DATA 1
#define TOY_SOCKET_TYPE_CONNECT 2
#define TOY_SOCKET_TYPE_CLOSE 3
#define TOY_SOCKET_TYPE_ACCEPT 4
#define TOY_SOCKET_TYPE_ERROR 5

struct toy_socket_message {
    int type;
    int id;
    int ud;
    char * buffer;
};

void toy_socket_init();
int toy_socket_poll();
int toy_socket_listen(uint32_t, const char *, int, int);
void toy_socket_start(uint32_t, int);
void toy_socket_close(uint32_t, int);
void toy_socket_shutdown(uint32_t, int);
void toy_socket_nodelay(int);
int toy_socket_send(int, void*, int);
int toy_socket_send_lowpriority(int,void*,int);
int toy_socket_connect(uint32_t, const char *, int);
void toy_socket_exit();
#endif