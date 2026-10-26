PY ?= python3

.PHONY: test capture install clean

test:
	$(PY) tests/test_fingerprints.py

# make capture PORT=8443 OUT=cap.hex
capture:
	$(PY) tools/capture.py $(PORT) $(OUT)

# install the two wrappers into $PREFIX/bin
install:
	install -m 0755 bin/chromium-real $(PREFIX)/bin/chromium-real
	install -m 0755 bin/pw-real $(PREFIX)/bin/pw-real
	@echo "installed. verify with: chromium-real --headless --dump-dom https://tls.peet.ws/api/all"

clean:
	rm -rf src out __pycache__ tests/__pycache__
