Maze generator in zig/SDL2 ported to run in the browser/WASM.

Try it out at https://dogspluspl.us/mazeme!

![](./web/demo.gif)

## Building

First, update submodules:
```
git submodule update --init
```

Then:
```
zig build
```

or
```
zig build -Drelease-fast
```
