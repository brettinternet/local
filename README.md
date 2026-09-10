# local

A machine-level Traefik broker for local development. One process owns host ports 80 and 443. Docker Compose projects and host processes register distinct hostnames behind it.

```text
browser / phone / agent
          |
   local broker :80/:443
      /              \
Docker edge proxy   host process
```

Machine-specific routes, domains, certificates, socket paths, ports, and bind settings belong in ignored files. Tracked files use reserved example names.

## Requirements

- [mise](https://mise.jdx.dev/)

`mise.toml` installs Task, Hum, Lefthook, Gitleaks, Prettier, Lima, Colima, the Docker CLI, the Docker Compose plugin, mkcert, and ShellCheck. This is the supported setup, but existing Docker Desktop and native Docker daemons also work.

Default images:

```text
Traefik 3.7
LinuxServer Socket Proxy
```

Override image values in `.env`.

## Start the broker

```sh
mise trust
mise install
task init
task docker:start # only when a Docker daemon is not already running
task up
task status
```

`task up` starts the broker under Hum for supervision.

```sh
hum status
hum logs broker
```

The broker creates the reusable external Docker network `local-broker`. Downstream Compose projects join it as consumers.

The safe default binds ports 80 and 443 to loopback:

```dotenv
LOCAL_BROKER_BIND_IP=127.0.0.1
```

Binding to `0.0.0.0` exposes registered routes to reachable network clients. Pair it with host firewall and route-level access controls.

Stop the broker with:

```sh
task down
```

The shared network remains in use while downstream containers are attached. Stop those projects before removing the broker network.

## Private configuration

Ignored paths:

```text
.env       bind address, ports, network name, socket path, image overrides
config/*   Traefik dynamic configuration
certs/*    certificate material and the local certificate name list
```

Create the example files:

```sh
task example-config
```

Replace every `example.test` name before use. `example.test` is reserved for documentation and does not provide a working project URL without matching local resolution.

Generate the ignored leaf certificate:

```sh
task certs
```

Never commit a local CA private key. `mkcert` stores its root key outside this repository. Only leaf certificates belong under `certs/`.

## Connect projects

- [Project setup](docs/project-setup.md) — direct routes, edge passthrough, and host processes
- [Project practices](docs/practices.md) — identity, ports, data, TLS, exposure, and lifecycle
- [Migration checklist](docs/migration.md) — move an existing stack without changing behavior

## Route a host process

`examples/routes.yaml` demonstrates a file-provider route:

```text
https://app.local.example.test
        -> host.docker.internal:3000
```

The broker supplies `host.docker.internal` on Docker Desktop and Linux Docker Engine.

The upstream process must listen on an interface reachable from the Docker VM or bridge. Docker Desktop and Colima provide host forwarding. On native Linux, a process bound only to host `127.0.0.1` is not reachable through the bridge gateway.

Prefer direct Docker registration. Otherwise, bind the process deliberately to a reachable host interface and protect it with the host firewall.

```sh
cp examples/routes.yaml config/routes.yaml
# Update the hostname and upstream.
task certs
# Ensure the hostname resolves to 127.0.0.1.
```

Traefik watches `config/`. Atomic file replacement updates routes without restarting the broker.

## Route another Compose proxy

A project-level Traefik can remain responsible for certificates, HTTP routing, and TCP/mTLS behavior. For a minimally disruptive migration:

1. Stop publishing host ports 80 and 443.
2. Join the project proxy to `local-broker`.
3. Register SNI routes with the machine broker.
4. Let the machine broker pass TLS through unchanged.

See `examples/edge.compose.yaml` for the network and labels. Router and service names must be globally unique within this broker. Derive them from a stable environment ID.

If the downstream Traefik watches Docker, constrain its Docker provider to that environment's labels. Otherwise, it can consume broker-facing labels on itself or another edge and create recursive or cross-environment routes.

The example uses:

```yaml
TRAEFIK_PROVIDERS_DOCKER_CONSTRAINTS: "Label(`local.stack`,`example-environment`)"
```

If the existing edge sets the same option on its command line, update that value instead:

```text
--providers.docker.constraints=Label(`local.stack`,`example-environment-id`)
```

Apply the matching `local.stack` label only to services the downstream proxy should discover. Do not apply it to the edge proxy carrying `local.broker.enable=true`.

## Direct Docker registration

The broker discovers only containers with both labels:

```yaml
labels:
    traefik.enable: "true"
    local.broker.enable: "true"
```

Normal Traefik Docker labels still apply. Attach the target container to the shared network:

```yaml
traefik.docker.network: "local-broker"
```

Router and service names are global within this broker. Prefix them with a project or environment identifier.

## Security model

```text
Docker socket
    -> read-only socket proxy
    -> internal Docker network
    -> Traefik
```

- The socket proxy exposes only read endpoints needed for container discovery.
- The socket proxy is reachable only on an internal Docker network.
- Traefik never mounts the Docker socket directly.
- Docker container metadata remains sensitive through a read-only API. Do not attach untrusted containers to the control network.
- `exposedByDefault=false` and the `local.broker.enable=true` constraint make route publication opt-in.
- No dashboard route is published by default.
- No ACME resolver, public tunnel, LAN listener, authentication, or DNS mutation is enabled by default.
- Keep database and administration ports loopback-only. Normally, do not register them with the broker.

Do not publish socket-proxy port 2375 or attach it to the shared ingress network.

## Validation and diagnostics

Run the isolated integration test without disturbing a broker already using ports 80 and 443:

```sh
task check
```

It starts a temporary broker on Docker-assigned loopback ports and verifies:

- direct HTTPS discovery
- TLS passthrough through a downstream edge
- HTTP redirection
- healthchecks
- cleanup

Operational diagnostics:

```sh
task status
docker compose logs --tail 100 traefik
docker compose logs --tail 100 socket-proxy
docker network inspect local-broker
```

Traefik's internal health entrypoint listens on port 8082. The container healthcheck uses it; the port is not published to the host.

## License

MIT
