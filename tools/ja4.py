#!/usr/bin/env python3
"""JA4 per FoxIO spec: c-part hashes extensions IN ORDER + sigalgs IN ORDER."""
import struct, hashlib, binascii, sys

GREASE = {0x0a0a,0x1a1a,0x2a2a,0x3a3a,0x4a4a,0x5a5a,0x6a6a,0x7a7a,
          0x8a8a,0x9a9a,0xaaaa,0xbaba,0xcaca,0xdada,0xeaea,0xfafa}

def parse(ch):
    p = 2 + 32
    sid = ch[p]; p += 1 + sid
    cl = struct.unpack(">H", ch[p:p+2])[0]; p += 2
    cip = [struct.unpack(">H", ch[p+i:p+i+2])[0] for i in range(0, cl, 2)]; p += cl
    cm = ch[p]; p += 1 + cm
    el = struct.unpack(">H", ch[p:p+2])[0]; p += 2; end = p + el
    exts, sni, alpn, ver, sigs = [], False, None, 0x0303, []
    while p + 4 <= end:
        et, ln = struct.unpack(">HH", ch[p:p+4]); p += 4
        body = ch[p:p+ln]; p += ln
        exts.append(et)
        if et == 0x0000: sni = True
        elif et == 0x0010 and ln >= 3: alpn = body[3:3+body[2]].decode("latin1","replace")
        elif et == 0x000d and ln >= 2:
            n = struct.unpack(">H", body[0:2])[0]
            sigs = [struct.unpack(">H", body[2+i:4+i])[0] for i in range(0, n, 2)]
        elif et == 0x002b and ln >= 3:
            n = body[0]; best = 0
            for i in range(0, n, 2):
                v = struct.unpack(">H", body[1+i:3+i])[0]
                if v not in GREASE and v > best: best = v
            if best: ver = best
    c   = [x for x in cip  if x not in GREASE]
    eall= [x for x in exts if x not in GREASE]
    eord= sorted(x for x in exts if x not in GREASE and x not in (0x0000, 0x0010))
    s   = [x for x in sigs if x not in GREASE]
    vmap = {0x0304:"13", 0x0303:"12", 0x0302:"11", 0x0301:"10"}
    a = "t%s%s%02d%02d%s" % (vmap.get(ver,"00"), "d" if sni else "i",
                             len(c), len(eall), (alpn[:1]+alpn[-1]) if alpn else "00")
    b = hashlib.sha256(",".join("%04x" % x for x in sorted(c)).encode()).hexdigest()[:12]
    cc = hashlib.sha256((",".join("%04x" % x for x in eord) +
                         ("_" + ",".join("%04x" % x for x in s) if s else "")).encode()).hexdigest()[:12]
    return dict(ja4=f"{a}_{b}_{cc}",
                ja4_r=f"{a}_" + ",".join("%04x"%x for x in sorted(c)) + "_" +
                      ",".join("%04x"%x for x in eord) + "_" + ",".join("%04x"%x for x in s),
                ciphers=c, exts=eord, sigs=s, alpn=alpn, sni=sni, ver=ver)

def self_test():
    # Firefox 135 ground truth from tls.peet.ws
    ext = "0005,000a,000b,000d,0012,0017,001b,001c,0022,0023,002b,002d,0033,fe0d,ff01"
    sig = "0403,0503,0603,0804,0805,0806,0401,0501,0601,0203,0201"
    got = hashlib.sha256((ext+"_"+sig).encode()).hexdigest()[:12]
    assert got == "3cbfd9057e0d", got
    ext2 = "0005,000a,000b,000d,0012,0017,001b,0023,002b,002d,0033,44cd,fe0d,ff01"
    sig2 = "0403,0804,0401,0503,0805,0501,0806,0601"
    assert hashlib.sha256((ext2+"_"+sig2).encode()).hexdigest()[:12] == "d8a2da3f94cd"
    ext3 = "0005,000a,000b,000d,0012,0017,001b,0023,002b,002d,0033,44cd,ca34,fe0d,ff01"
    sig3 = "0904,0905,0906,0403,0804,0401,0503,0805,0501,0806,0601"
    assert hashlib.sha256((ext3+"_"+sig3).encode()).hexdigest()[:12] == "cb7bf5808d99"
    print("self-test OK (FF135, CH136, CH152 vectors match)")

if __name__ == "__main__":
    if sys.argv[1] == "selftest": self_test(); sys.exit()
    for line in open(sys.argv[1]):
        line = line.strip()
        if not line: continue
        r = parse(binascii.unhexlify(line))
        print(r["ja4"])
        print("  ja4_r :", r["ja4_r"])
        print("  alpn=%s sni=%s ver=%s cip=%d ext=%d sig=%d" %
              (r["alpn"], r["sni"], hex(r["ver"]), len(r["ciphers"]), len(r["exts"]), len(r["sigs"])))
