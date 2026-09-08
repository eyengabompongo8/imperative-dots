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

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <workspace_id>", file=sys.stderr)
        sys.exit(1)

    try:
        ws_id = int(sys.argv[1])
    except ValueError:
        print("Workspace ID must be an integer", file=sys.stderr)
        sys.exit(1)

    out = run_cmd(['hyprctl', 'clients', '-j'])
    if not out:
        sys.exit(0)

    try:
        clients = json.loads(out)
    except Exception:
        sys.exit(0)

    ws_clients = [c for c in clients if c.get('workspace', {}).get('id') == ws_id]
    if not ws_clients:
        sys.exit(0)

    batch_cmds = []
    for c in ws_clients:
        addr = c.get('address')
        if addr:
            batch_cmds.append(f"dispatch hl.dsp.focus({{ window = 'address:{addr}' }}) ; dispatch hl.dsp.window.close()")

    if batch_cmds:
        batch_str = " ; ".join(batch_cmds)
        run_cmd(['hyprctl', '--batch', batch_str])

if __name__ == '__main__':
    main()
