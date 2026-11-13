"""lldb 原版全量形变记录器——SetSpeed 触发→停跑循环逐帧采样 position/scale/rotation"""
import lldb, struct, time

_t0 = time.time()
_log = open('/tmp/vc_probe.log', 'a')
_log.write(f'\n=== session {time.strftime("%H:%M:%S")} ===\n')
_log.flush()
_recording = False
_native_ptr = 0
_pos_off = -1

def _p(msg):
    print(msg)
    _log.write(msg + '\n')
    _log.flush()

def _read(proc, addr, size):
    err = lldb.SBError()
    raw = proc.ReadMemory(addr, size, err)
    return raw if err.Success() else None

def _find_native_and_offsets(proc, transform_ptr):
    """从 managed Transform 找 native ptr，dump 找 position offset"""
    global _native_ptr, _pos_off
    # managed Transform: native ptr at +0x10 (x86_64 dump Transform.set_position :149)
    raw = _read(proc, transform_ptr, 0x20)
    if not raw:
        _p(f'[INIT] FAIL: read Transform@0x{transform_ptr:X}')
        return False
    _p(f'[INIT] Transform@0x{transform_ptr:X}:')
    for i in range(0, 0x20, 8):
        _p(f'  +0x{i:02X}: 0x{struct.unpack_from("<Q", raw, i)[0]:016X}')

    native = 0
    for off in [0x10, 0x18, 0x08, 0x20]:
        if off + 8 <= len(raw):
            val = struct.unpack_from('<Q', raw, off)[0]
            if val > 0x100000000 and val != transform_ptr:
                native = val
                _p(f'  native_ptr candidate at +0x{off:02X} = 0x{val:X}')
                break
    if not native:
        _p('[INIT] FAIL: no native ptr found')
        return False

    # dump native 256 bytes
    nraw = _read(proc, native, 0x100)
    if not nraw:
        _p(f'[INIT] FAIL: read native@0x{native:X}')
        return False
    _p(f'[INIT] native@0x{native:X} dump:')
    for i in range(0, 0x100, 16):
        hexs = ' '.join(f'{b:02X}' for b in nraw[i:i+16])
        _p(f'  +0x{i:02X}: {hexs}')

    # 找 position: 3 个连续 float，|x|<3000, |y|<3000, |z|<100
    candidates = []
    for off in range(0, 0x100 - 12, 4):
        x, y, z = struct.unpack_from('<fff', nraw, off)
        if abs(x) < 3000 and abs(y) < 3000 and abs(z) < 100:
            if abs(x) > 0.1 or abs(y) > 0.1:
                candidates.append((off, x, y, z))
    for off, x, y, z in candidates[:5]:
        _p(f'  pos candidate +0x{off:02X}: ({x:.1f}, {y:.1f}, {z:.1f})')

    if not candidates:
        _p('[INIT] FAIL: no position found in native dump')
        return False

    _native_ptr = native
    _pos_off = candidates[0][0]
    _p(f'[INIT] ★ native=0x{native:X} pos_offset=0x{_pos_off:X}')
    return True

def on_speed(frame, bp_loc, internal_dict):
    """SetSpeed 触发：dump 整个 mover 对象诊断字段布局"""
    try:
        proc = frame.GetThread().GetProcess()
        err = lldb.SBError()
        mover = frame.FindRegister('x0').GetValueAsUnsigned()
        v0 = frame.FindRegister('v0')
        speed = 0.0
        if v0 and v0.IsValid():
            data = v0.GetData()
            speed = data.GetFloat(err, 0) if err.Success() else 0.0

        # dump 128 字节的 mover 对象——看全部字段
        raw = _read(proc, mover, 0x80)
        if raw:
            _p(f'\n[DUMP] speed={speed:.0f} mover=0x{mover:X}')
            for i in range(0, 0x80, 16):
                # hex 视图
                hexs = ' '.join(f'{b:02X}' for b in raw[i:i+16])
                # float 视图
                floats = ''
                for j in range(i, min(i+16, len(raw)), 4):
                    f = struct.unpack_from('<f', raw, j)[0]
                    floats += f'{f:10.2f}'
                # ptr 视图
                ptrs = ''
                for j in range(i, min(i+8, len(raw)), 8):
                    p = struct.unpack_from('<Q', raw, j)[0]
                    ptrs += f' 0x{p:X}' if p > 0x100000000 else ''
                _p(f'  +0x{i:02X}: {hexs} │{floats}│{ptrs}')
            _p('')
    except Exception as e:
        _p(f'[DUMP] err: {e}')
    return False

# 全部 13 个 SetSpeed 地址
VADDRS = [0x6D9AB4, 0x3673EB4, 0x3BC23E4, 0x4665EA8, 0x466D980,
          0x46F9D44, 0x4852464, 0x48524EC, 0x4AB68BC, 0x4D72158,
          0x4E478DC, 0x500010C, 0x5011080]

def setup(target):
    base = None
    for m in target.modules:
        if 'GameAssembly' in str(m.file):
            base = m.GetObjectFileHeaderAddress().GetLoadAddress(target)
            _p(f'[SETUP] base=0x{base:X}')
            break
    if base is None:
        _p('[SETUP] ERROR: GameAssembly not found')
        return
    for va in VADDRS:
        bp = target.BreakpointCreateByAddress(base + va)
        bp.SetScriptCallbackFunction('vc_probe_cb.on_speed')
    _p(f'[SETUP] {len(VADDRS)} 个断点')
    _p('[SETUP] === 抽一张牌——自动记录 5 秒完整动画 → /tmp/vc_card_anim.csv ===')
