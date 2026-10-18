#!/usr/bin/env python3
"""Check both pinned source bytes and exact prerequisite/mip patch application."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(yes,message):
    if not yes:
        raise ValueError(message)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--shipping-source',type=Path,required=True)
    parser.add_argument('--prerequisite-patch',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    own=Path(__file__).resolve().parent
    contract=json.loads((own/'contract.json').read_text())
    patch=own.parent/'patches/glassvow-660-bounded-mip-upload.patch'
    tests=own.parents[2]/'tests/native'
    require(digest(tests/'texture_mip_batches.cpp.in')==contract['first_fixture_sha256'],'frozen first native fixture differs')
    require(digest(tests/'test_texture_mip_batches.py')==contract['first_runner_sha256'],'frozen first native runner differs')
    require(digest(patch)==contract['production_patch_sha256'],'production patch identity differs')
    require(digest(args.prerequisite_patch)==contract['prerequisite_patch_sha256'],'prerequisite patch identity differs')
    args.output.mkdir(parents=True,exist_ok=False)
    result={}
    for variant,path in [('stable',args.source),('shipping',args.shipping_source)]:
        require(digest(path)==contract['original_rd_sha256'],variant+': original pinned source differs')
        tree=args.output/variant
        target=tree/'servers/rendering/rendering_device.cpp'
        target.parent.mkdir(parents=True)
        target.write_bytes(path.read_bytes())
        phases=[]
        for name,patch_file,expected in [('prerequisite',args.prerequisite_patch,contract['allocator_baseline_rd_sha256']),
                                         ('mip',patch,contract['candidate_rd_sha256'])]:
            ran=subprocess.run(['patch','--batch','--forward','--fuzz=0','-p1','--input',str(patch_file.resolve())],
                cwd=tree,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=20)
            (args.output/f'{variant}-{name}.log').write_text(ran.stdout)
            require(ran.returncode==0 and 'offset' not in ran.stdout and 'fuzz' not in ran.stdout,'patch failed or did not apply exactly')
            require(digest(target)==expected,name+': exact resulting source differs')
            if name=='prerequisite':
                (args.output/f'{variant}-allocator-baseline.cpp').write_bytes(target.read_bytes())
            phases.append({'patch':name,'sha256':digest(patch_file),'source_after_sha256':digest(target)})
        result[variant]={'original_source_sha256':digest(path),'application':phases}
    (args.output/'source-check.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Both pinned source bytes and exact ordered patch application: OK')


if __name__=='__main__':
    main()
