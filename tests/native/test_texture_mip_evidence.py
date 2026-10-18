#!/usr/bin/env python3
"""Seed defects in synthetic evidence; these tests do not claim native execution."""
import hashlib
import importlib.util
import json
import copy
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('mip_verify',ROOT/'tools/godot/native_texture_mips/verify.py')
verify=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


def event(marker,item):
    return marker+' '+' '.join(f'{k}={v}' for k,v in item.items())


def synthetic(variant, astc_supported=True):
    lines=[];count=0
    for name,(w,h,d,mips,layers) in verify.CASES.items():
        rgba=name.startswith('rgba8');padded=name.endswith('-padded')
        supported=rgba or astc_supported
        lines.append('GV_MIP_CAPABILITY '+json.dumps({'case':name,'format':'RGBA8' if rgba else 'ASTC_4x4',
            'format_id':36 if rgba else 156,'supported':supported,'usage':49,'width':w,'height':h,'depth':d,'mips':mips,
            'validated_upload_format':('RGBA8' if rgba else 'ASTC_4x4') if supported else 'UNSUPPORTED'}))
        if not supported:
            continue
        for layer in range(layers):
            start={'case':name,'layer':layer,'format':36 if rgba else 156,'width':w,'height':h,'depth':d,'mips':mips,
                'pitch_step':256 if padded else 1,'align':512 if padded else (4 if rgba else 16),
                'block_w':1 if rgba else 4,'block_h':1 if rgba else 4,'block_bytes':1 if rgba else 16,
                'pixel_size':4 if rgba else 1,'rshift':0,'forced':int(padded)}
            payload=verify.layout(start,'baseline')[0];start['payload']=payload
            if name=='atomic-reject' and variant=='candidate':
                lines.append('GV_MIP_REJECT '+json.dumps({'case':name,'valid':False,'bytes':payload}));continue
            lines.append(event('GV_MIP_START',start))
            _,requests,copies=verify.layout(start,variant)
            for request in requests:
                lines.append(event('GV_MIP_REQUEST',{'case':name,'layer':layer,**request}))
                for phase in ('begin','end'):
                    lines.append(event('GV_MIP_BARRIER',{'case':name,'layer':layer,'batch':request['batch'],'phase':phase,
                        'first_mip':request['first_mip'],'mip_count':request['mip_count']}))
            for item in copies:
                lines.append(event('GV_MIP_COPY',{'case':name,'layer':layer,**item,'offset':item['local']+2*start['align']}))
            for batch in range(len(requests)-1):
                lines.append(event('GV_MIP_WAIT',{'case':name,'layer':layer,'batch':batch}))
            pattern=bytes((i*37+layer*17)%251 for i in range(251))
            digest=hashlib.sha256((pattern*((payload+250)//251))[:payload]).hexdigest()
            lines.append('GV_MIP_READBACK '+json.dumps({'case':name,'layer':layer,'format':'RGBA8' if rgba else 'ASTC_4x4',
                'format_id':start['format'],'created_format':start['format'],'created_mipmaps':mips,'width':w,'height':h,'depth':d,'mips':mips,'source_bytes':payload,
                'actual_bytes':payload,'source_sha256':digest,'actual_sha256':digest,'equal':True}))
            count+=1
    return lines+[f'GV_MIP_DONE {count}']


class EvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before=synthetic('baseline');cls.after=synthetic('candidate')

    def rejects(self,lines):
        with self.assertRaises(ValueError):
            verify.inspect('\n'.join(lines),'candidate')

    def test_valid_synthetic_schema_and_fixed_vigil_bound(self):
        before=verify.inspect('\n'.join(self.before),'baseline')
        after=verify.inspect('\n'.join(self.after),'candidate')
        self.assertEqual([r['bytes'] for r in after['cases']['vigil-astc:0']['requests']],[4194304,1398128])
        self.assertEqual(verify.compare(before,after)['status'],'PASS')

    def test_unsupported_astc_keeps_supported_rd_proof_separate(self):
        before=verify.inspect('\n'.join(synthetic('baseline',False)),'baseline')
        after=verify.inspect('\n'.join(synthetic('candidate',False)),'candidate')
        report=verify.compare(before,after)
        self.assertEqual(report['supported_rd_readback'],'PASS')
        self.assertEqual(report['status'],'INCONCLUSIVE_ASTC_UNSUPPORTED')
        self.assertNotIn('vigil-astc:0',report['candidate']['cases'])

    def test_missing_or_duplicate_required_events(self):
        for marker in ('START','REQUEST','COPY','BARRIER','READBACK','WAIT','REJECT','CAPABILITY','DONE'):
            index=next(i for i,line in enumerate(self.after) if line.startswith('GV_MIP_'+marker+' '))
            with self.subTest(marker=marker,mode='missing'):
                lines=list(self.after);lines.pop(index);self.rejects(lines)
            with self.subTest(marker=marker,mode='duplicate'):
                lines=list(self.after);lines.insert(index,lines[index]);self.rejects(lines)

    def test_wrong_native_request_copy_and_barrier_fields(self):
        defects=[('REQUEST','bytes=4194304','bytes=4194305'),('REQUEST','mip_count=1','mip_count=2'),
                 ('COPY','source=0','source=1'),('COPY','pitch=8192','pitch=8193'),
                 ('COPY','mip=0','mip=1'),('COPY','layer=0','layer=7'),
                 ('BARRIER','phase=begin','phase=unknown'),('START','mips=12','mips=11')]
        for marker,old,new in defects:
            with self.subTest(marker=marker,field=old):
                lines=list(self.after);index=next(i for i,line in enumerate(lines) if line.startswith('GV_MIP_'+marker+' ') and old in line)
                lines[index]=lines[index].replace(old,new,1);self.rejects(lines)

    def test_forged_gpu_payload_digest_count_format_and_equality(self):
        for field,value in [('equal',False),('actual_sha256','0'*64),('source_sha256','0'*64),
                            ('actual_bytes',1),('format_id',999),('created_format',999),('created_mipmaps',999),('mips',999)]:
            with self.subTest(field=field):
                lines=list(self.after);index=next(i for i,line in enumerate(lines) if line.startswith('GV_MIP_READBACK '))
                data=json.loads(lines[index].split(' ',1)[1]);data[field]=value
                lines[index]='GV_MIP_READBACK '+json.dumps(data);self.rejects(lines)

    def test_partial_atomic_rejection_cannot_pass(self):
        lines=list(self.after);lines.append('GV_MIP_WAIT case=atomic-reject layer=0 batch=0');self.rejects(lines)
        for field,value in [('valid',True),('bytes',0)]:
            lines=list(self.after);index=next(i for i,line in enumerate(lines) if line.startswith('GV_MIP_REJECT '))
            data=json.loads(lines[index].split(' ',1)[1]);data[field]=value
            lines[index]='GV_MIP_REJECT '+json.dumps(data);self.rejects(lines)

    def test_silent_format_fallback_cannot_pass(self):
        lines=list(self.after);index=next(i for i,line in enumerate(lines) if line.startswith('GV_MIP_CAPABILITY ') and 'vigil-astc' in line)
        data=json.loads(lines[index].split(' ',1)[1]);data['validated_upload_format']='RGBA8'
        lines[index]='GV_MIP_CAPABILITY '+json.dumps(data);self.rejects(lines)

    def test_compiler_requires_identical_allocator_only_baseline(self):
        contract=json.loads((ROOT/'tools/godot/native_texture_mips/contract.json').read_text())
        dependency={'role':'prerequisite','path':'dependency.patch','sha256':contract['prerequisite_patch_sha256'],'source_tree_sha256':'a'*64}
        production={'role':'production','path':'production.patch','sha256':contract['production_patch_sha256'],'source_tree_sha256':'b'*64}
        common={'unmodified_source_tree_sha256':'0'*64,'instrumented_source_tree_sha256':'c'*64,'binary_sha256':'d'*64}
        manifest={'status':'pass','source_sha':contract['source_pins'][0],
            'flags':['disable_path_overrides=no'],'runtime_test_configuration':contract['runtime_test_configuration'],
            'source_archive_sha256':'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef',
            'observer_sha256':'e'*64,'patch_sha256':contract['production_patch_sha256'],
            'prerequisite_patches':[{'sha256':dependency['sha256']}],
            'builds':{'baseline':{**common,'applied_patches':[dependency],'pre_observer_source_tree_sha256':'a'*64},
                'candidate':{**common,'applied_patches':[dependency,production],'pre_observer_source_tree_sha256':'b'*64}}}
        verify.validate_build(manifest,contract,'e'*64,production['sha256'])
        for defect in ('missing-prerequisite','changed-prerequisite','wrong-production','unrecorded-source','different-archive-tree'):
            with self.subTest(defect=defect):
                changed=copy.deepcopy(manifest)
                candidate=changed['builds']['candidate']
                if defect=='missing-prerequisite':
                    candidate['applied_patches'].pop(0)
                elif defect=='changed-prerequisite':
                    candidate['applied_patches'][0]['sha256']='f'*64
                elif defect=='wrong-production':
                    candidate['applied_patches'][1]['sha256']='f'*64
                elif defect=='unrecorded-source':
                    candidate['pre_observer_source_tree_sha256']='f'*64
                else:
                    candidate['unmodified_source_tree_sha256']='f'*64
                with self.assertRaises(ValueError):
                    verify.validate_build(changed,contract,'e'*64,production['sha256'])


if __name__=='__main__':
    unittest.main()
