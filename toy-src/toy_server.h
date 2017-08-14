#ifndef TOY_H
#define TOY_H
#include "toy.h"

int toy_server_init();
int toy_server_bootstrap();
int toy_server_dispatch_msg(int);
struct toy_context* toy_server_get_context();

#endif