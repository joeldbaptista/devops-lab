# Load balancing with nginx, at layer 4 and layer 7

In this project we compare two ways of balancing load with nginx. The first way
works at layer 4 of the OSI model, the transport layer, so nginx forwards TCP
connections without reading what travels inside them. The second way works at
layer 7, the application layer, so nginx parses each HTTP request and routes it
by the request path. Both run as containers under Docker Compose, and both sit
in front of the same small Python backend.

The two experiments are independent. They share one `docker-compose.yml`, and
they use separate load balancers, separate backends, and separate host ports, so
starting the stack starts both at once.

## The backend

The backend is a Flask application in `backend/app.py`. It answers every path
and every method with a JSON object that reports what the request looked like
when it arrived. The complete list of reported fields is: `server_name`, taken
from the `NAME` environment variable; `hostname`, the container hostname;
`path_requested`; `method`; `client_ip`; `x_forwarded_for`; and `host_header`.

Those fields are the instrument of the experiment. `server_name` shows which
backend answered, so it exposes the balancing decision. And `client_ip`,
`x_forwarded_for`, and `host_header` show what the load balancer did to the
request on the way through.

The same image serves both experiments. Only `NAME` differs between the five
backend containers.

## Experiment 1 — layer 4

The layer 4 load balancer is `lb_l4`, configured by `l4/nginx.conf` and
published on host port 8081. Its configuration uses the `stream` block, so nginx
proxies raw TCP. The upstream holds `backend1:8080` and `backend2:8080`, and
nginx applies its default round-robin policy, so consecutive connections go to
alternating backends.

Two properties follow from proxying at layer 4:

- Balancing happens per TCP connection, not per HTTP request. `curl` opens a new
  connection each time, so repeated calls alternate between `backend1` and
  `backend2`.
- nginx never parses the payload, so it cannot add HTTP headers. The backend
  therefore reports `x_forwarded_for` as `null`, and it reports `client_ip` as
  the address of the load balancer rather than the address of the real client.

`test-l4-raw.sh` demonstrates the second property directly. It sends the
non-HTTP line `Hello there` through the load balancer with `nc`. The connection
is still forwarded to a backend, because nginx does not care what the bytes mean.
Flask then rejects the payload, which is the expected outcome.

## Experiment 2 — layer 7

The layer 7 load balancer is `lb_l7`, configured by `l7/nginx.conf` and published
on host port 8082. Its configuration uses the `http` block, so nginx terminates
the HTTP request and inspects it. Three `location` rules route by path prefix,
and this list is exhaustive:

| Path prefix | Upstream container |
| --- | --- |
| `/v1/api` | `v1_server` |
| `/v2/api` | `v2_server` |
| `/static` | `static_server` |

Each upstream holds a single server, so there is no balancing within an upstream.
The routing itself is the point of the experiment. A path outside the three
prefixes matches no `location`, so nginx answers 404 without contacting any
backend.

Every rule sets two headers before proxying: `Host`, from the original request;
and `X-Forwarded-For`, extended with the client address. So the backend reports
a non-null `x_forwarded_for` here, and that is the visible contrast with
experiment 1.

## Sandbox organisation

```sh
README.md
Makefile             # up, down, build, restart, logs, ps, clean, and the three tests
docker-compose.yml   # both load balancers and the five backends
backend/
  app.py             # the Flask echo service
  Dockerfile         # python:3.12-slim plus flask
l4/
  nginx.conf         # stream block, round-robin over two backends
l7/
  nginx.conf         # http block, path routing to three backends
test-l4.sh           # five requests to 8081, to watch server_name alternate
test-l4-raw.sh       # a non-HTTP payload to 8081, to prove nginx does not parse it
test-l7.sh           # one request to each of the three routed paths on 8082
```

## Running it

Bring the stack up, then run the tests:

```sh
make build     # build the backend image
make up        # start both load balancers and all five backends
make test-l4   # experiment 1: round-robin
make test-l7   # experiment 2: path routing
make test-l4-raw
make down      # stop everything
```

The backend containers publish no host ports, so they are reachable only through
the load balancers and only from inside the Compose network. That is deliberate,
because it forces every test to go through nginx.

`make logs-l4` and `make logs-l7` follow the containers of one experiment each.
`make clean` removes the containers, the volumes, and the locally built image.

## Prerequisites

The complete list of tools needed on the host is: Docker with the Compose
plugin; `make`; `curl`; `python3`, used only to pretty-print the JSON in the test
scripts; and `nc`, used only by `test-l4-raw.sh`.

## State of the lab

Complete. The backend, its Dockerfile, both nginx configurations, the Compose
file, the three test scripts, and the Makefile are all in place, and the project
was committed on 2026-09-03.

This sandbox has no `notes/` directory, unlike the AWS projects in this repo.
Everything it does is in the two nginx configuration files, and this README
explains both.
