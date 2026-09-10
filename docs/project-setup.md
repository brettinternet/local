# Connect a project

Choose one route model.

| Project shape                        | Route model      | TLS ends at   |
| ------------------------------------ | ---------------- | ------------- |
| New containerized service            | Direct           | Broker        |
| Existing project proxy or TCP/mTLS   | Edge passthrough | Project proxy |
| Host process without a project proxy | File route       | Broker        |

Do not register the same hostname with more than one model. TCP routers run before HTTP routers.

## Environment values

Generate an ignored `.env` for each checkout or worktree:

```dotenv
DEV_ENV_ID=example-fix-login-a1b2
COMPOSE_PROJECT_NAME=example-fix-login-a1b2
LOCAL_BROKER_NETWORK=local-broker
APP_HOST=app-fix-login-a1b2.local.example.test
DOCS_HOST=docs-fix-login-a1b2.local.example.test
```

`DEV_ENV_ID` must be stable, DNS-safe, and unique on the machine. Add a short hash; branch names
alone collide.

Keep worktree names in one DNS label. A certificate for `*.local.example.test` covers
`app-fix-login-a1b2.local.example.test`, not `app.fix-login-a1b2.local.example.test`.

## Direct container route

Use this for a new HTTP service:

```yaml
services:
    app:
        image: example/app
        networks: [default, local-broker]
        labels:
            - traefik.enable=true
            - local.broker.enable=true
            - traefik.docker.network=${LOCAL_BROKER_NETWORK:-local-broker}
            - traefik.http.routers.${DEV_ENV_ID:?}-app.rule=Host(`${APP_HOST:?}`)
            - traefik.http.routers.${DEV_ENV_ID:?}-app.entrypoints=websecure
            - traefik.http.routers.${DEV_ENV_ID:?}-app.tls=true
            - traefik.http.routers.${DEV_ENV_ID:?}-app.service=${DEV_ENV_ID:?}-app
            - traefik.http.services.${DEV_ENV_ID:?}-app.loadbalancer.server.port=3000

networks:
    local-broker:
        external: true
        name: ${LOCAL_BROKER_NETWORK:-local-broker}
```

The service listens on `0.0.0.0:3000` inside its container. It does not publish a host port. Add
`APP_HOST` or its wildcard to the broker certificate in `certs/domains.txt`, then run
`task certs` in the broker checkout. Load `/certs/local.pem` and `/certs/local-key.pem` once in
broker configuration; `examples/routes.yaml` shows the `tls.certificates` block.

## Existing edge proxy

Use passthrough when a project already owns HTTP routing, certificates, or TCP/mTLS behavior.
Delete its host mappings for ports 80 and 443, then connect it to the broker:

```yaml
services:
    edge:
        environment:
            TRAEFIK_PROVIDERS_DOCKER_CONSTRAINTS: "Label(`local.stack`,`${DEV_ENV_ID:?}`)"
        networks: [default, local-broker]
        labels:
            - traefik.enable=true
            - local.broker.enable=true
            - traefik.docker.network=${LOCAL_BROKER_NETWORK:-local-broker}
            - traefik.tcp.routers.${DEV_ENV_ID:?}-edge.rule=HostSNI(`${APP_HOST:?}`) || HostSNI(`${DOCS_HOST:?}`)
            - traefik.tcp.routers.${DEV_ENV_ID:?}-edge.entrypoints=websecure
            - traefik.tcp.routers.${DEV_ENV_ID:?}-edge.tls.passthrough=true
            - traefik.tcp.routers.${DEV_ENV_ID:?}-edge.service=${DEV_ENV_ID:?}-edge
            - traefik.tcp.services.${DEV_ENV_ID:?}-edge.loadbalancer.server.port=443

    app:
        labels:
            traefik.enable: "true"
            local.stack: "${DEV_ENV_ID:?}"

networks:
    local-broker:
        external: true
        name: ${LOCAL_BROKER_NETWORK:-local-broker}
```

Apply `local.stack=${DEV_ENV_ID}` to every service the project proxy should discover. Do not apply
it to the edge proxy. This prevents the edge from reading its broker-facing labels and routing back
to itself.

The project proxy keeps its certificate. The broker forwards the TLS stream unchanged.

## Host process route

Create an ignored file in the broker checkout, such as `config/example-fix-login.yaml`:

```yaml
http:
    routers:
        example-fix-login-app:
            rule: Host(`app-fix-login-a1b2.local.example.test`)
            entryPoints: [websecure]
            service: example-fix-login-app
            tls: {}

    services:
        example-fix-login-app:
            loadBalancer:
                servers:
                    - url: http://host.docker.internal:43120
```

The broker reloads the file automatically. The process must be reachable from the broker container;
see the native Linux warning in the main README.

## Verify

```sh
# Broker checkout
task up

# Project checkout
docker compose config --quiet
docker compose up --detach

curl --fail https://app-fix-login-a1b2.local.example.test/
```

Run main and one linked worktree together. Both URLs must return the correct checkout. Then stop the
worktree and confirm its route disappears without affecting main.
