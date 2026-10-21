"""Build a QSPI-capable FSBL in a separate workspace; preserve CAR1 app/PL."""
from pathlib import Path
import vitis,hashlib,json,zipfile,re,runpy
root=Path(__file__).resolve().parents[1]
out=root/'boot_qspi'
ws=out/'workspace'
xsa=out/'boot_init.xsa'
runpy.run_path(str(root/'scripts/check_boot_init.py'),run_name='__main__')
client=vitis.create_client()
try:
 client.set_workspace(str(ws))
 if (ws/'qspi_platform').exists():
  p=client.get_component(name='qspi_platform');p.update_hw(hw_design=str(xsa))
 else:
  p=client.create_platform_component(name='qspi_platform',hw_design=str(xsa),os='standalone',cpu='ps7_cortexa9_0',domain_name='standalone_a9',generate_dtb=False)
 if p.build()!=0:raise RuntimeError('QSPI platform build failed')
 base=ws/'qspi_platform/zynq_fsbl'
 config=(base/'zynq_fsbl_bsp/include/xparameters.h').read_text()
 for token in ['XPAR_XQSPIPS_0_BASEADDR','XPAR_XQSPIPS_0_CONNECTION_MODE','XPAR_PS7_QSPI_LINEAR_0_BASEADDRESS']:
  if token not in config:raise RuntimeError('Missing boot capability: '+token)
 elf=ws/'qspi_platform/export/qspi_platform/sw/boot/fsbl.elf'
 if elf.read_bytes()!=(base/'build/fsbl.elf').read_bytes():raise RuntimeError('FSBL export mismatch')
 with zipfile.ZipFile(xsa) as z:
  for name in ['ps7_init.c','ps7_init.h']:
   if z.read(name)!=(base/name).read_bytes():raise RuntimeError('QSPI FSBL PS init mismatch')
  (out/'ps7_init_qspi.tcl').write_bytes(z.read('ps7_init.tcl'))
 (out/'fsbl.elf').write_bytes(elf.read_bytes())
 inputs=['soc_hw/system_wrapper.xsa','soc_prj/SXCX.srcs/sources_1/bd/system/system.bd','boot_qspi/boot_init.xsa','boot_qspi/fsbl.elf','boot_qspi/ps7_init_qspi.tcl']
 (out/'fsbl_receipt.json').write_text(json.dumps({n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in inputs},indent=2)+'\n')
 print('QSPI_FSBL_READY: includes QSPI driver and correct PS init')
finally:vitis.dispose()
