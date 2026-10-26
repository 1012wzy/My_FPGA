"""Deterministic host comparison; production car sources are never edited."""
from pathlib import Path
import argparse, csv, hashlib, json, re, shutil, subprocess, tempfile

def run(root, output, gcc):
    source=root/'soc_sdk/src'
    harness=root/'soc_sdk/tests/compare_car_gap.c'
    output.mkdir(parents=True,exist_ok=True)
    result={'test_type':'deterministic_host_parameter_ablation','sample_period_ms':20,
            'observation_interval_ms':900,'duration_ms':10800,'bearing_deg':30,
            'source_age_ms':60,'pl_implementation_shared':True,'cases':[],
            'production_inputs':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in [source/'car.c',source/'car.h',harness]},
            'shared_utilization_report_sha256':hashlib.sha256((root/'soc_prj/reports/soc/utilization.rpt').read_bytes()).hexdigest()}
    current=(source/'car.h').read_text(encoding='utf-8-sig')
    if not re.search(r'^#define CAR_LOSS_MS 1200u$',current,re.M):
        raise RuntimeError('This comparison expects the released 1200 ms configuration')
    with tempfile.TemporaryDirectory(prefix='car_gap_compare_',dir=output) as directory:
        work=Path(directory)
        for loss in [500,1200]:
            variant=work/str(loss);variant.mkdir()
            shutil.copy2(source/'car.c',variant/'car.c')
            header=re.sub(r'^#define CAR_LOSS_MS 1200u$',f'#define CAR_LOSS_MS {loss}u',current,flags=re.M)
            (variant/'car.h').write_text(header,encoding='utf-8')
            exe=variant/'compare.exe'
            subprocess.run([gcc,'-O2','-Wall','-Wextra','-Werror','-I',str(variant),str(harness),str(variant/'car.c'),'-lm','-o',str(exe)],check=True,capture_output=True)
            trace=output/f'gap_{loss}.csv'
            status=subprocess.run([str(exe),str(trace)],check=True,capture_output=True,text=True).stdout.strip()
            if 'BOUNDARY_CHECKS_OK' not in status:raise RuntimeError('Missing comparison checks')
            with trace.open(newline='') as f: rows=list(csv.DictReader(f))
            states=[int(v['actual_run']) for v in rows]
            mismatch=sum(v['reference_run']!=v['actual_run'] for v in rows)
            stops=sum(a==1 and b==0 for a,b in zip(states,states[1:]))
            starts=sum(a==0 and b==1 for a,b in zip([0]+states[:-1],states))
            result['cases'].append({'loss_ms':loss,'samples':len(rows),
                'authorized_samples':sum(states),'authorized_fraction':sum(states)/len(states),
                'stop_transitions':stops,'start_transitions':starts,'reference_mismatches':mismatch,
                'car_state_bytes':int(re.search(r'car_state_bytes=(\d+)',status).group(1)),
                'timeout_boundary_pass':True,'stale_500ms_rejected':True,
                'trace':trace.name,'trace_sha256':hashlib.sha256(trace.read_bytes()).hexdigest()})
            print(status)
    (output/'comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    with (output/'comparison.csv').open('w',newline='',encoding='utf-8') as f:
        fields=['loss_ms','samples','authorized_samples','authorized_fraction','stop_transitions','start_transitions','reference_mismatches','car_state_bytes']
        writer=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');writer.writeheader();writer.writerows(result['cases'])
    print('CAR_GAP_COMPARISON_OK: host results only; no wheel-speed or acoustic-accuracy claim')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output',type=Path)
    parser.add_argument('--gcc',default=r'D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe')
    args=parser.parse_args()
    run(args.root,args.output or args.root/'report/evidence/car_gap',args.gcc)
