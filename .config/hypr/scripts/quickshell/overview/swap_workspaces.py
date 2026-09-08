#!/usr/bin/env python3
import sys
import json
import subprocess

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return res.stdout
    except Exception as e:
        print(f"Error running command {cmd}: {e}", file=sys.stderr)
        return None

def get_json(cmd):
    out = run_cmd(cmd)
    if out:
        try:
            return json.loads(out)
        except Exception as e:
            print(f"JSON decode error: {e}", file=sys.stderr)
    return None

def main():
    active_ws = get_json(['hyprctl', 'activeworkspace', '-j']) or {}
    active_ws_id = active_ws.get('id', 1)

    if len(sys.argv) == 2:
        try:
            ws_a = active_ws_id
            ws_b = int(sys.argv[1])
        except ValueError:
            print("Workspace ID must be an integer", file=sys.stderr)
            sys.exit(1)
    elif len(sys.argv) >= 3:
        try:
            ws_a = int(sys.argv[1])
            ws_b = int(sys.argv[2])
        except ValueError:
            print("Workspace IDs must be integers", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"Usage: {sys.argv[0]} [workspace_a] <workspace_b>", file=sys.stderr)
        sys.exit(1)

    if ws_a == ws_b:
        sys.exit(0)

    clients = get_json(['hyprctl', 'clients', '-j']) or []
    workspaces = get_json(['hyprctl', 'workspaces', '-j']) or []

    # Detect per-workspace tiledLayout (monocle, dwindle, scrolling, etc.)
    ws_layout = {}
    for ws in workspaces:
        ws_id = ws.get('id')
        if ws_id is not None:
            ws_layout[ws_id] = ws.get('tiledLayout', 'monocle')

    layout_a = ws_layout.get(ws_a, 'monocle')
    layout_b = ws_layout.get(ws_b, 'monocle')

    # Gather clients on each workspace
    clients_a = [c for c in clients if c.get('workspace', {}).get('id') == ws_a]
    clients_b = [c for c in clients if c.get('workspace', {}).get('id') == ws_b]

    # If both workspaces are empty, nothing to move
    if not clients_a and not clients_b:
        sys.exit(0)

    # Function to sort windows preserving their layout arrangement:
    # Tiled windows: sorted spatially by X, then Y
    # Floating windows: sorted by focusHistoryID descending (oldest to newest)
    def sort_workspace_clients(c_list):
        tiled = [c for c in c_list if not c.get('floating', False)]
        floating = [c for c in c_list if c.get('floating', False)]

        tiled.sort(key=lambda c: (c.get('at', [0, 0])[0], c.get('at', [0, 0])[1]))
        floating.sort(key=lambda c: c.get('focusHistoryID', 99), reverse=True)
        return tiled, floating

    tiled_a, floating_a = sort_workspace_clients(clients_a)
    tiled_b, floating_b = sort_workspace_clients(clients_b)

    batch_cmds = []
    TEMP_WS = 9999

    # 1. Move windows of ws_a to TEMP_WS (tiled first, then floating)
    if clients_a:
        for w in tiled_a + floating_a:
            addr = w.get('address')
            if addr:
                batch_cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {TEMP_WS}, follow = false, window = 'address:{addr}' }})")

    # 2. Swap layout rules if they differ
    if layout_b and layout_b != layout_a:
        batch_cmds.append(f"eval hl.workspace_rule({{ workspace = '{ws_a}', layout = '{layout_b}' }})")
    if layout_a and layout_a != layout_b:
        batch_cmds.append(f"eval hl.workspace_rule({{ workspace = '{ws_b}', layout = '{layout_a}' }})")

    # 3. Move windows of ws_b to ws_a (tiled first in spatial order, then floating)
    if clients_b:
        for w in tiled_b + floating_b:
            addr = w.get('address')
            if addr:
                batch_cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {ws_a}, follow = false, window = 'address:{addr}' }})")

    # 4. Move windows from TEMP_WS to ws_b (tiled first in spatial order, then floating)
    if clients_a:
        for w in tiled_a + floating_a:
            addr = w.get('address')
            if addr:
                batch_cmds.append(f"dispatch hl.dsp.window.move({{ workspace = {ws_b}, follow = false, window = 'address:{addr}' }})")

    # Execute batch in chunks if needed
    if batch_cmds:
        batch_str = " ; ".join(batch_cmds)
        run_cmd(['hyprctl', '--batch', batch_str])

if __name__ == '__main__':
    main()
