#!/usr/bin/env python3
"""Fail closed on actual mip requests, copies, barriers and GPU readback evidence."""
import argparse
import hashlib
import json
import re
from pathlib import Path

LIMIT = 4194304
CASES = {'rgba8-mip-surrogate': (1024,1024,1,11,1), 'vigil-astc': (2048,2048,1,12,2), 'vigil-astc-padded': (2048,2048,1,12,1),
         'astc4-odd-padded': (53,31,1,6,2), 'rgba8-depth-padded': (23,17,3,5,1),
         'single-exact-cap': (2048,2048,1,1,1), 'atomic-reject': (4096,2048,1,13,1)}


def require(yes, message):
    if not yes:
        raise ValueError(message)


def step(n, alignment):
    return (n + alignment - 1) // alignment * alignment


def fields(text):
    result = {}
    for pair in text.split():
        key, value = pair.split('=', 1)
        require(key not in result, 'duplicate native event field')
        result[key] = value if key in ('case', 'phase') else int(value)
    return result


def layout(start, variant):
    w,h,d = start['width'],start['height'],start['depth']
    bw,bh = start['block_w'],start['block_h']
    unit = start['block_bytes'] if (bw,bh) != (1,1) else start['pixel_size']
    source, size, batch, first_mip = 0,0,0,0
    copies, requests = [],[]
    for mip in range(start['mips']):
        pw,ph = step(w,bw),step(h,bh)
        tight_row = pw // bw * unit
        pitch = step(tight_row,start['pitch_step'])
        slice_bytes = pitch * (ph // bh)
        aligned_slice = step(slice_bytes,start['align'])
        mip_bytes = (d-1)*aligned_slice + slice_bytes
        begin = step(size,start['align'])
        if variant == 'candidate' and begin + mip_bytes > LIMIT:
            requests.append({'batch':batch,'bytes':size,'first_mip':first_mip,'mip_count':mip-first_mip})
            batch += 1;size=0;begin=0;first_mip=mip
        require(variant != 'candidate' or mip_bytes <= LIMIT,'candidate atomic mip cannot fit')
        for z in range(d):
            copies.append({'batch':batch,'mip':mip,'z':z,'local':begin+z*aligned_slice,'pitch':pitch,
                           'width':w,'height':h,'padded_w':pw,'padded_h':ph,'source':source})
            source += tight_row*(ph//bh)
        size = begin+mip_bytes
        w,h,d = max(1,w>>1),max(1,h>>1),max(1,d>>1)
    requests.append({'batch':batch,'bytes':size,'first_mip':first_mip,'mip_count':start['mips']-first_mip})
    return source, requests, copies


def inspect(text, variant, metal=False):
    require('SCRIPT ERROR' not in text and 'Parse Error' not in text,'script diagnostics invalidate evidence')
    starts,requests,copies,barriers,waits,readbacks,rejected,caps,traits = {},{},{},{},{},{},{},{},{}
    for line in text.splitlines():
        if line.startswith(('GV_MIP_READBACK ','GV_MIP_REJECT ','GV_MIP_CAPABILITY ')):
            marker,raw = line.split(' ',1);item=json.loads(raw)
            if marker == 'GV_MIP_CAPABILITY':
                require(item['case'] not in caps,'duplicate physical format capability')
                caps[item['case']]=item;continue
            if marker == 'GV_MIP_REJECT':
                require(item['case'] not in rejected,'duplicate rejection')
                rejected[item['case']]=item;continue
            key=item['case'],item['layer'];require(key not in readbacks,'duplicate GPU readback');readbacks[key]=item
        elif metal and line.startswith('GV_MIP_METAL_TRAITS '):
            item=fields(line.split(' ',1)[1]);key=item['case'],item['layer']
            require(key not in traits,'duplicate native Metal traits');traits[key]=item
        elif line.startswith(('GV_MIP_START ','GV_MIP_REQUEST ','GV_MIP_COPY ','GV_MIP_BARRIER ','GV_MIP_WAIT ')):
            marker,raw=line.split(' ',1);item=fields(raw);key=item['case'],item['layer']
            if marker=='GV_MIP_START':
                require(key not in starts,'duplicate initializer');starts[key]=item
            else:
                target={'GV_MIP_REQUEST':requests,'GV_MIP_COPY':copies,'GV_MIP_BARRIER':barriers,'GV_MIP_WAIT':waits}[marker]
                target.setdefault(key,[]).append(item)
        elif metal and line.startswith('GV_MIP_') and not line.startswith('GV_MIP_DONE '):
            raise ValueError('unknown native Metal event')
    require(set(caps)==set(CASES),'physical format capability report incomplete')
    for name,cap in caps.items():
        require(type(cap['supported']) is bool and cap['usage']>0,'physical format support/usage missing')
        require(not metal or cap['usage']==193,'Metal capability usage differs')
        require(tuple(cap[k] for k in ('width','height','depth','mips'))==CASES[name][:4],'capability case shape differs')
        wanted_format='RGBA8' if name.startswith('rgba8') else 'ASTC_4x4'
        require(cap['format_id']==(36 if wanted_format=='RGBA8' else 156),'physical DataFormat differs from pinned enum')
        require(cap['format']==wanted_format and cap['validated_upload_format']==(wanted_format if cap['supported'] else 'UNSUPPORTED'),'format fallback or unreported physical format')
    require(caps['rgba8-mip-surrogate']['supported'] and caps['rgba8-depth-padded']['supported'],'required supported-RD control unavailable')
    expected={(name,layer) for name,shape in CASES.items() if caps[name]['supported'] for layer in range(shape[-1])}
    reject_expected=variant=='candidate' and caps['atomic-reject']['supported']
    success=expected-({('atomic-reject',0)} if reject_expected else set())
    require(set(starts)==success if variant=='candidate' else set(starts)==expected,'missing or unexpected native initializer')
    for key,start in starts.items():
        require(tuple(start[name] for name in ('width','height','depth','mips'))==CASES[key[0]][:4],'wrong initializer shape')
        require(start['align']>0 and start['pitch_step']>0 and start['block_bytes']>0,'invalid actual backend traits')
        require(start['payload']==layout(start,'baseline')[0],'initializer full-chain bytes differ')
        expected_format=(36,1,1,4,0) if key[0].startswith('rgba8') else (156,4,4,1,0)
        require(tuple(start[k] for k in ('format','block_w','block_h','pixel_size','rshift'))==expected_format,'native format/block layout differs from pinned source')
    require(set(requests)==set(copies)==set(readbacks)==success,'missing or unexpected request/copy/readback')
    if metal:
        require(set(traits)==success,'missing or unexpected native Metal traits')
        require(not barriers,'default hazard-tracked Metal must have exactly zero explicit barriers')
    else:
        require(set(barriers)==success,'missing or unexpected native barriers')
    require(set(waits)<=success,'unexpected wait or partial rejected upload')
    require([line for line in text.splitlines() if line.startswith('GV_MIP_DONE ')] ==
            ['GV_MIP_DONE '+str(len(success))], 'complete native probe marker absent or duplicated')
    if reject_expected:
        require(set(rejected)=={'atomic-reject'} and rejected['atomic-reject']['valid'] is False,'atomic mip must reject at real texture_create')
        require(rejected['atomic-reject']['bytes']==11184848,'wrong rejected payload')
    else:
        require(not rejected,'baseline must create the deliberately oversized control')
    result={}
    for key in sorted(success):
        start=starts[key];shape=CASES[key[0]]
        require(tuple(start[name] for name in ('width','height','depth','mips'))==shape[:4],'wrong case dimensions/depth/mips')
        require(start['align']>0 and start['pitch_step']>0,'missing actual backend traits')
        require(start['forced']==int(key[0].endswith('-padded')),'wrong forced-profile marker')
        if metal:
            require(traits[key]=={'case':key[0],'layer':key[1],'native_pitch_step':1,
                    'native_transfer_align':1,'honors_barriers':0},'native Metal traits differ from pinned default')
            require(start['block_bytes']==(1 if key[0].startswith('rgba8') else 16),
                    'native Metal block bytes differ from pinned format')
            unit=start['block_bytes'] if start['block_w']!=1 else start['pixel_size']
            require(start['pitch_step']==1 and start['align']==(512 if start['forced'] else unit),
                    'Metal must use natural rows and recorded offset stress')
        elif start['forced']:
            require(start['align']>=512 and start['pitch_step']>=256,'nonunit profile inactive')
        payload,wanted_requests,wanted_copies=layout(start,variant)
        require(start['payload']==payload,'complete raw mip/depth payload differs')
        actual_requests=[{name:event[name] for name in wanted_requests[0]} for event in requests[key]]
        require(actual_requests==wanted_requests,'actual request boundaries/bytes differ')
        if variant=='candidate':
            require(all(0<event['bytes']<=LIMIT for event in requests[key]),'actual candidate request exceeds cap')
        require(len(copies[key])==len(wanted_copies),'mip/depth copy omitted or duplicated')
        worker_offsets={}
        for actual,wanted in zip(copies[key],wanted_copies):
            require(all(actual[name]==value for name,value in wanted.items()),'actual copy span/pitch/source differs')
            require(actual['offset']>=actual['local'] and actual['offset']%start['align']==0,'worker offset misaligned')
            worker_offset=actual['offset']-actual['local']
            require(worker_offsets.setdefault(actual['batch'],worker_offset)==worker_offset,'worker offset changed within one request')
        for phase in (() if metal else ('begin','end')):
            phase_events=[event for event in barriers[key] if event['phase']==phase]
            wanted=[{k:event[k] for k in ('batch','first_mip','mip_count')} for event in wanted_requests]
            require([{k:event[k] for k in ('batch','first_mip','mip_count')} for event in phase_events]==wanted,'mip barrier coverage differs')
        require(metal or len(barriers[key])==2*len(wanted_requests),'unexpected barrier phase')
        require([event['batch'] for event in waits.get(key,[])]==list(range(len(wanted_requests)-1)),'earlier batches not completed before final dependency')
        readback=readbacks[key]
        require(readback['equal'] is True and readback['source_sha256']==readback['actual_sha256'],'actual GPU bytes differ')
        require(len(readback['source_sha256'])==64,'missing GPU source identity')
        pattern=bytes((i*37+key[1]*17)%251 for i in range(251))
        source=(pattern*((payload+250)//251))[:payload]
        require(readback['source_sha256']==hashlib.sha256(source).hexdigest(),'actual source bytes differ from the fixed probe')
        require(readback['source_bytes']==readback['actual_bytes']==payload,'GPU byte count differs')
        require(all(readback[name]==start[name] for name in ('width','height','depth','mips')),'GPU resource shape differs')
        require(readback['format_id']==start['format']==caps[key[0]]['format_id'],'GPU format differs from physical capability/upload')
        require(readback['created_format']==start['format'] and readback['created_mipmaps']==start['mips'],'created GPU format/mip chain differs')
        require(readback['format']==('RGBA8' if key[0].startswith('rgba8') else 'ASTC_4x4'),'wrong compressed/control format')
        result[key[0]+':'+str(key[1])]={'payload':payload,'requests':wanted_requests,'copies':len(wanted_copies),
             'source_sha256':readback['source_sha256'],'actual_sha256':readback['actual_sha256'],
             'pitch_step':start['pitch_step'],'alignment':start['align']}
    # Native reservations include the recorded backend's per-mip alignment;
    # raw payload totals are invariant, while reservation totals are not.
    for name,payload in (('vigil-astc:0',5592432),('rgba8-mip-surrogate:0',5592404)):
        if name not in result:
            continue
        case=result[name]
        require(case['payload']==payload,'complete-chain source payload differs')
        if variant=='baseline':
            require(len(case['requests'])==1 and case['requests'][0]['bytes']>LIMIT,'whole-chain baseline overage not observed')
        else:
            require(len(case['requests'])>=2 and case['requests'][0]['first_mip']==0 and
                    case['requests'][0]['mip_count']==1,'base mip not separated from complete tail')
    require(not waits.get(('atomic-reject',0)),'rejected mip performed partial work')
    report={'cases':result,'capabilities':caps}
    if metal:
        report.update(profile='macos-arm64-metal-v1',
            native_traits={name+':'+str(layer):value for (name,layer),value in traits.items()})
    return report


def inspect_metal(text, variant):
    require(variant in ('baseline','candidate'),'unknown Metal variant')
    diagnostics=re.findall(r'(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):[^\n]*',text)
    expected=['ERROR: One padded texture mip exceeds the bounded staging request.'] if variant=='candidate' and 'GV_MIP_REJECT ' in text else []
    require([line.strip() for line in diagnostics]==expected,'unexpected native Metal error or missing rejection error')
    return inspect(text,variant,metal=True)


def compare_metal(before, after):
    require(before.get('profile')==after.get('profile')=='macos-arm64-metal-v1','Metal profile missing')
    require({key:value for key,value in before['native_traits'].items() if key!='atomic-reject:0'}==
            after['native_traits'],'native Metal traits changed between variants')
    report=compare(before,after)
    report.update(profile='macos-arm64-metal-v1',
        scope='desktop Metal RD component only; no iOS/A12, shipping-template, timing or memory qualification',
        row_pitch_coverage='native tight rows and retained 512-byte offset stress; original CPU/Vulkan 256-byte row-pitch controls remain separate',
        explicit_barrier_events=0)
    return report


def compare(before,after):
    require(before['capabilities']==after['capabilities'],'actual physical format support changed between variants')
    old,new=before['cases'],after['cases']
    require(set(old)-{'atomic-reject:0'}==set(new),'variant case sets differ')
    for key,value in new.items():
        for field in ('payload','copies','source_sha256','actual_sha256','pitch_step','alignment'):
            require(value[field]==old[key][field],key+': variant '+field+' changed')
    return {'status':'PASS' if after['capabilities']['vigil-astc']['supported'] else 'INCONCLUSIVE_ASTC_UNSUPPORTED','supported_rd_readback':'PASS','scope':'actual RD component on recorded backend; not Metal/iOS or device acceptance',
            'baseline':before,'candidate':after}


def validate_build(manifest, contract, observer_sha, patch_sha):
    require(manifest['status']=='pass','hosted native compiler proof missing')
    require([flag for flag in manifest.get('flags', []) if flag.startswith('disable_path_overrides=')] ==
            ['disable_path_overrides=no'], 'runtime-test configuration must enable unambiguous path overrides')
    require(json.dumps(manifest.get('runtime_test_configuration'), sort_keys=True) ==
            json.dumps(contract['runtime_test_configuration'], sort_keys=True),
            'runtime-test configuration must distinguish component proof from shipping templates')
    require(manifest['source_sha']==contract['source_pins'][0] and manifest['source_archive_sha256']=='e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef','compiler source/archive identity differs')
    require(manifest['observer_sha256']==observer_sha,'compiler observer identity differs')
    require(manifest['patch_sha256']==patch_sha==contract['production_patch_sha256'],'compiler patch identity differs')
    require([p['sha256'] for p in manifest['prerequisite_patches']]==[contract['prerequisite_patch_sha256']],'allocator-only baseline prerequisite differs')
    baseline, candidate = (manifest['builds'][name] for name in ('baseline','candidate'))
    require(baseline['unmodified_source_tree_sha256']==candidate['unmodified_source_tree_sha256'],'variant unmodified source trees differ')
    before, after = baseline['applied_patches'], candidate['applied_patches']
    require(len(before)==1 and len(after)==2 and before==after[:1],'allocator prerequisite not identical in both variants')
    require(before[0]['role']=='prerequisite' and before[0]['sha256']==contract['prerequisite_patch_sha256'],'baseline is not allocator-only')
    require(after[1]['role']=='production' and after[1]['sha256']==patch_sha,'candidate production patch differs')
    for build in (baseline,candidate):
        require(build['pre_observer_source_tree_sha256']==build['applied_patches'][-1]['source_tree_sha256'],'unrecorded change before observer')
        for field in ('unmodified_source_tree_sha256','pre_observer_source_tree_sha256','instrumented_source_tree_sha256','binary_sha256'):
            require(len(build[field])==64,'missing compiler source/binary identity')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--build-manifest',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    import probe
    manifest=json.loads(args.build_manifest.read_text())
    contract=json.loads(Path(__file__).with_name('contract.json').read_text())
    require(hashlib.sha256(Path(__file__).parents[1].joinpath('native_boot_upload/build.py').read_bytes()).hexdigest()==
            contract['shared_builder_sha256'],'shared runtime-test builder differs')
    observer_sha=hashlib.sha256(Path(__file__).with_name('observer.py').read_bytes()).hexdigest()
    patch_sha=hashlib.sha256(Path(__file__).parents[1].joinpath('patches/glassvow-660-bounded-mip-upload.patch').read_bytes()).hexdigest()
    validate_build(manifest,contract,observer_sha,patch_sha)
    logs={}
    icd_sha=None
    for variant,directory in [('baseline',args.baseline),('candidate',args.candidate)]:
        instrument=json.loads((args.build_manifest.parent/(variant+'-instrument.log')).read_text())
        require(instrument['variant']==variant and instrument['observer_sha256']==observer_sha,'actual observer receipt differs')
        require(instrument['source_before_sha256']==contract['allocator_baseline_rd_sha256' if variant=='baseline' else 'candidate_rd_sha256'],'actual observed native source differs')
        require(len(instrument['source_after_sha256'])==64,'instrumented native source identity absent')
        inputs=json.loads((directory/'probe-input.json').read_text())
        require(inputs['variant']==variant and inputs['binary_sha256']==manifest['builds'][variant]['binary_sha256'],'actual probe binary does not match hosted compiler')
        require(inputs['script_sha256']==hashlib.sha256(probe.script_for(variant).encode()).hexdigest(),'actual probe script differs')
        require(inputs['global_class_cache_sha256']==hashlib.sha256(probe.GLOBAL_CLASS_CACHE.encode()).hexdigest(),'actual standalone global-class cache differs')
        require(len(inputs['icd_sha256'])==64 and (icd_sha is None or icd_sha==inputs['icd_sha256']),'actual Vulkan ICD identity differs')
        icd_sha=inputs['icd_sha256']
        text=(directory/'native.log').read_text(errors='replace')
        require('Vulkan' in text and 'llvmpipe' in text.lower(),'required actual software-Vulkan backend absent')
        errors=[line for line in text.splitlines() if line.startswith('ERROR:')]
        require((not errors) if variant=='baseline' else (((len(errors)==1 and 'One padded texture mip exceeds the bounded staging request.' in errors[0]) if 'GV_MIP_REJECT ' in text else not errors)),'unexpected native error or missing fail-closed control')
        logs[variant]=inspect(text,variant)
    report=compare(logs['baseline'],logs['candidate'])
    report['build_manifest_sha256']=hashlib.sha256(args.build_manifest.read_bytes()).hexdigest()
    report['icd_sha256']=icd_sha
    report['runtime_test_configuration']=manifest['runtime_test_configuration']
    report['shared_builder_sha256']=contract['shared_builder_sha256']
    args.output.write_text(json.dumps(report,indent=2)+'\n')
    print('Actual native mip request/readback evidence: '+report['status'])
    return 0 if report['status']=='PASS' else 2


if __name__=='__main__':
    raise SystemExit(main())
