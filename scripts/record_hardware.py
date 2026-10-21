"""Record build inputs only after Vivado timing/DRC/pin checks succeed."""
from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1]
files=[]
for sub in ('soc_prj/SXCX.srcs/sources_1/new','soc_prj/SXCX.srcs/constrs_1/new'):
 files.extend(p for p in (r/sub).iterdir() if p.is_file())
files += [r/p for p in ('soc_prj/SXCX.srcs/sources_1/bd/system/system.bd','soc_prj/scripts/build_soc.tcl','soc_prj/scripts/configure_video_bram.tcl','soc_prj/scripts/check_car_pins.tcl','soc_hw/mic_soc_top.bit','soc_hw/system_wrapper.xsa')]
receipt={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(r/'soc_hw/hardware_sources.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('CAR1_HARDWARE_RECEIPT_OK')
