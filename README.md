# ZencPipe

just trying to learn Zig 😊

implemented:

- [x] `-G, --passgen          generate a random password`
- [x] `-e, --encrypt          encryption mode`
- [x] `-d, --decrypt          decryption mode`
- [x] `-p, --pass <password>  use <password>`
- [x] `-P, --passfile <file>  read password from <file>`
- [x] `-i, --in <file>        read input from <file>`
- [x] `-o, --out <file>       write output to <file>`
- [x] `-h, --help             print this message`
- [ ] tests : probably more needed

original is [here](https://github.com/jedisct1/encpipe)

## How to build

```bash
# clone submodule
git submodule update --init
# get dependencies
zigmod ci
# test
zig build test
# build release
zig build -Drelease-safe # or -Drelease-fast
```

Note that building without `release-safe` or `release-fast` will give a very slow binary.
