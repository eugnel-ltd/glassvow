"""Independent synthetic request/copy graphs; never native or GPU results."""
import json

CASES = [
    ('etc2-rgb-odd', 'ETC2_RGB8', 146, 17, 13, 1, 2, 1, 4, 1, 8),
    ('etc2-rgba-wood', 'ETC2_RGBA8', 150, 2048, 1024, 1, 2, 1, 4, 0, 16),
    ('eac-rg11-normal', 'ETC2_RG11', 154, 1024, 768, 1, 1, 1, 4, 0, 16),
    ('astc4-material', 'ASTC_4x4', 156, 1024, 1024, 1, 1, 1, 4, 0, 16),
    ('astc4-padded', 'ASTC_4x4', 156, 53, 31, 1, 2, 1, 4, 0, 16),
    ('rgba8-depth-padded', 'RGBA8', 36, 23, 17, 3, 1, 4, 1, 0, 4),
    ('la8-control', 'LA8', 15, 3, 17, 1, 2, 2, 1, 0, 2),
]


def aligned(value, step):
    return (value + step - 1) // step * step


def graph(variant, row_step=1):
    lines = ['Metal 3.2 - Forward Mobile - Using Device #0: Apple - Apple Synthetic Test GPU']
    for case, name, fmt, *_ in CASES:
        lines.append('GV_STAGING_CAPABILITY ' + json.dumps(dict(case=case, format=name,
            native_format=fmt, usage_flags=193, supported=True)))
    for case, name, fmt, width, height, depth, layers, pixel, block, shift, block_bytes in CASES:
        count, w, h, d = 1, width, height, depth
        while w > 1 or h > 1 or d > 1:
            w, h, d = max(1, w // 2), max(1, h // 2), max(1, d // 2)
            count += 1
        forced = int(case.endswith('-padded'))
        alignment = 512 if forced else block_bytes
        for layer in range(layers):
            w, h, d = width, height, depth
            offset, payload, copies = 0, 0, []
            for mip in range(count):
                pw, ph = aligned(w, block), aligned(h, block)
                pitch = aligned((pw * pixel * block) >> shift, row_step)
                reserved = pitch * (ph // block) if variant == 'candidate' else (pitch * ph) >> shift
                tight = (pw * ph * pixel) >> shift
                for z in range(d):
                    offset = aligned(offset, alignment)
                    copies.append(dict(case=case, layer=layer, mip=mip, z=z, offset=offset,
                        local=offset, pitch=pitch, width=w, height=h, padded_w=pw, padded_h=ph,
                        reserved=reserved))
                    offset += reserved
                    payload += tight
                w, h, d = max(1, w // 2), max(1, h // 2), max(1, d // 2)
            traits = dict(case=case, layer=layer, row_pitch_step=row_step, transfer_alignment=1,
                honors_pipeline_barriers=0, forced_row_padding=0, forced_offset_alignment=forced)
            lines.append('GV_STAGING_METAL_TRAITS ' + ' '.join(f'{k}={v}' for k, v in traits.items()))
            request = dict(case=case, layer=layer, format=fmt, width=width, height=height,
                depth=depth, mips=count, payload=payload, reserved=offset, pitch_step=row_step,
                align=alignment, block_w=block, block_h=block, pixel_size=pixel, rshift=shift,
                forced=forced)
            lines.append('GV_STAGING_REQUEST ' + ' '.join(f'{k}={v}' for k, v in request.items()))
            lines += ['GV_STAGING_COPY ' + ' '.join(f'{k}={v}' for k, v in copy.items()) for copy in copies]
            lines.append('GV_STAGING_READBACK ' + json.dumps(dict(case=case, format=name,
                layer=layer, width=width, height=height, depth=depth, mips=count,
                requested_native_format=fmt, created_native_format=fmt,
                source_bytes=payload, actual_bytes=payload, source_sha256='1' * 64,
                actual_sha256='1' * 64, equal=True)))
    return '\n'.join(lines + ['GV_STAGING_DONE 11', ''])
