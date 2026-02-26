#!/bin/bash

# DO NOT CHANGE, JUST COPY THIS
docker-compose --env-file ./.env.local-dev up -d --no-recreate
docker exec -e "TERM=xterm-256color" -it frappe-local-dev bash
