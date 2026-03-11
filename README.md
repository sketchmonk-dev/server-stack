# Server Stack

Complete server initialization stack with:

- **Caddy** (automatic reverse proxy + TLS)
- **Portainer** (Docker management UI)
- **Monitoring stack**: Prometheus, Grafana, Tempo, cAdvisor, and Node Exporter

## Quick Start

```bash
cp .env.example .env
# edit .env (DOMAIN + credentials)
./start.sh
```

Before running `./start.sh`, ensure DNS records for `infra.<DOMAIN>`, `grafana.<DOMAIN>`, and `prometheus.<DOMAIN>` point to your server.

After startup, open:

- `https://infra.<DOMAIN>`
- `https://grafana.<DOMAIN>`
- `https://prometheus.<DOMAIN>`

## Architecture

- `caddy/docker-compose.yml` runs Caddy Docker Proxy on ports `80` and `443`.
- `portainer/docker-compose.yml` publishes Portainer behind Caddy at `infra.<DOMAIN>`.
- `monitoring/docker-compose.yml` runs Prometheus, Grafana, Tempo, cAdvisor, and Node Exporter.
- Shared external Docker network: `public`.

## Prerequisites

Install and verify:

1. **Docker Engine**
2. **Docker Compose** (Compose v2 plugin: `docker compose`)

Quick verification:

```bash
docker --version
docker compose version
```

## Environment Configuration

Edit the root `.env` file (created in Quick Start).

Generate a Caddy-compatible hash for `PROMETHEUS_HASHED_PASSWORD`:

```bash
docker run --rm caddy caddy hash-password --plaintext 'your-password'
```

Copy the output value into `PROMETHEUS_HASHED_PASSWORD`.

Required variables:

```env
DOMAIN=example.com

# Prometheus basic auth (used by Caddy labels)
PROMETHEUS_USER=admin
PROMETHEUS_HASHED_PASSWORD=<caddy-compatible-hash>

# Grafana admin credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=changeme
```

### Domain / DNS requirements

Point these DNS records to your server IP (A/AAAA as needed):

- `infra.<DOMAIN>`
- `grafana.<DOMAIN>`
- `prometheus.<DOMAIN>`

Example when `DOMAIN=example.com`:

- `infra.example.com`
- `grafana.example.com`
- `prometheus.example.com`

## Start Services

The `start.sh` script:

- copies root `.env` into `caddy/.env`, `portainer/.env`, and `monitoring/.env`
- creates Docker network `public` if it does not exist
- starts Caddy, Portainer, and monitoring stack in detached mode

Run:

```bash
chmod +x start.sh stop.sh
./start.sh
```

## Stop Services

The `stop.sh` script:

- asks for confirmation
- stops monitoring, Portainer, and Caddy stacks
- removes copied `.env` files from service folders

Run:

```bash
./stop.sh
```

## Useful Commands

Check running containers:

```bash
docker ps
```

Check compose status per stack:

```bash
docker compose -f caddy/docker-compose.yml ps
docker compose -f portainer/docker-compose.yml ps
docker compose -f monitoring/docker-compose.yml ps
```

View logs:

```bash
docker compose -f caddy/docker-compose.yml logs -f
docker compose -f portainer/docker-compose.yml logs -f
docker compose -f monitoring/docker-compose.yml logs -f
```

## Host an Elysia Backend with OpenTelemetry

Use a separate compose file for your app (example: `apps/api/docker-compose.yml`) and attach it to:

- `public` network (for Caddy ingress)
- `monitoring` network (to reach Tempo/Prometheus)

Example:

```yaml
services:
	api:
		image: oven/bun:1
		container_name: my-elysia-api
		working_dir: /app
		command: ["bun", "run", "start"]
		volumes:
			- ./:/app
		restart: always
		environment:
			- NODE_ENV=production
			- OTEL_SERVICE_NAME=my-elysia-api
			- OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4318
		labels:
			caddy: api.${DOMAIN}
			caddy.handle.reverse_proxy: "{{upstreams http 3000}}"
		networks:
			- public
			- monitoring

networks:
	public:
		external: true
	monitoring:
		external: true
		name: monitoring
```

### OpenTelemetry tracing setup (Elysia)

Install dependencies in your app:

```bash
bun add @opentelemetry/api @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-http
```

Create `src/telemetry.ts`:

```ts
import { NodeSDK } from '@opentelemetry/sdk-node'
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'

const traceExporter = new OTLPTraceExporter({
	url: `${process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://tempo:4318'}/v1/traces`,
})

const sdk = new NodeSDK({
	traceExporter,
	instrumentations: [getNodeAutoInstrumentations()],
})

await sdk.start()
```

Import telemetry before creating the Elysia app in your entrypoint:

```ts
import './telemetry'
import { Elysia } from 'elysia'

new Elysia()
	.get('/health', () => 'ok')
	.listen(3000)
```

### (Optional) Prometheus metrics from your app

If your app exposes `/metrics` (for example on port `9464`), add a scrape job in `monitoring/config/prometheus/prometheus.yml`:

```yaml
- job_name: "my-elysia-api"
	static_configs:
		- targets: ["my-elysia-api:9464"]
	labels:
		service: "my-elysia-api"
```

Then restart Prometheus:

```bash
docker compose -f monitoring/docker-compose.yml up -d prometheus
```

### Verify in Grafana

- Open `https://grafana.<DOMAIN>`
- Go to **Explore** → select **Tempo** datasource
- Filter by `service.name = my-elysia-api`
- You should see traces and service graph data (Tempo is already wired to Prometheus in this stack)

## Project Structure

```text
.
├── caddy/
├── monitoring/
├── portainer/
├── scripts/
├── start.sh
└── stop.sh
```

## Notes

- This setup expects a valid public DNS configuration before HTTPS endpoints become reachable.
- Caddy obtains/manages TLS certificates automatically for configured domains.
