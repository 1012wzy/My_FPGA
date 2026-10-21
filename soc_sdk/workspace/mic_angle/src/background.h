#ifndef BACKGROUND_H
#define BACKGROUND_H
#define BACKGROUND_BLOCKS 24u
typedef struct {float level[BACKGROUND_BLOCKS],noise_rms;unsigned count,ready;} Background;
void background_init(Background *b);
int background_add(Background *b,float rms);
#endif
