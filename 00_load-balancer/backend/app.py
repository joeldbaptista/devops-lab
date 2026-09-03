import os
import socket
from flask import Flask, request

app = Flask(__name__)
NAME = os.environ.get("NAME", "unknown")

@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def catch_all(path):
	return {
		"server_name": NAME,
		"hostname": socket.gethostname(),
		"path_requested": f"/{path}",
		"method": request.method,
		"client_ip": request.remote_addr,
		"x_forwarded_for": request.headers.get("X-Forwarded-For", None),
		"host_header": request.headers.get("Host", None),
	}

if __name__ == "__main__":
	app.run(host="0.0.0.0", port=8080)
