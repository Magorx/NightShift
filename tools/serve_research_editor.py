#!/usr/bin/env python3
"""Local server for the Research Tree Editor — enables direct save to research_tree.json with backups."""
import http.server
import json
import os
import shutil
from datetime import datetime

PORT = 8099
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.join(SCRIPT_DIR, '..')
JSON_PATH = os.path.join(PROJECT_ROOT, 'resources', 'tech', 'research_tree.json')
EDITOR_PATH = os.path.join(SCRIPT_DIR, 'research_tree_editor.html')
ATLAS_PATH = os.path.join(PROJECT_ROOT, 'resources', 'items', 'sprites', 'item_atlas.png')
BACKUP_DIR = os.path.join(os.path.dirname(JSON_PATH), 'backups')
MAX_BACKUPS = 10


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Quieter logging
        if '/api/' in (args[0] if args else ''):
            print(f"  {args[0]}")

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            with open(EDITOR_PATH, 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/api/tree':
            try:
                with open(JSON_PATH, 'r') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(data.encode())
            except Exception as e:
                self._json_error(500, str(e))
        elif self.path == '/api/atlas':
            try:
                with open(ATLAS_PATH, 'rb') as f:
                    img = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'image/png')
                self.send_header('Cache-Control', 'max-age=3600')
                self.end_headers()
                self.wfile.write(img)
            except Exception as e:
                self._json_error(500, str(e))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/api/tree':
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length).decode()
            try:
                json.loads(body)  # validate
            except json.JSONDecodeError as e:
                self._json_error(400, f'Invalid JSON: {e}')
                return

            # Create backup
            if os.path.exists(JSON_PATH):
                os.makedirs(BACKUP_DIR, exist_ok=True)
                ts = datetime.now().strftime('%Y-%m-%dT%H-%M-%S')
                backup_path = os.path.join(BACKUP_DIR, f'research_tree_{ts}.json')
                shutil.copy2(JSON_PATH, backup_path)
                # Prune old backups
                backups = sorted(f for f in os.listdir(BACKUP_DIR)
                                 if f.startswith('research_tree_') and f.endswith('.json'))
                while len(backups) > MAX_BACKUPS:
                    os.remove(os.path.join(BACKUP_DIR, backups.pop(0)))

            with open(JSON_PATH, 'w') as f:
                f.write(body)
            print(f"  Saved research_tree.json (backup: {ts})")

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"ok": true}')
        else:
            self.send_response(404)
            self.end_headers()

    def _json_error(self, code, msg):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'error': msg}).encode())


if __name__ == '__main__':
    print(f'Research Tree Editor: http://localhost:{PORT}')
    print(f'Editing: {os.path.abspath(JSON_PATH)}')
    print('Press Ctrl+C to stop.\n')
    server = http.server.HTTPServer(('', PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nStopped.')
