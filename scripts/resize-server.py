#!/usr/bin/env python3
"""
HTTP server for dynamic resolution changes.
GET /resize?width=W&height=H - Change resolution
GET /resolution - Get current resolution
"""

import subprocess
import http.server
import socketserver
import urllib.parse
import json
import re
import os

PORT = 6081

class ResizeHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def get_current_resolution(self):
        try:
            result = subprocess.run(['xrandr'], capture_output=True, text=True,
                                    env={**os.environ, 'DISPLAY': ':0'})
            match = re.search(r'current (\d+) x (\d+)', result.stdout)
            if match:
                return int(match.group(1)), int(match.group(2))
        except:
            pass
        return None, None

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path == '/resolution':
            width, height = self.get_current_resolution()
            if width:
                self.send_json({'width': width, 'height': height})
            else:
                self.send_json({'error': 'Could not get resolution'}, 500)

        elif parsed.path == '/resize':
            width = params.get('width', [None])[0]
            height = params.get('height', [None])[0]

            if not width or not height:
                self.send_json({'error': 'Missing width or height'}, 400)
                return

            try:
                width = max(640, min(3840, int(width)))
                height = max(480, min(2160, int(height)))

                result = subprocess.run(
                    ['/usr/local/bin/resize.sh', f'{width}x{height}'],
                    capture_output=True, text=True,
                    env={**os.environ, 'DISPLAY': ':0'}
                )

                if result.returncode == 0:
                    self.send_json({'success': True, 'width': width, 'height': height})
                else:
                    self.send_json({'error': result.stderr or 'Resize failed'}, 500)
            except Exception as e:
                self.send_json({'error': str(e)}, 500)

        elif parsed.path == '/health':
            self.send_json({'status': 'ok'})
        else:
            self.send_json({'error': 'Not found'}, 404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.end_headers()

if __name__ == '__main__':
    with socketserver.TCPServer(('', PORT), ResizeHandler) as httpd:
        print(f'[RESIZE] Server on port {PORT}')
        httpd.serve_forever()
