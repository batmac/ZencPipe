all:
	@zig fmt .
	@zig build
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
