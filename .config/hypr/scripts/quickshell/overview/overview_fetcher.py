#!/usr/bin/env python3
import json
import os
import subprocess
import glob

def get_json(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(res.stdout)
    except Exception:
        return None

# Hardcoded overrides for apps with no .desktop or unusual WM class behavior
ICON_OVERRIDES = {
    'zen':          'zen-browser',
    'code':         'com.visualstudio.code',
    'code-oss':     'com.visualstudio.code.oss',
    'obs':          'com.obsproject.Studio',
}

def build_class_to_icon_map():
    """Parse .desktop files to build a WMClass / desktop ID -> icon name lookup table."""
    class_map = {}
    desktop_dirs = [
        '/usr/share/applications',
        '/usr/local/share/applications',
        os.path.expanduser('~/.local/share/applications'),
        '/var/lib/flatpak/exports/share/applications',
        os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
    ]
    for d in desktop_dirs:
        if not os.path.isdir(d):
            continue
        for path in glob.glob(os.path.join(d, '**/*.desktop'), recursive=True):
            basename = os.path.splitext(os.path.basename(path))[0].lower()
            try:
                with open(path, encoding='utf-8', errors='ignore') as f:
                    in_entry = False
                    icon = wm_class = ''
                    for line in f:
                        line = line.strip()
                        if line == '[Desktop Entry]':
                            in_entry = True
                        elif line.startswith('['):
                            in_entry = False
                        if not in_entry:
                            continue
                        if line.startswith('Icon=') and not icon:
                            icon = line[5:].strip()
                        elif line.startswith('StartupWMClass=') and not wm_class:
                            wm_class = line[15:].strip()
                    if icon:
                        if wm_class:
                            class_map[wm_class.lower()] = icon
                        class_map[basename] = icon
            except Exception:
                pass
    return class_map

def resolve_icon(cls, class_map):
    """Resolve the best icon name for a given window class string."""
    key = cls.lower()
    # 1. Hardcoded overrides (highest priority)
    if key in ICON_OVERRIDES:
        return ICON_OVERRIDES[key]
    # 2. .desktop StartupWMClass or basename lookup
    if key in class_map:
        return class_map[key]
    # 3. Bare lowercased class (last resort fallback)
    return key

def compute_virtual_tiling_bounds(windows, mon_w, mon_h):
    n = len(windows)
    if n == 0:
        return
    
    gap = 12
    def split(rect, count):
        if count == 1:
            return [rect]
        x, y, w, h = rect
        if count == 2:
            if w >= h:
                w1 = max(100, (w - gap) // 2)
                w2 = max(100, w - w1 - gap)
                return [(x, y, w1, h), (x + w1 + gap, y, w2, h)]
            else:
                h1 = max(80, (h - gap) // 2)
                h2 = max(80, h - h1 - gap)
                return [(x, y, w, h1), (x, y + h1 + gap, w, h2)]
        
        half = count // 2
        rest = count - half
        if w >= h:
            w1 = max(100, (w - gap) // 2)
            w2 = max(100, w - w1 - gap)
            left_rect = (x, y, w1, h)
            right_rect = (x + w1 + gap, y, w2, h)
            return split(left_rect, half) + split(right_rect, rest)
        else:
            h1 = max(80, (h - gap) // 2)
            h2 = max(80, h - h1 - gap)
            top_rect = (x, y, w, h1)
            bottom_rect = (x, y + h1 + gap, w, h2)
            return split(top_rect, half) + split(bottom_rect, rest)

    rects = split((0, 0, mon_w, mon_h), n)
    for win, r in zip(windows, rects):
        win['at'] = [int(r[0]), int(r[1])]
        win['size'] = [int(r[2]), int(r[3])]

def fetch_overview():
    home = os.path.expanduser('~')
    settings_path = os.path.join(home, '.config', 'hypr', 'settings.json')
    workspace_count = 8
    if os.path.exists(settings_path):
        try:
            with open(settings_path, 'r', encoding='utf-8') as f:
                s = json.load(f)
                workspace_count = int(s.get('workspaceCount', 8))
        except Exception:
            pass

    class_map = build_class_to_icon_map()

    clients = get_json(['hyprctl', 'clients', '-j']) or []
    monitors = get_json(['hyprctl', 'monitors', '-j']) or []
    active_ws = get_json(['hyprctl', 'activeworkspace', '-j']) or {}

    active_ws_id = active_ws.get('id', 1)

    mon_w = 1920
    mon_h = 1080
    if monitors and len(monitors) > 0:
        focused_mon = next((m for m in monitors if m.get('focused')), monitors[0])
        mon_w = focused_mon.get('width', 1920)
        mon_h = focused_mon.get('height', 1080)

    ws_map = {}
    for i in range(1, workspace_count + 1):
        ws_map[i] = {
            'id': i,
            'name': str(i),
            'isActive': (i == active_ws_id),
            'isOccupied': False,
            'windows': []
        }

    for c in clients:
        if not c.get('mapped', True) or c.get('hidden', False):
            continue
        ws_info = c.get('workspace', {})
        ws_id = ws_info.get('id')
        if ws_id is not None and ws_id in ws_map:
            cls = c.get('class') or c.get('initialClass') or 'application-x-executable'
            icon = resolve_icon(cls, class_map)
            
            addr = c.get('address', '')
            ws_map[ws_id]['isOccupied'] = True
            ws_map[ws_id]['windows'].append({
                'address': addr,
                'title': c.get('title', 'Window'),
                'class': cls,
                'icon': icon,
                'at': c.get('at', [0, 0]),
                'size': c.get('size', [400, 300]),
                'floating': bool(c.get('floating', False)),
                'fullscreen': int(c.get('fullscreen', 0)),
                'focusHistoryID': c.get('focusHistoryID', 99)
            })

    for i in range(1, workspace_count + 1):
        wins = ws_map[i]['windows']
        wins.sort(key=lambda x: x['focusHistoryID'])
        # Include ALL windows (tiling + floating) in virtual layout calculation
        compute_virtual_tiling_bounds(wins, mon_w, mon_h)

    result = {
        'workspaceCount': workspace_count,
        'activeWorkspaceId': active_ws_id,
        'monitor': {
            'width': mon_w,
            'height': mon_h
        },
        'workspaces': list(ws_map.values())
    }

    print(json.dumps(result))

if __name__ == '__main__':
    fetch_overview()
