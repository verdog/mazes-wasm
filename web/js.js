const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");

const options_walls = document.getElementById("walls");
const options_fill_cells = document.getElementById("fill cells");
const options_width = document.getElementById("width");
const options_height = document.getElementById("height");
const options_scale = document.getElementById("scale");
const options_seed = document.getElementById("seed");
const options_braid = document.getElementById("braid");
const options_inset = document.getElementById("inset");

const blob = await WebAssembly.compileStreaming(fetch("./zig-out/lib/masm.wasm"));

const {
  exports: {
    memory,
    gen,

    getSeed,
    setSeed,

    getWalls,
    setWalls,

    getFillCells,
    setFillCells,

    getWidth,
    setWidth,

    getHeight,
    setHeight,

    getScale,
    setScale,

    getBraid,
    setBraid,

    getInset,
    setInset,
  },
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
      ctx.lineWidth = 1.5;
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

const redraw = () => {
  options_walls.checked = getWalls();
  options_fill_cells.checked = getFillCells();
  options_width.value = getWidth();
  options_height.value = getHeight();
  options_scale.value = getScale();
  options_seed.value = getSeed();
  options_braid.value = getBraid();
  options_inset.value = getInset();

  gen();
}

setSeed(Date.now());
redraw();

canvas.onclick = (_) => {
  setSeed(options_seed.value + 1);
  redraw();
}

options_walls.onchange = (_) => {
  setWalls(options_walls.checked);
  redraw();
}

options_fill_cells.onchange = (_) => {
  setFillCells(options_fill_cells.checked);
  redraw();
}

options_width.oninput = (_) => {
  setWidth(options_width.value);
  redraw();
}

options_height.oninput = (_) => {
  setHeight(options_height.value);
  redraw();
}

options_scale.oninput = (_) => {
  setScale(options_scale.value);
  redraw();
}

options_seed.onchange = (_) => {
  setSeed(options_seed.value);
  redraw();
}

options_braid.oninput = (_) => {
  setBraid(options_braid.value);
  redraw();
}

options_inset.oninput = (_) => {
  setInset(options_inset.value);
  redraw();
}

window.redraw = redraw;
window.setWalls = setWalls;
window.setFillCells = setFillCells;
window.setScale = setScale;
window.setSeed = setSeed;
window.setWidth = setWidth;
window.setHeight = setHeight;
window.setInset = setInset;
window.setBraid = setBraid;
