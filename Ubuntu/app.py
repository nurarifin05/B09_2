#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from urllib.parse import parse_qs
from html import escape
import os
class Handler(BaseHTTPRequestHandler):
 def render(self,body,code=200):
  data=body.encode();self.send_response(code);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(data)
 def do_GET(self):
  self.render("<!doctype html><html lang=\"id\"><meta charset=\"utf-8\"><title>LAB_SSL</title><body><h1>LAB_SSL</h1><p>Gunakan kredensial simulasi saja.</p><form method=\"post\" action=\"/login\"><label>Username <input name=\"username\"></label><label>Password <input type=\"password\" name=\"password\"></label><button type=\"submit\">Login simulasi</button></form></body></html>")
 def do_POST(self):
  if self.path!='/login':self.send_error(404);return
  n=int(self.headers.get('Content-Length','0'))
  if n>2048:self.send_error(413);return
  fields=parse_qs(self.rfile.read(n).decode('utf-8','replace'))
  # Tidak menyimpan password di log server.
  self.render('<html><body><h2>Login dummy diterima</h2><p>Username: '+escape(fields.get('username',[''])[0])+'</p><p>Tidak ada autentikasi sungguhan.</p></body></html>')
 def log_message(self,fmt,*args):
  # Jangan log parameter POST.
  print(self.address_string(),self.command,self.path,flush=True)
ThreadingHTTPServer(('127.0.0.1',8088),Handler).serve_forever()
