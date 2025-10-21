#!/usr/bin/env python3
"""
초간단 테스트 서버 - MCP 연결 테스트용
"""

import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                "message": "✅ 서버 정상 작동 중!",
                "status": "running",
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "port": 8000
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
            
        elif self.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                "health": "excellent",
                "memory": "normal",
                "connections": "stable"
            }
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Not found"}, ensure_ascii=False).encode('utf-8'))
    
    def log_message(self, format, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {format % args}")

def start_server():
    PORT = 8000
    print("🚀 초간단 테스트 서버 시작!")
    print(f"📊 서버 주소: http://localhost:{PORT}")
    print("🔄 서버 실행 중... (Ctrl+C로 종료)")
    
    with socketserver.TCPServer(("", PORT), SimpleHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n⏹️ 서버 종료됨")

if __name__ == "__main__":
    start_server()
