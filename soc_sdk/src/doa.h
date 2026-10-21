#ifndef DOA_H
#define DOA_H
#include <stdint.h>
#define AUDIO_FRAMES 2048
#define AUDIO_WORDS (AUDIO_FRAMES*8)
#define AUDIO_FS 48828.125f
typedef struct {float az,el,coherence,margin,rms,tonality; int valid;} DoaResult;
void doa_init(void);
int doa_process(const int32_t *records, float noise_rms, DoaResult *out);
#endif
