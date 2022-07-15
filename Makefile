all:
	@zig build
init:
	@git submodule init
clean:
	-make clean -C libhydrogen
	-rm -rf zig-cache/
	-rm -rf zig-out/
