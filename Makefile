ZIG ?= zig

.DEFAULT_GOAL := all

.PHONY: all build test fmt fmt-check cross-compile cross-x86_64-windows cross-aarch64-windows clean

all: build test

build:
	$(ZIG) build

test:
	cd test && $(ZIG) build run

fmt:
	$(ZIG) fmt . test/

fmt-check:
	$(ZIG) fmt --check . test/

cross-x86_64-windows:
	$(ZIG) build -Dtarget=x86_64-windows

cross-aarch64-windows:
	$(ZIG) build -Dtarget=aarch64-windows

cross-compile: cross-x86_64-windows cross-aarch64-windows

clean:
	rm -rf zig-out .zig-cache test/zig-out test/.zig-cache
