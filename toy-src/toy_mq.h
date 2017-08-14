#ifndef TOY_MESSAGE_QUEUE_H
#define TOY_MESSAGE_QUEUE_H
#include "spinlock.h"
// type is encoding in toy_message.sz high 8bit
#define MESSAGE_TYPE_MASK (SIZE_MAX >> 8)
#define MESSAGE_TYPE_SHIFT ((sizeof(size_t)-1) * 8)
#define DEFAULT_QUEUE_SIZE 64

struct toy_message {
    void* data;
    size_t sz;
};

struct message_queue {
    int cap;
    int head;
    int tail;
    struct toy_message *queue;
    struct spinlock lock;
};

void toy_mq_init();
void toy_mq_push(struct toy_message*);
int toy_mq_pop(struct toy_message*);
struct message_queue* toy_get_queue();
int toy_mq_size();

#endif