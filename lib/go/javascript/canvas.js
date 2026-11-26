//
// canvas.js
// f_dot webgl.
//
// created by i2097i
//

const canvas = document.querySelector("#gl-canvas");

export function configureCanvas() {
  console.info("configureCanvas");

  // initialize webgl context
  const gl = canvas.getContext("webgl");

  if (gl === null) {
    console.error(
      "unable to initialize webgl. your browser or machine may not support it.",
    );
    return;
  }

  gl.clearColor(0.1, 0.2, 0.3, 0.77);
  gl.clear(gl.COLOR_BUFFER_BIT);
}

export function toggleVisible() {
  if (canvas.style.display == "none") {
    canvas.style.display = "block";
  } else {
    canvas.style.display = "none";
  }
}
