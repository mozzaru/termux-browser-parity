#!/usr/bin/env python3
"""Capture a raw TLS ClientHello from any local client and print its JA4.

Usage:
    python3 tools/capture.py 8443 out.hex &
    chromium-real --headless --dump-dom https://127.0.0.1.nip.io:8443/
    # then: python3 tools/ja4.py out.hex
"""
import socket, struct, sys, binascii, threading

def serve(port, out, count=8):
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", port)); s.listen(16)
    print(f"listening on {port}, writing {out}", flush=True)
    for _ in range(count):
        c, _ = s.accept()
        c.settimeout(8)
        buf = b""
        try:
            while len(buf) < 65536:
                d = c.recv(4096)
                if not d: break
                buf += d
                if len(buf) > 5:
                    ln = struct.unpack(">H", buf[3:5])[0]
                    if len(buf) >= 5 + ln: break
        except Exception:
            pass
        if len(buf) > 9 and buf[5] == 1:
            hl = struct.unpack(">H", buf[7:9])[0] + 4
            ch = buf[9:5+hl]
            open(out, "ab").write(binascii.hexlify(ch) + b"\n")
            print(f"captured {len(ch)} bytes", flush=True)
        try: c.close()
        except Exception: pass

if __name__ == "__main__":
    serve(int(sys.argv[1]), sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 8)
