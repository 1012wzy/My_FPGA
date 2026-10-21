
"""Read-only checks for the current release; historical ZIP archives are not required."""
from pathlib import Path
import hashlib,json,zipfile,re
root=Path(__file__).resolve().parents[1]
baselines=json.loads((root/'scripts/validation/release_baselines.json').read_text(encoding='utf-8'))
assert baselines['schema_version']==1
for n,h in baselines['files'].items():
 assert hashlib.sha256((root/n).read_bytes()).hexdigest()==h,'Protected source mismatch: '+n

def check_segment(name,text):
 assert hashlib.sha256(text.encode('utf-8')).hexdigest()==baselines['normalized_segments'][name],name

for n,h in json.loads((root/'soc_hw/build_manifest.json').read_text()).items():
 assert hashlib.sha256((root/n).read_bytes()).hexdigest()==h,n
with zipfile.ZipFile(root/'soc_hw/system_wrapper.xsa') as z:
 bits=[n for n in z.namelist() if n.endswith('.bit')]
 assert len(bits)==1 and z.read(bits[0])==(root/'soc_hw/mic_soc_top.bit').read_bytes()
 assert z.read('ps7_init.tcl')==(root/'soc_hw/ps7_init.tcl').read_bytes()
for p in (root/'soc_sdk/src').glob('*'):
 if p.suffix in ('.c','.h'):assert p.read_bytes()==(root/'soc_sdk/workspace/mic_angle/src'/p.name).read_bytes(),p.name
xdc=(root/'soc_prj/SXCX.srcs/constrs_1/new/camera_display.xdc').read_text()
pins=json.loads((root/'docs/reference/camera/pin_mapping.json').read_text())
for n,p in pins.items():assert 'set_property PACKAGE_PIN '+p+' [get_ports {'+n+'}]' in xdc,n
assert len(set(pins.values()))==len(pins)
# This package requires the current implementation reports; old bitstreams are not a fallback.
def log(name):
 b=(root/'soc_prj/reports'/name).read_bytes()
 return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
marks={'status_script_offline.log':'STATUS_SCRIPT_OFFLINE_OK','zip_camera_vitis_build.log':'VITIS_BUILD_OK:',
'zip_audio_regression.log':'ALL_REQUESTED_CHECKS_PASSED','zip_camera_host_test.log':'PASS:',
'response_host_test.log':'PASS:','presence_host_test.log':'PASS:','servo_startup_test.log':'PASS:','zip_servo_host_test.log':'PASS:','tb_camera_store.log':'PASS:','tb_sound_marker_cdc.log':'PASS:','tb_sound_overlay.log':'PASS:','tb_sound_direction_cdc.log':'PASS:','sound_marker_host_test.log':'PASS:','tb_dvi_encode.log':'PASS:','tb_camera_display.log':'PASS:'}
marks['zip_camera_build_console.log']='SOC_BUILD_OK'
for n,m in marks.items():
 t=log(n);assert m in t,n
 assert not re.search(r'(?m)^\s*(ERROR:|FATAL|Fatal:|ParserError)',t),n
assert 'CRITICAL WARNING:' not in log('zip_camera_build_console.log')
assert not re.search(r'CDC-\d+\s+Critical',log('soc/cdc.rpt'))
assert 'All user specified timing constraints are met.' in log('soc/timing.rpt')
assert 'tilt_actual_us<=1600' in (root/'soc_prj/SXCX.srcs/sources_1/new/servo_pwm.v').read_text()
assert 's->target[1]=s->actual[1]=1600' in (root/'soc_sdk/src/servo.c').read_text()
assert '800x450 triple-BRAM source; 1280x720 raster' in log('tb_camera_display.log')
assert '800x450 capture dimensions' in log('zip_camera_host_test.log')
print('ZIP_CAMERA_RELEASE_OK: original audio/DOA baseline, tests, pins, source copies, XSA/bit/init/ELF manifest, tilt=1600, 800x450 triple-BRAM capture / 720p display and sound marker')

assert 'video_dma' not in (root/'soc_prj/SXCX.srcs/sources_1/bd/system/system.bd').read_text()
assert 'HP1' not in (root/'soc_sdk/src/main.c').read_text()
assert '0x5001a3u' in (root/'soc_sdk/src/camera_regs.h').read_text()
assert '0x5001a3' in (root/'soc_sdk/src/camera.c').read_text()
assert 'ISP scaling enabled' in log('zip_camera_host_test.log')
print('BRAM_VIDEO_RELEASE_CHECK_OK')

receipt=json.loads((root/'soc_hw/software_sources.json').read_text())
for n,h in receipt.items():assert hashlib.sha256((root/n).read_bytes()).hexdigest()==h, 'Software input/output receipt mismatch: '+n
print('PS_SOURCE_RECEIPT_OK')

assert 'PASS:' in log('tb_servo_pwm.log')
assert 'rows=64 candidates=6 visible=0' in log('response_trace_replay.log')
assert 'stop settling <0.6deg in three updates' in log('sound_marker_host_test.log')
assert 'MAX_STEP_US=12' in (root/'soc_prj/SXCX.srcs/sources_1/new/servo_pwm.v').read_text()
assert '(after-before)*1000/(COUNTS_PER_SECOND)' in (root/'soc_sdk/src/main.c').read_text()
print('RESPONSE_RELEASE_OK: faster bounded PWM, speech continuation, fresh observation servo gate, motion/stop/noise tests, corrected timing calculation')

# Preserve the same projection and proportional actuator bodies used by the validated baselines.
current=(root/'soc_sdk/src/sound_marker.c').read_text()
check_segment('marker_projection',current[current.index('int marker_project'):current.index('static float bound')])
current=(root/'soc_sdk/src/servo.c').read_text().split('// Untrusted standalone')[0]
key=' s->last_valid_ms=now;s->hold=0;'
check_segment('proportional_actuation',current[current.index(key):].strip())
assert 'if(!confirmed && s->pending<(jump?3u:2u))' in current
current=(root/'soc_sdk/src/camera.c').read_text().replace('0x43415231u','0x534f5333u')
check_segment('camera_before_mode_signature',current)
current=(root/'soc_prj/SXCX.srcs/sources_1/new/servo_pwm.v').read_text()
current=current.replace('heartbeat,hold_position,pan_center,','heartbeat,hold_position,')
current=current.replace("pan_center?12'd1500:pan_us",'pan_us')
current=current.replace('(pan_center || !hold_position)','!hold_position')
check_segment('servo_pwm_without_pan_override',current)
print('SOS3_BASELINE_PRESERVED: camera, SOS, DOA, P servo; only independent pan-centre override added to servo PWM')
for n,h in json.loads((root/'soc_hw/hardware_sources.json').read_text()).items():
 assert hashlib.sha256((root/n).read_bytes()).hexdigest()==h,'Hardware receipt mismatch: '+n
for n in ('car_host_test.log','car_presence_test.log','tb_car_motor.log','tb_servo_car.log'):
 t=log(n);assert 'PASS:' in t and not re.search(r'Fatal:|FATAL|ERROR:|Assertion',t),n
assert 'CAR_PIN_CHECK_OK' in log('zip_camera_build_console.log')
car_xdc=(root/'soc_prj/SXCX.srcs/constrs_1/new/car_motor.xdc').read_text()
for n,p in {'motor_pwm_a':'Y28','motor_ain1':'AB27','motor_ain2':'AA27','motor_pwm_b':'Y26','motor_bin1':'Y30','motor_bin2':'AB29','motor_stby':'AA29','mode_key_n':'U29','mode_led':'W24','drive_led':'V23'}.items():
 assert 'set_property PACKAGE_PIN '+p+' [get_ports '+n+']' in car_xdc
print('CAR1_HARDWARE_AND_TESTS_OK')
assert '35 closed-loop scenarios' in log('zip_servo_host_test.log')
assert 'trajectory-authorized servo' in log('presence_host_test.log')
assert 'paired-outlier rejection' in log('sound_marker_host_test.log')
assert 'signed direction CDC' in log('tb_sound_direction_cdc.log')
assert 'SOS 204x84 glyph/size/transparency' in log('tb_sound_overlay.log')
assert 'removed history panel' in log('tb_sound_overlay.log')
assert 'interpolation' in log('tb_sound_marker_cdc.log')
main=(root/'soc_sdk/src/main.c').read_text()
assert 'servo_observe_confirmed(&servo,marker.accepted,r.az,r.el,observed_ms)' in main
assert main.index('if(servo_startup(')<main.index('background_init(&background)')<main.index('background_add(&background,r.rms)')
assert 'servo.tracking=0;servo.hold=1;write_control();background_init' in main
assert 'camera_set_direction(marker.locked,' in main
assert '0x43415231u' in (root/'soc_sdk/src/camera.c').read_text()
assert '#define BACKGROUND_BLOCKS 24u' in (root/'soc_sdk/src/background.h').read_text()
bd=json.loads((root/'soc_prj/SXCX.srcs/sources_1/bd/system/system.bd').read_text())
assert all(v in str(bd) for v in ('direction_gpio','0x41220000','car_gpio','0x41230000'))
assert 'moving_accepted=12/12 resume_after_one_dip=1' in log('response_host_test.log')
print('CAR1_RELEASE_OK: powered background calibration, trajectory-authorized non-PID servo, 204x84 SOS, no history table, vblank interpolation; new full hardware + matching rebuilt PS software')

# CAR rolling update: exercise actual PS leases through the unchanged motor RTL.
assert '1200ms loss stop and automatic recovery' in log('tb_car_lease.log')
assert '1199ms hold/1200ms stop' in log('car_host_test.log')
assert '#define CAR_LOSS_MS 1200u' in (root/'soc_sdk/src/car.h').read_text()
assert '#define CAR_DEADBAND_DEG 10.f' in (root/'soc_sdk/src/car.h').read_text()
assert '#define CAR_FULL_TURN_DEG 50.f' in (root/'soc_sdk/src/car.h').read_text()
print('CAR_ROLLING_RELEASE_OK: forward arcs, 10deg deadband/50deg saturation, 1200ms speech-loss timeout and real PS-to-PL command replay')

# User-selected My_FPGA18 baseline: application logic changes limited to two car files.
for name in baselines['excluded_sources']:
 assert not (root/name).exists(),'Inactive source unexpectedly restored: '+name
assert '#define CAR_SAMPLE_MAX_AGE_MS 500u' in (root/'soc_sdk/src/car.h').read_text()
assert '#define CAR_BASE_DUTY 64' in (root/'soc_sdk/src/car.h').read_text()
assert '#define CAR_TURN_DUTY 38' in (root/'soc_sdk/src/car.h').read_text()
assert 'repeated 900ms speech gaps remain driven' in log('car_host_test.log')
print('RESTORE18_RELEASE_OK: exact user ZIP baseline; only car.c/car.h application edits; gap1200ms, stale500ms, original64/38 speed and sound judgment')
