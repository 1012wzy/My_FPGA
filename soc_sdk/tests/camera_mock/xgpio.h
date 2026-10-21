
#ifndef MOCK_GPIO_H
#define MOCK_GPIO_H
#include <stdint.h>
typedef struct {int unused;} XGpio;
typedef struct {int unused;} XGpio_Config;
XGpio_Config *XGpio_LookupConfig(unsigned);
int XGpio_CfgInitialize(XGpio *,XGpio_Config *,unsigned);
void XGpio_SetDataDirection(XGpio *,unsigned,unsigned);
void XGpio_DiscreteWrite(XGpio *,unsigned,unsigned);
unsigned XGpio_DiscreteRead(XGpio *,unsigned);
#endif
