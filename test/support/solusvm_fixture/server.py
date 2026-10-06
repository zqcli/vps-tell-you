#!/usr/bin/env python3
"""Loopback-only synthetic SolusVM HTTPS fixture; never executes power actions.

Only the fixed SYNTHETIC_* credentials below are accepted. Logs retain method,
path, query and result only; headers/form data are neither printed nor saved.
"""
import argparse
import json
import ssl
import time
from email.parser import BytesParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=34576)
parser.add_argument('--cert', required=True)
parser.add_argument('--key', required=True)
args = parser.parse_args()


def event(**values):
    print(json.dumps(values, ensure_ascii=False), flush=True)


class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *_):
        pass

    def send(self, status, body, content_type='application/json'):
        payload = body.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
            pass
        event(method=self.command, path=urlsplit(self.path).path,
              query=urlsplit(self.path).query, status=status)

    def do_POST(self):
        if self.path != '/api/client/command.php':
            self.send(404, '{}')
            return
        size = int(self.headers.get('Content-Length', 0))
        if size <= 0 or size > 20000:
            self.send(400, '{}')
            return
        content_type = self.headers.get('Content-Type', '')
        mime = BytesParser().parsebytes(('Content-Type: ' + content_type + '\r\n\r\n').encode() + self.rfile.read(size))
        fields = {}
        if mime.is_multipart():
            for part in mime.get_payload():
                fields[part.get_param('name', header='content-disposition')] = part.get_payload(decode=True).decode()
        if set(fields) != {'key', 'hash', 'action'} or fields['action'] != 'status':
            self.send(400, '{}')
            return
        if fields['key'] == 'SYNTHETIC_SLOW':
            time.sleep(20)
        if fields['key'] not in {'SYNTHETIC_KEY', 'SYNTHETIC_SLOW'} or fields['hash'] != 'SYNTHETIC_HASH':
            self.send(401, '{}')
            return
        self.send(200, '<status>success</status><statusmsg>online</statusmsg>', 'text/xml; charset=utf-8')

    def do_GET(self):
        path = urlsplit(self.path)
        token = self.headers.get('Authorization', '')
        if token == 'Bearer SYNTHETIC_SLOW':
            time.sleep(20)
        if token not in {'Bearer SYNTHETIC_TOKEN', 'Bearer SYNTHETIC_SLOW', 'Bearer SYNTHETIC_OTHER'}:
            self.send(401, '{}')
            return
        page = int(parse_qs(path.query).get('page', ['1'])[0])
        if path.path == '/api/v1/account' and not path.query:
            data = {'data': {'id': 99 if token.endswith('OTHER') else 12}}
        elif path.path == '/api/v1/projects' and set(parse_qs(path.query)) == {'page'}:
            data = {'data': [{'id': 7, 'name': '本地合成项目'}], 'meta': {'current_page': 1, 'last_page': 1}}
        elif path.path == '/api/v1/projects/7/servers' and page in {1, 2}:
            data = {'data': [{
                'id': 100 + page,
                'uuid': '00000000-0000-4000-8000-' + str(page).zfill(12),
                'name': '合成实例 ' + str(page), 'project': {'id': 7},
                'real_status': 'started' if page == 1 else 'stopped',
                'is_suspended': False,
                'specifications': {'vcpu': 2, 'ram': 2147483648, 'disk': 40},
                'ip_addresses': {'ipv4': [{'ip': '192.0.2.' + str(page), 'is_primary': True}]},
                'location': {'name': '本地协议验收'},
                'settings': {'os_image': {'name': 'Synthetic Linux'}},
            }], 'meta': {'current_page': page, 'last_page': 2},
                'links': {'next': '?page=2' if page == 1 else None}}
        else:
            self.send(404, '{}')
            return
        self.send(200, json.dumps(data, ensure_ascii=False))


server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(args.cert, args.key)
server.socket = context.wrap_socket(server.socket, server_side=True)
event(event='ready', host='127.0.0.1', port=server.server_port)
server.serve_forever()
