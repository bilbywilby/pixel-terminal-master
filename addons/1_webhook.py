import http.server, socketserver, subprocess
local_port = 8080
class H(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        subprocess.Popen(["sh", "./master.sh"])
        self.send_response(200)
        self.end_headers()
socketserver.TCPServer(("", local_port), H).serve_forever()
