#!/usr/bin/env python3
"""
OSD Hardware Watcher - event-driven detection of hardware state changes for Osd.qml.

Monitors:
- Screen Brightness: Kernel netlink uevents (SUBSYSTEM=backlight)
- Keyboard Backlight: sysfs brightness_hw_changed (POLLPRI) & netlink (SUBSYSTEM=leds)
- Caps Lock / Num Lock: Kernel netlink uevents (SUBSYSTEM=leds)
- Camera: Kernel netlink uevents (SUBSYSTEM=video4linux, SUBSYSTEM=media)
- Power Profile: D-Bus monitor on net.hadess.PowerProfiles
- Audio Volume / Mic: pactl subscribe in real-time
"""
import sys, os, glob, subprocess, threading, select, socket, signal

def out(msg):
    sys.stdout.write(msg + "\n")
    sys.stdout.flush()

def find_first(patterns):
    for pat in patterns:
        matches = glob.glob(pat)
        if matches:
            return matches[0]
    return None

kbd_file     = find_first(["/sys/class/leds/*kbd_backlight/brightness", "/sys/class/leds/*kbd*/brightness"])
kbd_max_file = find_first(["/sys/class/leds/*kbd_backlight/max_brightness", "/sys/class/leds/*kbd*/max_brightness"])
kbd_hw_file  = find_first(["/sys/class/leds/*kbd_backlight/brightness_hw_changed", "/sys/class/leds/*kbd*/brightness_hw_changed"])
caps_file    = find_first(["/sys/class/leds/*capslock/brightness"])
num_file     = find_first(["/sys/class/leds/*numlock/brightness"])
mon_file     = find_first(["/sys/class/backlight/*/brightness"])
mon_max_file = find_first(["/sys/class/backlight/*/max_brightness"])
power_file   = "/sys/firmware/acpi/platform_profile"

def read_val(path):
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r") as f:
            return int(f.read().strip())
    except Exception:
        return None

def read_str(path):
    if not path or not os.path.exists(path):
        return ""
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        return ""

def check_camera():
    return 1 if glob.glob("/dev/video*") else 0

last_kbd   = read_val(kbd_file)
last_caps  = read_val(caps_file)
last_num   = read_val(num_file)
last_mon   = read_val(mon_file)
last_power = read_str(power_file)
last_cam   = check_camera()
kbd_max    = read_val(kbd_max_file) or 3
mon_max    = read_val(mon_max_file) or 100

# ── Audio Listener ────────────────────────────────────────────────────────────

def get_sink_vol():
    try:
        v = subprocess.check_output(["pamixer", "--get-volume"], stderr=subprocess.DEVNULL).decode().strip()
        m = subprocess.check_output(["pamixer", "--get-mute"],   stderr=subprocess.DEVNULL).decode().strip()
        return v, m
    except Exception:
        return "50", "false"

def get_source_vol():
    try:
        v = subprocess.check_output(["pamixer", "--default-source", "--get-volume"], stderr=subprocess.DEVNULL).decode().strip()
        m = subprocess.check_output(["pamixer", "--default-source", "--get-mute"],   stderr=subprocess.DEVNULL).decode().strip()
        return v, m
    except Exception:
        return "100", "false"

last_vol,     last_mute     = get_sink_vol()
last_mic_vol, last_mic_mute = get_source_vol()

def audio_listener():
    global last_vol, last_mute, last_mic_vol, last_mic_mute
    try:
        proc = subprocess.Popen(["pactl", "subscribe"],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for line in proc.stdout:
            if "sink" in line:
                cur_vol, cur_mute = get_sink_vol()
                if cur_vol != last_vol or cur_mute != last_mute:
                    last_vol, last_mute = cur_vol, cur_mute
                    out(f"volume|{cur_vol}|{cur_mute}")
            elif "source" in line:
                cur_mic_vol, cur_mic_mute = get_source_vol()
                if cur_mic_vol != last_mic_vol or cur_mic_mute != last_mic_mute:
                    last_mic_vol, last_mic_mute = cur_mic_vol, cur_mic_mute
                    out(f"mic|{cur_mic_vol}|{cur_mic_mute}")
    except Exception:
        pass

# ── Power Profile Listener ───────────────────────────────────────────────────

def power_listener():
    global last_power
    try:
        proc = subprocess.Popen(["gdbus", "monitor", "--system", "--dest", "net.hadess.PowerProfiles"],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for _ in proc.stdout:
            cur_power = read_str(power_file)
            if not cur_power:
                try:
                    cur_power = subprocess.check_output(["powerprofilesctl", "get"], stderr=subprocess.DEVNULL).decode().strip()
                except Exception:
                    pass
            if cur_power and cur_power != last_power:
                last_power = cur_power
                out(f"power|{cur_power}")
    except Exception:
        pass

threading.Thread(target=audio_listener, daemon=True).start()
threading.Thread(target=power_listener, daemon=True).start()

# ── Netlink and Sysfs epoll Setup ─────────────────────────────────────────────

NETLINK_KOBJECT_UEVENT = 15
nl_sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_KOBJECT_UEVENT)
nl_sock.bind((os.getpid(), 1))
nl_sock.setblocking(False)

epoll = select.epoll()
epoll.register(nl_sock.fileno(), select.EPOLLIN)

kbd_fd = None
if kbd_hw_file and os.path.exists(kbd_hw_file):
    try:
        kbd_fd = os.open(kbd_hw_file, os.O_RDONLY | os.O_NONBLOCK)
        try:
            os.read(kbd_fd, 64)
        except OSError:
            pass
        os.lseek(kbd_fd, 0, os.SEEK_SET)
        epoll.register(kbd_fd, select.POLLPRI | select.POLLERR)
    except Exception:
        kbd_fd = None

def handle_kbd_hw():
    global last_kbd
    if kbd_fd is not None:
        try:
            os.read(kbd_fd, 64)
        except OSError:
            pass
        os.lseek(kbd_fd, 0, os.SEEK_SET)
    cur_kbd = read_val(kbd_file)
    if cur_kbd is not None and cur_kbd != last_kbd:
        last_kbd = cur_kbd
        pct = round((cur_kbd * 100) / (kbd_max if kbd_max > 0 else 1))
        out(f"kbd|{pct}")

def handle_uevent(raw_data):
    global last_mon, last_caps, last_num, last_kbd, last_cam
    msg = raw_data.decode('latin-1', errors='replace')
    
    if "SUBSYSTEM=backlight" in msg:
        if mon_file:
            cur_mon = read_val(mon_file)
            if cur_mon is not None and cur_mon != last_mon:
                last_mon = cur_mon
                pct = round((cur_mon * 100) / (mon_max if mon_max > 0 else 1))
                out(f"brightness|{pct}")
                
    elif "SUBSYSTEM=leds" in msg:
        if caps_file:
            cur_caps = read_val(caps_file)
            if cur_caps is not None and cur_caps != last_caps:
                last_caps = cur_caps
                out(f"caps|{cur_caps}")
        if num_file:
            cur_num = read_val(num_file)
            if cur_num is not None and cur_num != last_num:
                last_num = cur_num
                out(f"num|{cur_num}")
        if kbd_file:
            cur_kbd = read_val(kbd_file)
            if cur_kbd is not None and cur_kbd != last_kbd:
                last_kbd = cur_kbd
                pct = round((cur_kbd * 100) / (kbd_max if kbd_max > 0 else 1))
                out(f"kbd|{pct}")
                
    elif "SUBSYSTEM=video4linux" in msg or "SUBSYSTEM=media" in msg:
        cur_cam = check_camera()
        if cur_cam != last_cam:
            last_cam = cur_cam
            out(f"camera|{cur_cam}")

# Signal handling for clean exit
def handle_exit(signum, frame):
    try:
        epoll.close()
        nl_sock.close()
        if kbd_fd is not None:
            os.close(kbd_fd)
    except Exception:
        pass
    sys.exit(0)

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)

# ── Main Event Loop ───────────────────────────────────────────────────────────

while True:
    events = epoll.poll()
    for fd, event in events:
        if fd == nl_sock.fileno():
            while True:
                try:
                    data = nl_sock.recv(4096)
                    handle_uevent(data)
                except BlockingIOError:
                    break
        elif kbd_fd is not None and fd == kbd_fd:
            handle_kbd_hw()

