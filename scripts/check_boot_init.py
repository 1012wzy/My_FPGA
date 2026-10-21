"""Check that boot-only PS initialization adds QSPI without changing CAR1 clocks/DDR."""
from pathlib import Path
import zipfile,re,json,hashlib
root=Path(__file__).resolve().parents[1]
out=root/'boot_qspi'
def arrays(path):
 with zipfile.ZipFile(path) as z:src=z.read('ps7_init.c').decode()
 return {k:re.findall(r'EMIT_\w+\([^)]*\)',v) for k,v in re.findall(r'unsigned long (ps7_\w+)\[\]\s*=\s*\{(.*?)\};',src,re.S)}
a=arrays(root/'soc_hw/system_wrapper.xsa');b=arrays(out/'boot_init.xsa')
assert len(a)==21 and a.keys()==b.keys(),'Unexpected PS-init arrays'
qspi_mio={0xf8000700+4*i for i in [0,1,2,3,4,5,6,9,10,11,12,13]}
def filtered(ops):
 result=[]
 for op in ops:
  nums=[int(x,16) for x in re.findall(r'0[xX]([0-9a-fA-F]+)',op)]
  if op.startswith('EMIT_MASKWRITE') and nums[0] in qspi_mio|{0xf800014c}:continue
  if op.startswith('EMIT_MASKWRITE') and nums[0]==0xf800012c:
   nums[2]&=~0x00800000
   result.append(('APER',tuple(nums)))
  else:result.append(op)
 return result
for k in a:assert filtered(a[k])==filtered(b[k]),'Unexpected non-QSPI PS-init change: '+k
for ver in ['1_0','2_0','3_0']:
 text='\n'.join(b['ps7_mio_init_data_'+ver])
 for addr in qspi_mio:assert f'0X{addr:08X}' in text,'Missing QSPI MIO init'
 text='\n'.join(b['ps7_clock_init_data_'+ver])
 assert '0XF800014C' in text and '0x01DC000D' in text,'Missing QSPI clock'
print('BOOT_PS_COMPATIBILITY_OK: all three silicon revisions; only QSPI MIO, QSPI reference clock, QSPI APER clock enabled; DDR/PLL/FCLK/UART/PCAP unchanged.')
