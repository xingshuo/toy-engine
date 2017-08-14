#ifndef TOY_ENV_H
#define TOY_ENV_H

const char * toy_getenv(const char *key);
void toy_setenv(const char *key, const char *value);
void toy_env_init();

#endif