//
// f_dot_go.js
// f_dot go websockets.
//
// adapted from golang gorilla websockets
//
// created by i2097i
//

import * as f_dot_canvas from "./canvas.js"

var ws;
var connectDelay = 4444;
var autoReconnect = true;
var connectTimer = null;
var counter = 0;
var lastMessageWasTimeout = false;
var singleInputMode = false;

function escapeHtml(unsafe) {
  return String(unsafe ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function sendControl(event) {
  ws.send(JSON.stringify({"uuid": event.target.getAttribute("id")})+"\n");
}

function onclose(event) {
  console.log('onclose', event);
  console.log('code:', event.code);
  console.log('reason:', event.reason);
  console.log('clean:', event.wasClean);

  clearTimeout(connectTimer);

  // check if server closed connection due to timeout
  // note: some browsers may not properly receive the close reason
  var isTimeoutClose = false;

  // check multiple conditions for timeout detection
  if (event.reason && event.reason.includes('Connection timeout')) {
    isTimeoutClose = true;
  } else if (event.code === 1000 && event.wasClean && lastMessageWasTimeout) {
    // fallback: if we received a timeout message just before close
    isTimeoutClose = true;
  }

  if (isTimeoutClose || lastMessageWasTimeout) {
    // server explicitly closed due to timeout - don't reconnect

    if (!lastMessageWasTimeout) {
      // only log if we didn't already log in onmessage
      var timeoutReason = event.reason || 'connection closed by server due to timeout';
      console.log('SERVER TIMEOUT: ' + timeoutReason, 'error');
      console.log('connection terminated by server - no auto-reconnect', 'error');
    }

    // reset the flag for next connection
    lastMessageWasTimeout = false;
  } else if (autoReconnect) {
    console.info('disconnected, reconnecting in ' + (connectDelay / 1000) + ' seconds');
    connectTimer = setTimeout(connect, connectDelay);
  } else {
    console.info('disconnected');
  }
}

function onopen(event) {
  console.info('onopen', event);

  // reset timeout flag on new connection
  lastMessageWasTimeout = false;

  ws.onclose = onclose;
}

function onmessage(event) {
  console.info('onmessage', event);

  // Check if this is a timeout message
  if (event.data && event.data.includes && event.data.includes('Connection timeout')) {
    lastMessageWasTimeout = true;
    autoReconnect = false; // Disable auto-reconnect immediately

    // Log the timeout message prominently
    console.log('SERVER TIMEOUT: ' + event.data, 'error');
    console.log('connection will close - no auto-reconnect', 'error');
    return; // Don't log as regular message
  }

  console.log("event_data", event.data);

  if (typeof event.data !== "string" || event.data.length == 0) {
    return
  }
  // rely on json parser exception
  try {
    // if pars-able, it is implicitly controls
    var parsed = JSON.parse(event.data);
    var controlsHtml = "";
    for(i = 0; i < parsed.length; i++) {
      if (typeof parsed[i].type !== "undefined") {
        singleInputMode = true;
        // value input
        switch(parsed[i].type) {
          case "text":
            controlsHtml = controlsHtml + `<input id="${parsed[i].uuid}" type="${parsed[i].type}" placeholder="enter value for ${escapeHtml(parsed[i].name)}"></input>`
            break;
          default:
            break;
        }

      } else {
        // default menu options
        controlsHtml = controlsHtml + `<button id="${parsed[i].uuid}"><pre>${escapeHtml(parsed[i].name)}</pre></button>`;
      }
    }
    document.getElementById('controls').innerHTML = controlsHtml;

    var buttons = document.getElementById("controls").children; // HTMLCollection
    for (var i = 0; i < buttons.length; i++) {
      var htmlEl = buttons.item(i)
      switch(htmlEl.tagName) {
        case "BUTTON":
          htmlEl.addEventListener("click", sendControl);
          break;
        case "INPUT":
          htmlEl.addEventListener("keydown", onControlKeyPress);
          break;
        default:
          break;
      }
    }
    moveBaton();
  } catch (error) {
    // otherwise assume display
    var node = document.createElement("div");
    node.className = "display_text";
    node.textContent = event.data;
    document.getElementById('display').appendChild(node);
    setTimeout(function() {
      document.getElementById('display').scrollIntoView({
        block: "end"
      });
    }, 42);
  }
}

function onerror(event) {
  console.error('onerror', event);
  clearTimeout(connectTimer);

  if (autoReconnect) {
    lconsole.og('unable to connect, retrying in ' + (connectDelay / 1000) + ' seconds', 'error');
    connectTimer = setTimeout(connect, connectDelay);
  } else {
    console.info('disconnected');
  }
}

export function connect() {
  console.info('attempting to connect')

  // reset timeout flag for new connection
  lastMessageWasTimeout = false;

  ws = new WebSocket("ws://localhost:8080/render")
  //   location.protocol === 'https:'
  //     ? 'wss://' + window.location.host + "/render"
  //     : 'ws://' + window.location.host + "/render"
  // );
  ws.onopen = onopen;
  ws.onmessage = onmessage;
  ws.onerror = onerror;
}

function moveBaton(reverse) {
  var currentHolder = null;
  var nextHolder = null;

  const buttons = document.getElementById("controls").children; // HTMLCollection
  for (var i = 0; i < buttons.length; i++) {
    const button = buttons.item(i);
    if (button.className == "baton") {
      currentHolder = button;
      if (reverse === true) {
        nextHolder = (i == 0) ? buttons.item(buttons.length - 1) : buttons.item(i - 1);
      } else {
        nextHolder = (i == (buttons.length - 1)) ? buttons.item(0) : buttons.item(i + 1);
      }
    }
  }
  if (currentHolder === null) {
    nextHolder = buttons.item(0);
  } else {
    currentHolder.className = "";
  }

  nextHolder.className = "baton";
  nextHolder.scrollIntoView({
    block: "end"
  });
}

function batonSelected() {
  const buttons = document.getElementById("controls").children; // HTMLCollection
  for (var i = 0; i < buttons.length; i++) {
    const button = buttons.item(i);
    if (button.className == "baton") {
      button.click();
    }
  }
}

function submitSingleInput(event) {
  singleInputMode = false;
  ws.send(JSON.stringify({"uuid": event.target.getAttribute("id"), "new_value": event.target.value})+"\n");
}

function onControlKeyPress(event) {
  if (!singleInputMode) {
    console.error("invalid call to onControlKeyPress!");
    return
  }

  const key = event.key.toLowerCase();
  console.info(`onControlKeyPress: event.key = "${key}"`);
  switch(key) {
    case "enter":
      if (typeof event.target.value === 'string' &&
        event.target.value.length > 0
      ) {
        submitSingleInput(event);
      } else {
        console.warn("cannot submit empty value!");
      }
      break;
    default:
      console.info(event.target.value);
      break;
  }
}

function onDocumentKeyPress(event) {
  if (singleInputMode) {
    return;
  }
  const key = event.key.toLowerCase();
  console.info(`onDocumentKeyPress: event.key = "${key}"`);
  switch(key) {
    case "tab":
      console.info("tab key pressed!");
      event.preventDefault();
      moveBaton();
      break;
    case "enter":
      batonSelected();
      break;
    case "w":
    case "arrowup":
      console.info("up key pressed!");
      break;
    case "a":
    case "arrowleft":
      console.info("left key pressed!");
      moveBaton(true);
      break;
    case "s":
    case "arrowdown":
      console.info("down key pressed!");
      break;
    case "d":
    case "arrowright":
      console.info("right key pressed!");
      moveBaton();
      break;
    default:
      break;
  }
}

function fDotMenuButtonClick(event) {
  console.info("fDotMenuButtonClick(event)", event);
  f_dot_canvas.toggleVisible();
}

export function configureDom() {
  // configure keyboard input processing
  document.addEventListener('keydown', onDocumentKeyPress);

  // configure menu button click
  document.getElementById("f_dot_menu_button").addEventListener('click', fDotMenuButtonClick);
}
