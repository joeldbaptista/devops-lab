.PHONY: up down build restart logs logs-l4 logs-l7 ps clean \
	test-l4 test-l7 test-l4-raw

up:
	docker compose up -d

build:
	docker compose build

down:
	docker compose down

restart: down up

logs:
	docker compose logs -f

logs-l4:
	docker compose logs -f lb_l4 backend1 backend2

logs-l7:
	docker compose logs -f lb_l7 v1_server v2_server static_server

ps:
	docker compose ps

clean:
	docker compose down -v --rmi local

test-l4:
	bash test-l4.sh

test-l7:
	bash test-l7.sh

test-l4-raw:
	bash test-l4-raw.sh
