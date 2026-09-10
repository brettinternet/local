# Project practices

## Keep resolved values local

| Location | Track                                | Ignore                               |
| -------- | ------------------------------------ | ------------------------------------ |
| Project  | Parameterized Compose, setup command | Environment ID, hostnames, ports     |
| Broker   | Runtime and examples                 | Routes, certificate names, leaf keys |

## Name the environment once

```text
DEV_ENV_ID = <project>-<worktree-slug>-<short-hash>
router      = <DEV_ENV_ID>-<service>
volume      = scoped by COMPOSE_PROJECT_NAME
hostname    = <service>-<worktree-slug>-<short-hash>.<zone>
```

Use the same ID for Compose, Traefik, logs, and cleanup. Persist it in the worktree's ignored
`.env`; do not recalculate it from the current branch on every start.

## Keep Compose isolated

```yaml
name: ${COMPOSE_PROJECT_NAME:-example-main}

services:
    database:
        ports:
            - 127.0.0.1:${POSTGRES_PORT:?}:5432
        volumes:
            - database-data:/var/lib/postgresql/data

volumes:
    database-data:
```

- Do not set `container_name`.
- Do not use fixed host ports across worktrees.
- Do not publish ports used only by containers.
- Bind databases and debug ports to `127.0.0.1`.
- Attach only routed services or the project edge to `local-broker`.

## Choose one TLS owner

```text
direct HTTP route  -> broker terminates TLS
edge/TCP route     -> project terminates TLS
```

Never commit CA keys or machine certificates. Keep broker certificate names and leaf keys under
ignored `certs/`.

## Make sharing explicit

```text
frontend     own web process; use a selected API
isolated     own Compose project and volumes
shared-infra shared daemon; separate database, bucket, namespace, stream, and index
```

Do not run branch migrations against main's database. A shared container is not shared data.

## Keep exposure narrow

```dotenv
LOCAL_BROKER_BIND_IP=127.0.0.1 # default
# LOCAL_BROKER_BIND_IP=0.0.0.0 # deliberate LAN exposure
```

LAN binding exposes every reachable route unless that route has an allowlist or authentication.
Keep dashboards, mail viewers, databases, and storage consoles local-only.

## Make lifecycle observable

```text
create worktree -> write .env -> start dependencies -> start processes
remove worktree -> stop processes -> compose down -> release routes and ports
```

Use a supervisor for host processes. Give humans and agents the same status, logs, restart, and URL
commands. Do not hide long-running processes in setup scripts.
