#ifndef CAMERA_H
#define CAMERA_H
#include <stdint.h>
struct CameraTelemetry {int32_t result;uint32_t sensor_id,last_register,status,displayed_frames,marker_valid,marker_x,marker_y,input_frames,complete_frames,restarts,recovery_stage;int32_t recovery_error;uint32_t version;};
extern volatile struct CameraTelemetry g_camera;
int camera_init(void);
void camera_poll(void);
// Once per DOA result: signed degrees; bit29 reserved (no history window).
void camera_set_direction(unsigned valid,int az,int el);
void camera_maintain(uint32_t now);
void camera_set_marker(unsigned valid,unsigned x,unsigned y);
#endif
