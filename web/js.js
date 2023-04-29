// const canvas = document.getElementById("canvas");
// const ctx = canvas.getContext("2d");
//
// ctx.fillStyle = "green";
// ctx.fillRect(0, 0, 2, 2);

const blob = await WebAssembly.compileStreaming(fetch("./zig-out/lib/masm.wasm"));

const {
  exports: { memory, gen },
} = await WebAssembly.instantiate(blob, {
  env: {
    consoleDebug: (ptr, len) => {
        const s = decodeString(ptr, len);
        console.log(s);
    }
  }
});

const decodeString = (ptr, length) => {
  const slice = new Uint8Array(
    memory.buffer,
    ptr,
    length
  );
  return new TextDecoder().decode(slice);
};

window.go = () => {
  gen();
};
