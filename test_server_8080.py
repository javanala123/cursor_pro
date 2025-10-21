#!/usr/bin/env python3
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        response = {'status': 'OK', 'message': '서버 작동 중!', 'port': 8080, 'time': time.strftime('%H:%M:%S')}
        self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
    
    def log_message(self, format, *args):
        print(f'[{time.strftime("%H:%M:%S")}] {format % args}')

print('🚀 서버 시작! http://localhost:8080')
with socketserver.TCPServer(('', 8080), Handler) as httpd:
    httpd.serve_forever()




