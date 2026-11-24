//
// i2097i adapted from:
// https://raw.githubusercontent.com/gorilla/websocket/refs/heads/main/examples/echo/server.go

// Copyright 2015 The Gorilla WebSocket Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
  "log"
  "net/http"
  "html/template"
  "os"
  "strings"
  "time"
  "path/filepath"
  "github.com/gorilla/websocket"
  "golang.org/x/net/http2"
  "golang.org/x/net/http2/h2c"
)

var port = "8080"

var upgrader = websocket.Upgrader{
  CheckOrigin: func(*http.Request) bool {
    return true
  },
}

var indexHtmlTemplate = template.Must(template.New("").Parse("<html></html>"))

var displayFileName = "display"
var controlsFileName = "controls"
var inputFileName = "input"

func writeDisplay(ws *websocket.Conn, displayFileData []byte) {
  log.Print("writing ", displayFileName)
  for _, line := range strings.Split(string(displayFileData), "\n") {
    ws.WriteMessage(websocket.TextMessage, []byte(line))
  }
}

func writeControls(ws *websocket.Conn, controlsFileData []byte) {
  log.Print("writing ", controlsFileName)
  ws.WriteMessage(websocket.TextMessage, controlsFileData)
}

func render(w http.ResponseWriter, r *http.Request) {
  log.Print("starting render:", r)
  c, err := upgrader.Upgrade(w, r, nil)
  if err != nil {
    log.Print("upgrade:", err)
    return
  }
  defer c.Close()

  path, err := os.Executable()
  if err != nil {
    log.Print("path, err := os.Executable() error!", err)
  }
  os.ReadDir(path)

  // send display file
  displayFileData, err := os.ReadFile(pathForFilename(displayFileName))
  if err != nil {
    log.Print("failed to read:", displayFileName)
  } else {
    writeDisplay(c, displayFileData)
  }

  // send controls file
  controlsFileData, err := os.ReadFile(pathForFilename(controlsFileName))
  if err != nil {
    log.Print("failed to read:", controlsFileName)
  } else {
    writeControls(c, controlsFileData)
  }

  type wsMessage struct {
    messageType int
    message     []byte
    err         error
  }
  messageChan := make(chan wsMessage)

  // Channel to signal when to stop reading
  done := make(chan bool)

  go func() {
    for {
      messageType, message, err := c.ReadMessage()
      select {
      case messageChan <- wsMessage{messageType, message, err}:
      case <-done:
        return
      }
      if err != nil {
        return
      }
    }
  }()

  defer close(done)

  for {
    select {
    case msg := <-messageChan:
      log.Print("writing input ", msg.message)
      os.WriteFile(pathForFilename(inputFileName), []byte(msg.message), 0644)
      if err != nil {
        log.Fatal(err)
      }

      time.Sleep(222 * time.Millisecond)

      path, err := os.Executable()
      if err != nil {
        log.Print("path, err := os.Executable() error!", err)
      }
      var f_dot_dir = filepath.Dir(path)
      log.Print("os.ReadDir(f_dot_dir)", f_dot_dir+"/")
      os.ReadDir(f_dot_dir+"/")

      // send display file
      displayFileData, err := os.ReadFile(pathForFilename(displayFileName))
      if err != nil {
        log.Print("failed to read:", displayFileName)
      } else {
        writeDisplay(c, displayFileData)
      }

      // send controls file
      controlsFileData, err := os.ReadFile(pathForFilename(controlsFileName))
      if err != nil {
        log.Print("failed to read:", controlsFileName)
      } else {
        writeControls(c, controlsFileData)
      }
    }
  }
}

func html(w http.ResponseWriter, r *http.Request) {
  indexHtmlTemplate.Execute(w, struct{}{})
}

func handler(wr http.ResponseWriter, req *http.Request) {
  defer req.Body.Close()

  if websocket.IsWebSocketUpgrade(req) {
    render(wr, req)
  } else if req.URL.Path == "/" {
    html(wr, req)
  }
}

func pathForFilename(f string) string {
  path, err := os.Executable()
  if err != nil {
    log.Fatal(err)
  }
  log.Print("running in ", path)

  return filepath.Dir(path)+"/"+f
}

func main() {
  indexHtmlTemplate = template.Must(template.ParseFiles(pathForFilename("index.html")))

  http.ListenAndServe(
    ":"+port,
    h2c.NewHandler(
      http.HandlerFunc(handler),
      &http2.Server{},
    ),
  )
}
