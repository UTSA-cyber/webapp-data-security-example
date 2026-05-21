# Vault policy: webapp-authentik
# Capabilities: read-only on Authentik's secrets. Applied to the
# authentik-db, authentik-redis, authentik-server, and authentik-worker
# task workload identities.

path "secret/data/webapp/authentik" {
  capabilities = ["read"]
}
