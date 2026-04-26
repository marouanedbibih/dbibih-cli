SHELL := /bin/bash

.PHONY: build install smoke all

build:
	bash scripts/build-deb.sh

install: build
	bash scripts/install-local.sh

smoke:
	bash scripts/smoke-test.sh

all: build smoke
