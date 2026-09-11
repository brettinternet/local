# LAN access

The broker binds to loopback by default. LAN binding exposes every registered route, so use it only
on a trusted network and restrict inbound TCP 80/443 with the host firewall.

## 1. Bind the broker

Prefer the developer machine's stable LAN address over all interfaces:

```dotenv
# .env
LOCAL_BROKER_BIND_IP=192.168.1.50
```

Use `0.0.0.0` only when the address changes frequently; it also listens on VPN and other network
interfaces.

```sh
task down
task up
```

Keep databases, debug ports, and administration services bound to `127.0.0.1` or protected with
authentication.

## 2. Configure LAN DNS

Point each development zone at the developer machine. A wildcard is useful for worktrees, but add
the zone apex separately:

```text
local.example.test    A  192.168.1.50
*.local.example.test  A  192.168.1.50
```

Configure this in the router or trusted LAN DNS server. If DNS administration is unavailable, add
each exact hostname to the client; phones generally require a DNS server. Allowlist the zone if the
resolver blocks private addresses through DNS-rebinding protection.

Keep each worktree hostname in one label so a certificate for `*.local.example.test` covers it.

## 3. Trust HTTPS certificates

All mkcert leaf certificates generated on the developer machine use its local CA. Find the CA with:

```sh
mise exec mkcert -- mkcert -CAROOT
```

Install only `rootCA.pem` on each device or agent. Never copy `rootCA-key.pem`.

- iOS/iPadOS: install the profile, then enable full trust under **Certificate Trust Settings**.
- Android: install it as a CA certificate. Some applications reject user-installed CAs by policy.
- Agents and CLI clients: add it to the process or OS trust store.

For broker-terminated routes, include the hostname in `certs/domains.txt` and run `task certs`. For
TLS-passthrough routes, regenerate the project edge certificate instead.

## 4. Verify from another device

```sh
curl --fail https://app.local.example.test/
```

If DNS is not ready, verify from a LAN computer with:

```sh
curl --resolve app.local.example.test:443:192.168.1.50 \
  https://app.local.example.test/
```

Remote agents use the same DNS and trust setup. TCP/mTLS routes remain end-to-end encrypted because
the broker passes their TLS stream through unchanged.

To disable LAN access, restore `LOCAL_BROKER_BIND_IP=127.0.0.1` and restart the broker.
