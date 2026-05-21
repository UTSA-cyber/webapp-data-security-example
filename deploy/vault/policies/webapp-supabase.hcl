# Vault policy: webapp-supabase
# Capabilities: read-only on the three secrets needed by the supabase job.
# Applied to Nomad workload identities for the postgres, gotrue, migrator,
# and rest tasks.

path "secret/data/webapp/postgres" {
  capabilities = ["read"]
}

path "secret/data/webapp/jwt" {
  capabilities = ["read"]
}

path "secret/data/webapp/authentik-oidc" {
  capabilities = ["read"]
}
