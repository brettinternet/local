# local

A machine-level Traefik broker for local development. One process owns host ports 80 and 443 while any number of Docker Compose projects or host processes register distinct hostnames behind it.

```text
browser / phone / agent
          |
   local broker :80/:443
      /              \
Docker edge proxy   host process
```

The repository is safe to publish: machine-specific routes, domains, certificates, socket paths, ports, and bind settings live only in ignored files. Tracked files contain reserved example names.

## Requirements

- [mise](https://mise.jdx.dev/)

`mise.toml` installs Task, Lima, Colima, the Docker CLI, the Docker Compose plugin, mkcert, and ShellCheck. This matches the repository's supported setup while still allowing an existing Docker Desktop or native Docker daemon.

The default images are Traefik 3.7 and LinuxServer Socket Proxy. Image values can be overridden in `.env`.

## Start the broker

```sh
mise trust
mise install
task init
task docker:start # only when a Docker daemon is not already running
task up
task status
```

The equivalent direct commands are `docker compose up --detach --wait` and `docker compose ps`.

The broker creates a reusable Docker network named `local-broker`. Downstream Compose projects join that network as external consumers.

By default, ports 80 and 443 bind only to `127.0.0.1`. This is deliberate: changing `LOCAL_BROKER_BIND_IP` to `0.0.0.0` exposes registered routes to reachable network clients and should be paired with host firewall and route-level access controls.

Stop it with:

```sh
docker compose down
```

The shared network remains in use while downstream containers are attached, so stop those projects before removing the broker network.

## Private configuration

The following paths are ignored:

- `.env` — bind address, ports, network name, socket path, and image overrides
- `config/*` — Traefik dynamic configuration
- `certs/*` — certificate material and the local certificate name list

Start from the tracked examples:

```sh
task example-config
```

Replace every `example.test` name before use. `example.test` is reserved for documentation and will not provide a working project URL without matching local resolution. Then generate the ignored leaf certificate:

```sh
task certs
```

Never commit a local CA private key. `mkcert` keeps its root key outside this repository; only leaf certificates belong under `certs/`.

## Route a host process

`examples/routes.yaml` shows a file-provider route from `https://app.local.example.test` to a process on host port 3000. The broker supplies `host.docker.internal` on Docker Desktop and Linux Docker Engine.

Copy the example into `config/`, update its hostname and upstream, generate a matching certificate, and ensure the hostname resolves to `127.0.0.1`.

Traefik watches `config/`; an atomic file replacement updates routes without restarting the broker.

## Route another Compose proxy

For a minimally disruptive migration, an existing project-level Traefik can remain responsible for its certificates, HTTP routing, and TCP/mTLS behavior. It stops publishing host ports 80/443, joins `local-broker`, and registers SNI routes with the machine broker. The machine broker passes TLS through unchanged.

See `examples/edge.compose.yaml` for the network and labels. Each downstream environment must use globally unique router/service names, normally derived from a stable environment ID.

A downstream Traefik that also watches the Docker daemon **must constrain its own Docker provider** to labels belonging to that environment. Otherwise it can consume the broker-facing labels on itself or another edge and create recursive or cross-environment routes. A typical per-environment constraint is:

```text
--providers.docker.constraints=Label(`local.stack`,`example-environment-id`)
```

Apply the matching `local.stack` label only to services that the downstream proxy should discover. Do not apply it to the edge proxy carrying `local.broker.enable=true`.

## Direct Docker registration

The broker discovers only containers carrying both labels:

```yaml
labels:
  traefik.enable: "true"
  local.broker.enable: "true"
```

All normal Traefik Docker labels still apply. Attach the target container to the shared network and set:

```yaml
traefik.docker.network: "local-broker"
```

Router and service names are global within this broker. Prefix them with a project/environment identifier.

## Security model

- The socket proxy exposes only read endpoints needed for container discovery and is reachable only on an internal Docker network.
- Traefik never mounts the Docker socket directly.
- Docker container metadata remains sensitive even through a read-only API. Do not attach untrusted containers to the control network.
- `exposedByDefault=false` and the `local.broker.enable=true` constraint make route publication opt-in.
- No dashboard route is published by default.
- No ACME resolver, public tunnel, LAN listener, authentication, or DNS mutation is enabled by default.
- Database and administration ports should stay loopback-only and normally should not be registered with the broker.

Do not publish socket-proxy port 2375 or attach it to the shared ingress network.

## Validation and diagnostics

Run the isolated integration test without disturbing a broker already using ports 80/443:

```sh
task check
```

It starts a temporary broker on Docker-assigned loopback ports and verifies direct HTTPS discovery, TLS passthrough through a downstream edge, HTTP redirection, healthchecks, and cleanup.

Operational diagnostics:

```sh
task status
docker compose logs --tail 100 traefik
docker compose logs --tail 100 socket-proxy
docker network inspect local-broker
```

Traefik has an internal health entrypoint on port 8082. It is used only by the container healthcheck and is not published to the host.

## License

MIT
