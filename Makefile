ENV_FILE=.env.core-dev
CONTAINER=frappe-core-dev

default: shell

.PHONY: up down restart shell logs ps

up:
	docker compose --env-file $(ENV_FILE) up -d --no-recreate

down:
	docker compose --env-file $(ENV_FILE) down

restart:
	docker compose --env-file $(ENV_FILE) down
	docker compose --env-file $(ENV_FILE) up -d
	docker exec -e TERM=xterm-256color -it $(CONTAINER) bash

shell:
	docker compose --env-file $(ENV_FILE) up -d --no-recreate
	docker exec -e TERM=xterm-256color -it $(CONTAINER) bash

logs:
	docker compose --env-file $(ENV_FILE) logs -f

ps:
	docker compose --env-file $(ENV_FILE) ps
