# Remote sharing

Use a Cloudflare Quick Tunnel when you want to share one HTTP(S) development route temporarily without exposing the whole broker to the LAN or changing DNS.

Start the broker and the project, then pass the route's existing hostname:

```sh
task up
task share HOST=app.local.example.test
```

`cloudflared` prints a random `https://...trycloudflare.com` URL. Send that URL to your friend and leave the task running. Press Ctrl-C to remove the tunnel; running `task down` is not required.

The task connects to the broker's configured HTTPS listener and sends the selected hostname as both TLS server name and HTTP host. Traefik therefore uses the same route and certificate as local access. Only that hostname is selected; other broker routes are not addressable through the generated URL.

## Limits and security

- The generated URL is public and has no authentication. Share only an application that is safe to expose, avoid sensitive data, and stop the task when finished.
- Quick Tunnels are intended for temporary testing. The URL changes on every run and availability is not guaranteed.
- This supports HTTP and WebSocket applications. It does not preserve end-to-end TCP, TLS, or mutual-TLS semantics because Cloudflare terminates the public connection.
- Application redirects, cookie domains, CORS rules, and generated absolute URLs may need to accept the `trycloudflare.com` origin.
- The broker must already be running, and its local certificate must be trusted by the machine running `cloudflared`.

For stable hostnames, access policies, or recurring sharing, configure a named Cloudflare Tunnel separately rather than adding public exposure to the broker's default lifecycle.
