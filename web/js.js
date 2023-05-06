const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

const blob = await WebAssembly.compileStreaming(fetch("./zig-out/lib/masm.wasm"));

const {
  exports: { memory, gen, setSeed },
} = await WebAssembly.instantiate(blob, {
  env: {
    consoleDebug: (ptr, len) => {
      const s = decodeString(ptr, len);
      console.log(s);
    },

    ctxFillStyle: (ptr, len) => {
      ctx.fillStyle = decodeString(ptr, len);
    },

    ctxFillRect: (x, y, w, h) => {
      ctx.fillRect(x, y, w, h);
    },

    ctxFillAll: () => {
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    },

    ctxStrokeStyle: (ptr, len) => {
      ctx.strokeStyle = decodeString(ptr, len);
    },

    ctxLine: (x1, x2, y1, y2) => {
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    },

    ctxSetSize: (width, height) => {
      canvas.width = width;
      canvas.height = height;
    },
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

setSeed(Date.now());
gen();

canvas.onclick = (event) => {
  gen();
};
