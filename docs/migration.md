# Migrate an existing project

## 1. Record the current contract

```text
hostnames:
TLS owner:
HTTP routes:
TCP/SNI routes:
host processes and ports:
published container ports:
stateful services and volumes:
```

Keep behavior unchanged during the first migration.

## 2. Add environment identity

```dotenv
DEV_ENV_ID=example-main
COMPOSE_PROJECT_NAME=example-main
LOCAL_BROKER_NETWORK=local-broker
APP_HOST=app.local.example.test
```

Generate unique values for linked worktrees. Keep main's existing hostname when possible.

## 3. Remove collisions

- Remove project host mappings for `80:80` and `443:443`.
- Remove unnecessary published ports.
- Make required host ports environment-specific and loopback-only.
- Remove `container_name`.
- Keep named volumes scoped by `COMPOSE_PROJECT_NAME`.

## 4. Connect the route

Use direct registration for a single container service. Use edge passthrough when preserving an
existing proxy or TCP/mTLS path. Follow [project setup](project-setup.md).

## 5. Constrain discovery

An existing project proxy must discover only containers labeled for its `DEV_ENV_ID`. The broker
must discover only containers labeled `local.broker.enable=true`.

Inspect both proxy configurations before starting them. An unconstrained project proxy can import
another environment's routes or route to itself.

## 6. Add worktree setup

The setup command writes the ignored `.env` once. It must refuse to use main's
`COMPOSE_PROJECT_NAME` from a linked worktree and must not overwrite an existing file.

The teardown command stops supervised processes before `docker compose down`.

## 7. Prove coexistence

```text
[ ] main starts
[ ] second project starts beside main
[ ] linked worktree starts beside both
[ ] every hostname reaches the intended environment
[ ] stopping one environment leaves the others healthy
[ ] no database or debug port listens on a LAN interface
[ ] project proxy cannot see another environment's containers
[ ] TCP/mTLS paths still terminate at the original service
```
