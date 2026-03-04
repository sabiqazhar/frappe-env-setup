#!/bin/bash

# DO NOT CHANGE, JUST COPY THIS
docker compose --env-file ./.env.core-dev up -d --no-recreate
docker exec -e "TERM=xterm-256color" -it frappe-core-dev bash
