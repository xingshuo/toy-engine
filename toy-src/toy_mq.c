#include "toy.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "spinlock.h"
#include "toy_mq.h"
#include "toy_server.h"

static struct message_queue *Q = NULL;

void 
toy_mq_init() {
    struct message_queue *q = toy_malloc(sizeof(*q));
    memset(q,0,sizeof(*q));
    SPIN_INIT(q)
    q->cap = DEFAULT_QUEUE_SIZE;
    q->head = 0;
    q->tail = 0;
    q->queue = toy_malloc(sizeof(struct toy_message) * q->cap);
    Q=q;
}

struct message_queue*
toy_get_queue() {
    return Q;
}

void
toy_mq_push(struct toy_message *msg) {
    assert(msg);
    SPIN_LOCK(Q)
    Q->queue[Q->tail] = *msg;
    if (++Q->tail >= Q->cap) {
        Q->tail = 0;
    }
    if (Q->head == Q->tail) { //expand_queue
        struct toy_message *new_q = toy_malloc(sizeof(struct toy_message) * Q->cap * 2);
        int i;
        for (i=0;i<Q->cap;i++) {
            new_q[i] = Q->queue[(Q->head + i) % Q->cap];
        }
        Q->head = 0;
        Q->tail = Q->cap;
        Q->cap *= 2;
        toy_free(Q->queue);
        Q->queue = new_q;
    }
    SPIN_UNLOCK(Q)
}

int
toy_mq_pop(struct toy_message* msg) {
    SPIN_LOCK(Q)
    int suc = 1;
    if (Q->head != Q->tail) { //not empty
        *msg = Q->queue[Q->head++]; //it is safe way
        if (Q->head >= Q->cap) {
            Q->head = 0;
        }
    }else{
        suc = 0;
    }
    SPIN_UNLOCK(Q)
    return suc;
}

int
toy_mq_size() {
    int length = Q->tail - Q->head;
    if (length < 0) {
        length += Q->cap;
    }
    return length;
}

