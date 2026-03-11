#!/bin/bash

# show alert before stopping the containers
read -p "Are you sure you want to stop all containers? (y/n) "
if [[ "$REPLY" != "y" ]]; then
    echo "Aborting..."
    exit 0
fi

# stop the monitoring stack
echo "Stopping Prometheus, Grafana, Tempo, Cadvisor Monitoring Stack..."
docker compose -f monitoring/docker-compose.yml down

# stop the portainer
echo "Stopping Portainer..."
docker compose -f portainer/docker-compose.yml down

# stop the caddy proxy
echo "Stopping Caddy Proxy..."
docker compose -f caddy/docker-compose.yml down

# remove .env files from each service directory
rm caddy/.env
rm portainer/.env
rm monitoring/.env