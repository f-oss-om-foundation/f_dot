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
  // "time"
  "path"
  "sync"
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
var connManager = newConnManager()

type ConnManager struct {
  mu      sync.RWMutex
  clients map[*websocket.Conn]bool
}

func newConnManager() *ConnManager {
  return &ConnManager{
    clients: make(map[*websocket.Conn]bool),
  }
}

func (m *ConnManager) add(conn *websocket.Conn) {
  m.mu.Lock()
  defer m.mu.Unlock()
  m.clients[conn] = true
}

func (m *ConnManager) remove(conn *websocket.Conn) {
  m.mu.Lock()
  defer m.mu.Unlock()
  delete(m.clients, conn)
}

func (m *ConnManager) broadcast(message []byte) {
  m.mu.Lock()
  defer m.mu.Unlock()

  for conn := range m.clients {
    err := conn.WriteMessage(websocket.TextMessage, message)
    if err != nil {
      log.Printf("Broadcast error, removing client: %v", err)
      conn.Close()
      delete(m.clients, conn)
    }
  }
}

func writeDisplay(displayFileData []byte) {
  connManager.broadcast(displayFileData)
}

func render(w http.ResponseWriter, req *http.Request) {
  log.Print("starting render:", req)
  c, err := upgrader.Upgrade(w, req, nil)
  if err != nil {
    log.Print("upgrade:", err)
    return
  }
  defer c.Close()

  connManager.add(c)

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
    writeDisplay(displayFileData)
  }

  // send controls file
  controlsFileData, err := os.ReadFile(pathForFilename(controlsFileName))
  if err != nil {
    log.Print("failed to read:", controlsFileName)
  } else {
    connManager.broadcast(controlsFileData)
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
    }
  }
}

func html(w http.ResponseWriter, req *http.Request) {
  indexHtmlTemplate.Execute(w, struct{}{})
}

func javascript(w http.ResponseWriter, req *http.Request) {
  fileName := path.Base(req.URL.Path)
  w.Header().Set("Content-Type", "application/javascript; charset=UTF-8")

  http.ServeFile(w, req, pathForFilename("javascript/"+fileName))
  // log.Print("rendering javascript: ", fileName)
  // fileTemplate := template.Must(template.ParseFiles(pathForFilename("javascript/"+fileName)))

  // err := fileTemplate.Execute(w, struct{}{})

  // if err != nil {
  //   log.Println("error:", err)
  //   http.Error(w, "template parse error", http.StatusInternalServerError)
  //   return
  // }
}

func ready() {
  log.Print("got ready from f_dot")
  // send display file
  displayFileData, err := os.ReadFile(pathForFilename(displayFileName))
  if err != nil {
    log.Print("failed to read:", displayFileName)
  } else {
    writeDisplay(displayFileData)
  }

  // send controls file
  controlsFileData, err := os.ReadFile(pathForFilename(controlsFileName))
  if err != nil {
    log.Print("failed to read:", controlsFileName)
  } else {
    connManager.broadcast([]byte(controlsFileData))
  }
}

func handler(wr http.ResponseWriter, req *http.Request) {
  defer req.Body.Close()

  if websocket.IsWebSocketUpgrade(req) {
    render(wr, req)
  } else if req.URL.Path == "/ready" {
    ready()
  } else if req.URL.Path == "/" {
    html(wr, req)
  } else if strings.Contains(req.URL.Path, "/javascript/") {
    javascript(wr, req)
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

func serveJavascript() {
  mux := http.NewServeMux()
  // Serve everything inside ./javascript under the /javascript/ URL path
  fs := http.FileServer(http.Dir("./javascript"))
  mux.Handle("/javascript/", http.StripPrefix("/javascript/", fs))
}

func main() {
  indexHtmlTemplate = template.Must(template.ParseFiles(pathForFilename("index.html")))
  http.ListenAndServe(
    "0.0.0.0:"+port,
    h2c.NewHandler(
      http.HandlerFunc(handler),
      &http2.Server{},
    ),
  )
}
