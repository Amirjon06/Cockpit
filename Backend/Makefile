.PHONY: help up down logs init test fmt shell

help:
	@echo "up     - build & start the stack (api, cockpit-db, vectordb, minio)"
	@echo "init   - create schemas in cockpit-db + vectordb (run once after up)"
	@echo "down   - stop the stack"
	@echo "logs   - tail the api logs"
	@echo "test   - run pytest inside the api container"
	@echo "prod   - start with the production overlay (shared octopilot PG)"

up:
	docker compose up -d --build

init:
	docker compose exec cockpit-api python -m scripts.init_databases

down:
	docker compose down

logs:
	docker compose logs -f cockpit-api

test:
	docker compose exec cockpit-api pytest -q

prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
