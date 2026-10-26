#!/usr/bin/env python3
"""Regression tests for measured Termux browser fingerprints.

Every fixture is a raw TLS ClientHello captured on-device. The expected JA4
values are the ones real browsers produce (verified against tls.peet.ws for
desktop Chrome/Firefox, raw capture for the device's own Android Chrome).
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
JA4 = ROOT / "tools" / "ja4.py"
FIX = ROOT / "tests" / "fixtures"

# (fixture, expected ja4, why it matters)
CASES = [
    ("camoufox156-default.hex",
     "t13d1517h2_8daaf6152771_3cbfd9057e0d",
     "camoufox 156 must equal real Firefox 154/155 out of the box"),
    ("camoufox156-cbcprefs-wrong.hex",
     "t13d1717h2_5b57614c22b0_3cbfd9057e0d",
     "regression guard: re-enabling CBC cipher prefs rewrites the JA4"),
    ("chromium156-padding-disabled.hex",
     "t13d1517h2_8daaf6152771_cb7bf5808d99",
     "termux chromium -AddTLSServerHandshakePadding == Chrome 152"),
    ("android-chrome-device.hex",
     "t13d1516h2_8daaf6152771_d8a2da3f94cd",
     "the device's own Android Chrome, the ground truth for mobile"),
]


def ja4_of(path):
    out = subprocess.run([sys.executable, str(JA4), str(path)],
                         capture_output=True, text=True, check=True)
    return out.stdout.splitlines()[0].strip()


def test_spec_vectors():
    subprocess.run([sys.executable, str(JA4), "selftest"], check=True)


def test_measured_fixtures():
    failures = []
    for name, expected, why in CASES:
        got = ja4_of(FIX / name)
        if got != expected:
            failures.append(f"{name}: got {got}, want {expected} ({why})")
    assert not failures, "\n".join(failures)


def test_camoufox_differs_from_cbc_profile():
    default = ja4_of(FIX / "camoufox156-default.hex")
    cbc = ja4_of(FIX / "camoufox156-cbcprefs-wrong.hex")
    assert default != cbc, "the CBC pref fixture must not collapse onto the default"
    assert default.startswith("t13d1517h2"), default
    assert cbc.startswith("t13d1717h2"), cbc


if __name__ == "__main__":
    test_spec_vectors()
    test_measured_fixtures()
    test_camoufox_differs_from_cbc_profile()
    print("all fingerprint regression tests passed")
