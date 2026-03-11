#!/bin/bash

# copy the .env file to each service directory
cp .env caddy/.env
cp .env portainer/.env
cp .env monitoring/.env

# create the public network if it doesn't exist
if ! docker network ls --format '{{.Name}}' | grep -q '^public$'; then
    echo "Creating public network..."
    # might need to change driver to overlay if using swarm mode
    docker network create --driver=bridge public
else
    echo "Public network already exists."
fi

# start the caddy proxy
echo "Starting Caddy Proxy..."
docker compose -f caddy/docker-compose.yml up -d

# start the portainer
echo "Starting Portainer..."
docker compose -f portainer/docker-compose.yml up -d

# start the monitoring stack
echo "Starting Prometheus, Grafana, Tempo, Cadvisor Monitoring Stack..."
docker compose -f monitoring/docker-compose.yml up -d