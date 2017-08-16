#ifndef TOY_TIMER_H
#define TOY_TIMER_H

#include <stdint.h>

int toy_timeout(int time, uint32_t session);
void toy_updatetime(void);
uint32_t toy_starttime(void);
uint64_t toy_thread_time(void);	// for profile, in micro second
void toy_timer_init(void);

#endif
