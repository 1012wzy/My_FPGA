"""Run with Vitis 2025.2: vitis.bat -s scripts/build_vitis.py."""
import vitis, pathlib, hashlib, zipfile, json, struct
root=pathlib.Path(__file__).resolve().parents[1]
for name,digest in json.loads((root/'soc_hw/hardware_sources.json').read_text()).items():
 if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise RuntimeError('Hardware/source mismatch: '+name+'; rebuild Vivado first')
workspace=root/'soc_sdk/workspace' 
xsa=root/'soc_hw/system_wrapper.xsa'
digest=hashlib.sha256(xsa.read_bytes()).hexdigest()
stamp=workspace/'hardware.sha256'
client=vitis.create_client()
try:
 client.set_workspace(str(workspace))
 if (workspace/'mic_platform').exists():
  platform=client.get_component(name='mic_platform')
  if not stamp.exists() or stamp.read_text().strip()!=digest:
   platform.update_hw(hw_design=str(xsa))
 else:
  platform=client.create_platform_component(name='mic_platform',hw_design=str(xsa),os='standalone',cpu='ps7_cortexa9_0',domain_name='standalone_a9',generate_dtb=False)
 # 2025.2 CLI protobuf SUCCESS=0; failure need not raise an exception.
 if platform.build()!=0: raise RuntimeError('Platform build failed')
 stamp.write_text(digest)
 xpfm=str(workspace/'mic_platform/export/mic_platform/mic_platform.xpfm')
 if (workspace/'mic_angle').exists():app=client.get_component(name='mic_angle')
 else:app=client.create_app_component(name='mic_angle',platform=xpfm,domain='standalone_a9',template='empty_application')
 # Retire the DDR-video source copies before rebuilding the BRAM edition.
 for name in ('video_dma.c','video_dma.h'):
  obsolete=workspace/'mic_angle/src'/name
  if obsolete.exists():obsolete.unlink()
 app.import_files(from_loc=str(root/'soc_sdk/src'),files=['main.c','car.c','car.h','background.c','background.h','doa.c','doa.h','servo.c','servo.h','servo_startup.c','servo_startup.h','camera.c','camera.h','camera_regs.h','sound_marker.c','sound_marker.h','sound_marker_config.h'],dest_dir_in_cmp='src')
 app.set_app_config(key='USER_COMPILE_SOURCES',values=['main.c','car.c','background.c','doa.c','servo.c','servo_startup.c','camera.c','sound_marker.c'])
 app.set_app_config(key='USER_LINK_LIBRARIES',values=['m'])
 app.set_app_config(key='USER_COMPILE_OPTIMIZATION_LEVEL',values=['-O2'])
 if app.build()!=0: raise RuntimeError('Application build failed')
 elf=workspace/'mic_angle/build/mic_angle.elf'
 if not elf.is_file() or elf.stat().st_size<1000: raise RuntimeError('Missing application ELF')
 with zipfile.ZipFile(xsa) as z:
  bits=[n for n in z.namelist() if n.endswith('.bit')]
  if len(bits)!=1: raise RuntimeError('Expected one bitstream in XSA')
  (root/'soc_hw/mic_soc_top.bit').write_bytes(z.read(bits[0]))
  (root/'soc_hw/ps7_init.tcl').write_bytes(z.read('ps7_init.tcl'))
 # Export current ELF symbols for JTAG diagnostics, never hard-code old addresses.
 data=elf.read_bytes()
 if data[:6]!=b'\x7fELF\x01\x01':raise RuntimeError('Expected little-endian ELF32')
 offset=struct.unpack_from('<I',data,32)[0]
 entry_size,count=struct.unpack_from('<HH',data,46)
 headers=[struct.unpack_from('<10I',data,offset+i*entry_size) for i in range(count)]
 symbols={}
 for h in headers:
  if h[1]!=2:continue
  st=headers[h[6]];names=data[st[4]:st[4]+st[5]]
  for off in range(h[4],h[4]+h[5],h[9]):
   name,value=struct.unpack_from('<II',data,off)
   label=names[name:names.find(b'\0',name)].decode('ascii',errors='ignore')
   if label in ('g_camera','g_tracking','g_marker','g_marker_hold','g_car'):symbols[label]=value
 if len(symbols)!=5:raise RuntimeError('Diagnostic symbols missing')
 (root/'soc_hw/debug_symbols.tcl').write_text(''.join('set '+k+' 0x%08x\n'%v for k,v in symbols.items()))
 artifacts=['soc_hw/debug_symbols.tcl','soc_hw/system_wrapper.xsa' ,'soc_hw/mic_soc_top.bit','soc_hw/ps7_init.tcl','soc_sdk/workspace/mic_angle/build/mic_angle.elf']
 hashes={n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in artifacts}
 (root/'soc_hw/build_manifest.json').write_text(json.dumps(hashes,indent=2)+'\n')
 inputs=[p for p in (root/'soc_sdk/src').glob('*') if p.suffix in ('.c','.h')]+[elf]
 (root/'soc_hw/software_sources.json').write_text(json.dumps({p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},indent=2)+'\n')
 print('VITIS_BUILD_OK: platform, ELF and matching XSA/bit/init verified')
finally:
 vitis.dispose()
