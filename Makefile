all:
	zig build

clean:
	-make clean -C libhydrogen
	-rm -rf zig-cache/
	-rm -rf zig-out/
