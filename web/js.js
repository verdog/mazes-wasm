const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

ctx.fillStyle = "green";
ctx.fillRect(0, 0, 2, 2);

const {
  exports: { memory }
} = WebAssembly.instantiateStreaming(fetch("./zig-out/lib/spike.wasm"), {
  env: {
    jprint: (ptr, len) => {
      console.debug(decodeString(ptr, len));
    }
  }}).then((results) => {
    main();
});

const decodeString = (ptr, length) => {
  const slice = new Uint8Array(
    memory, // memory exported from Zig
    ptr,
    length
  );
  return new TextDecoder().decode(slice);
};

