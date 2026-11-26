import * as f_dot_go from "./f_dot_go.js"
import * as f_dot_canvas from "./canvas.js"
console.info("starting f_dot_go.js", f_dot_go);
f_dot_go.connect();
f_dot_go.configureDom();

// todo: webgl
f_dot_canvas.configureCanvas();
f_dot_canvas.toggleVisible();
