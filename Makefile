all: fmt build test
fmt:
	@zig fmt .
build:
	@zig build
test:
	@zig build test
init:
	@pre-commit install
	@pre-commit autoupdate
	@git submodule init
	@zigmod fetch
clean:
	-make clean -C libhydrogen
	-rm -rf zig-cache/
	-rm -rf zig-out/

.PHONY: all init clean
