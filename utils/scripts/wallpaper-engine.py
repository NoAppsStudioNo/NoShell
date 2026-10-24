#!/usr/bin/env python3
"""Steam Workshop Wallpaper Engine wallpapers through waywallen (https://github.com/waywallen/waywallen).

  status                   {"engine", "steam"}: waywallen installed, Wallpaper Engine installed in Steam
  list                     installed scene/video/web Workshop wallpapers
  apply ID [--paused] | stop   show Workshop wallpaper ID (starting waywallen) | quit waywallen
  pause | resume           freeze or unfreeze the live wallpaper (the shell's play wallpaper toggle)
  account                  {"signedIn", "name"}: the Steam account waywallen uses for the Workshop
  login                    Steam QR login, one JSON line per step ({"state", "qr", "error"}) until it ends
  logout
  search SORT PAGE [TEXT]  {"items", "more", "error"}: Workshop search (needs login)
  subscribe ID on|off      Steam downloads subscribed wallpapers while its client runs
  props ID                 {"schema", "overrides"}: Wallpaper Engine properties of the live wallpaper
  set ID KEY VALUE | reset ID KEY

Everything except list/status talks to waywallen's control WebSocket (proto/control.proto in its repo), with
just enough protobuf and WebSocket here to need nothing outside the standard library.
"""

import base64
import json
import os
import re
import shutil
import socket
import sqlite3
import struct
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
STEAM_ROOTS = [HOME / ".steam/steam", HOME / ".local/share/Steam", HOME / ".var/app/com.valvesoftware.Steam/data/Steam"]
WORKSHOP = "steamapps/workshop/content/431960"
ENGINE = shutil.which("waywallen") or str(HOME / ".local/opt/waywallen/waywallen.AppImage")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "waywallen"
DATABASE = DATA / "waywallen-v2.db"
SOURCE = "wallpaper_engine"  # the plugin's source id

# control.proto field numbers
REQ_LIBRARY_AUTO_DETECT, REQ_WALLPAPER_GET, REQ_PROPERTY_SET = 29, 42, 43
REQ_AVAILABILITY, REQ_SEARCH, REQ_ACTION, REQ_SUB_STATUS, REQ_SUB_SET, REQ_QR_CANCEL = 50, 51, 69, 70, 71, 72
EVENT_QR_PROGRESS = 23
QR_STATES = ["", "starting", "scan", "confirm", "scan", "done", "expired", "failed", "cancelled"]


def libraries():
    roots = set()
    for root in STEAM_ROOTS:
        vdf = root / "steamapps/libraryfolders.vdf"
        if vdf.is_file():
            roots.update(Path(p).resolve() for p in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(errors="ignore")))
        if root.is_dir():
            roots.add(root.resolve())
    return roots


def projects():
    items = {}
    for library in libraries():
        workshop = library / WORKSHOP
        if not workshop.is_dir():
            continue
        for path in workshop.iterdir():
            try:
                data = json.loads((path / "project.json").read_text())
            except (OSError, ValueError):
                continue
            kind = str(data.get("type", "")).lower()
            if kind not in {"scene", "video", "web"}:
                continue
            preview = path / str(data.get("preview", ""))
            items[path.name] = {
                "id": path.name,
                "title": str(data.get("title") or path.name).replace("\n", " "),
                "type": kind,
                "preview": str(preview) if preview.is_file() else "",
            }
    return sorted(items.values(), key=lambda p: p["title"].casefold())


# --- protobuf: just varints and length-delimited fields

def varint(n):
    n &= (1 << 64) - 1
    out = bytearray()
    while n > 0x7f:
        out.append(n & 0x7f | 0x80)
        n >>= 7
    return bytes(out) + bytes([n])


def enc(*fields):
    """enc((number, value), ...): bool/int as varint, str/bytes as length-delimited (nested messages are bytes)."""
    out = bytearray()
    for number, value in fields:
        if isinstance(value, (bool, int)):
            out += varint(number << 3) + varint(int(value))
        else:
            data = value.encode() if isinstance(value, str) else value
            out += varint(number << 3 | 2) + varint(len(data)) + data
    return bytes(out)


def dec(data):
    """bytes -> {number: [int | bytes]}"""
    fields, i = {}, 0

    def read_varint():
        nonlocal i
        n = shift = 0
        while True:
            b = data[i]
            i += 1
            n |= (b & 0x7f) << shift
            shift += 7
            if b < 0x80:
                return n

    while i < len(data):
        key = read_varint()
        wire = key & 7
        if wire == 0:
            value = read_varint()
        elif wire == 2:
            size = read_varint()
            value = data[i:i + size]
            i += size
        else:
            size = {1: 8, 5: 4}[wire]
            value = data[i:i + size]
            i += size
        fields.setdefault(key >> 3, []).append(value)
    return fields


def text(fields, number):
    return fields.get(number, [b""])[0].decode(errors="replace")


# --- WebSocket client, binary frames only

class Socket:
    def __init__(self, port):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=60)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET / HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                           f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        head = b""
        while not head.endswith(b"\r\n\r\n"):
            head += self.read(1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            sys.exit("waywallen refused the control connection")

    def read(self, size):
        data = b""
        while len(data) < size:
            chunk = self.sock.recv(size - len(data))
            if not chunk:
                sys.exit("waywallen closed the control connection")
            data += chunk
        return data

    def send(self, payload, opcode=2):
        mask = os.urandom(4)
        size = len(payload)
        if size < 126:
            head = bytes([0x80 | opcode, 0x80 | size])
        elif size < 65536:
            head = bytes([0x80 | opcode, 0x80 | 126]) + struct.pack(">H", size)
        else:
            head = bytes([0x80 | opcode, 0x80 | 127]) + struct.pack(">Q", size)
        self.sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def recv(self):
        message = b""
        while True:
            b0, b1 = self.read(2)
            size = b1 & 0x7f
            if size == 126:
                size = struct.unpack(">H", self.read(2))[0]
            elif size == 127:
                size = struct.unpack(">Q", self.read(8))[0]
            data = self.read(size)
            opcode = b0 & 0xf
            if opcode == 9:
                self.send(data, 10)
            elif opcode == 8:
                sys.exit("waywallen closed the control connection")
            elif opcode in (0, 1, 2):
                message += data
                if b0 & 0x80:
                    return message


class Control:
    """Requests are `Request{request_id, <payload>}`; replies come as `ServerFrame{response | event}`."""

    def __init__(self, port):
        self.ws = Socket(port)
        self.last_id = 0
        self.events = []

    def call(self, number, body=b""):
        self.last_id += 1
        self.ws.send(enc((1, self.last_id), (number, body)))
        while True:
            frame = dec(self.ws.recv())
            if 2 in frame:
                self.events.append(dec(frame[2][0]))
                continue
            response = dec(frame[1][0])
            if response.get(1, [0])[0] != self.last_id:
                continue
            if number not in response:
                sys.exit(text(response, 3) or "waywallen request failed")
            return dec(response[number][0])

    def event(self):
        if self.events:
            return self.events.pop(0)
        frame = dec(self.ws.recv())
        return dec(frame[2][0]) if 2 in frame else {}


# --- daemon

def dbus(method, *args, interface="org.waywallen.waywallen.Daemon1"):
    return subprocess.run([
        "gdbus", "call", "--session", "--dest", "org.waywallen.waywallen.Daemon",
        "--object-path", "/org/waywallen/waywallen/Daemon", "--method", f"{interface}.{method}", *args,
    ], capture_output=True, text=True)


def headless():
    return "--no-display" in subprocess.run(["pgrep", "-af", "waywallen"], capture_output=True, text=True).stdout


def daemon(display):
    """Starts waywallen if needed. Without a live wallpaper it runs headless: an idle one with a display puts an
    empty surface on the background layer, above the shell's own wallpaper."""
    if not dbus("Rescan").returncode:
        if not display or not headless():
            return
        dbus("Quit")
        while not dbus("Rescan").returncode:
            time.sleep(.2)
    if not Path(ENGINE).is_file():
        sys.exit(f"waywallen not found at {ENGINE}, rerun NoShell's install.sh")
    args = ["--display-backend", "layer-shell"] if display else ["--no-display"]
    subprocess.Popen([ENGINE, *args, "--no-ui", "--no-tray", "--no-restore"],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    deadline = time.monotonic() + 30
    while dbus("Rescan").returncode:
        if time.monotonic() > deadline:
            sys.exit("waywallen did not start")
        time.sleep(.3)
    # A fresh waywallen has no Steam library (its UI asks for one)
    control().call(REQ_LIBRARY_AUTO_DETECT)
    dbus("Rescan")


def control():
    port = dbus("Get", "org.waywallen.waywallen.Daemon1", "WsPort", interface="org.freedesktop.DBus.Properties")
    return Control(int(re.search(r"(\d+)>", port.stdout).group(1)))  # "(<uint16 1234>,)"


def item_id(workshop_id):
    """waywallen's id for a Workshop wallpaper, once its scan has imported it."""
    for _ in range(100):
        if DATABASE.is_file():
            with sqlite3.connect(DATABASE) as connection:
                row = connection.execute(
                    "SELECT id FROM item WHERE external_id = ? AND type IN ('scene', 'video', 'web')", (workshop_id,)
                ).fetchone()
            if row:
                return str(row[0])
        time.sleep(.3)
    sys.exit(f"waywallen has not imported {workshop_id}")


# --- commands

def apply(workshop_id, paused):
    daemon(display=True)
    result = dbus("ApplyById", item_id(workshop_id))
    if result.returncode:
        sys.exit(f"could not apply {workshop_id}: {result.stderr.strip()}")
    if paused:
        dbus("Pause")


def account(ctl):
    for source in ctl.call(REQ_AVAILABILITY).get(1, []):
        source = dec(source)
        if text(source, 1) == SOURCE:
            actions = {text(a, 1): bool(a.get(6, [0])[0]) for a in map(dec, source.get(10, []))}
            status = [text(s, 5) for s in map(dec, source.get(11, []))]
            return {"signedIn": actions.get("steam_sign_out", False), "name": status[0] if status else ""}
    sys.exit("waywallen's Wallpaper Engine plugin is not installed, rerun NoShell's install.sh")


def action(ctl, name):
    reply = ctl.call(REQ_ACTION, enc((1, SOURCE), (2, name)))
    if not reply.get(1, [0])[0]:
        sys.exit(text(reply, 2) or f"{name} failed")
    return text(reply, 3)


def login(ctl):
    session = action(ctl, "steam_sign_in")
    try:
        while True:
            progress = ctl.event().get(EVENT_QR_PROGRESS)
            if not progress:
                continue
            progress = dec(progress[0])
            if text(progress, 1) != session:
                continue
            state = QR_STATES[progress.get(4, [0])[0]]
            print(json.dumps({"state": state, "qr": text(progress, 5), "error": text(progress, 7)}), flush=True)
            if state in ("done", "expired", "failed", "cancelled"):
                return
    finally:
        if sys.exc_info()[0]:
            ctl.call(REQ_QR_CANCEL, enc((1, session)))


def search(ctl, sort, page, query):
    reply = ctl.call(REQ_SEARCH, enc((1, SOURCE), (2, query), (3, sort), (4, int(page))))
    items = [{"id": text(i, 1), "title": text(i, 2), "preview": text(i, 3), "author": text(i, 4), "type": text(i, 7)}
             for i in map(dec, reply.get(1, []))]
    if items:
        status = ctl.call(REQ_SUB_STATUS, enc((1, SOURCE), *[(2, i["id"]) for i in items]))
        subscribed = {text(s, 1) for s in map(dec, status.get(1, [])) if s.get(2, [0])[0] == 2}
        for item in items:
            item["subscribed"] = item["id"] in subscribed
    return {"items": items, "more": bool(reply.get(2, [0])[0]), "error": text(reply, 3)}


def subscribe(ctl, workshop_id, on):
    reply = ctl.call(REQ_SUB_SET, enc((1, SOURCE), (2, workshop_id), (3, on)))
    if not reply.get(1, [0])[0]:
        sys.exit(text(reply, 2) or "Steam did not accept the change")


def props(ctl, workshop_id):
    entry = dec(ctl.call(REQ_WALLPAPER_GET, enc((1, item_id(workshop_id)))).get(1, [b""])[0])
    return {"schema": json.loads(text(entry, 12) or "{}"), "overrides": json.loads(text(entry, 13) or "{}")}


def main():
    args = sys.argv[1:]
    match args:
        case ["status"]:
            steam = any((lib / "steamapps/common/wallpaper_engine/assets").is_dir() for lib in libraries())
            print(json.dumps({"engine": Path(ENGINE).is_file(), "steam": steam}))
            return
        case ["list"]:
            print(json.dumps(projects(), ensure_ascii=False))
            return
        case ["apply", workshop_id, *flags]:
            apply(workshop_id, "--paused" in flags)
            return
        case ["stop"]:
            dbus("Quit")
            return
        case ["pause"] | ["resume"]:
            dbus(args[0].capitalize())  # nothing to do when waywallen isn't running
            return
    if not args or args[0] not in ("account", "login", "logout", "search", "subscribe", "props", "set", "reset"):
        sys.exit(__doc__)
    daemon(display=False)
    ctl = control()
    match args:
        case ["account"]:
            print(json.dumps(account(ctl), ensure_ascii=False))
        case ["login"]:
            login(ctl)
        case ["logout"]:
            action(ctl, "steam_sign_out")
        case ["search", sort, page, *query]:
            print(json.dumps(search(ctl, sort, page, " ".join(query)), ensure_ascii=False))
        case ["subscribe", workshop_id, on]:
            subscribe(ctl, workshop_id, on == "on")
        case ["props", workshop_id]:
            print(json.dumps(props(ctl, workshop_id), ensure_ascii=False))
        case ["set", workshop_id, key, value]:
            ctl.call(REQ_PROPERTY_SET, enc((1, item_id(workshop_id)), (2, key), (3, value)))
        case ["reset", workshop_id, key]:
            ctl.call(REQ_PROPERTY_SET, enc((1, item_id(workshop_id)), (2, key), (4, True)))
        case _:
            sys.exit(__doc__)


if __name__ == "__main__":
    main()
