# Vault setup for the webapp deployment

Defines the KV v2 paths the Nomad jobs read and the policies that grant access.

## KV layout

All secrets live under `secret/data/webapp/` (KV v2 mount at `secret/`). Four
keys, each scoped to one concern:

| Path | Fields | Read by |
|---|---|---|
| `secret/data/webapp/postgres` | `password` | supabase job (postgres, gotrue, migrator, rest) |
| `secret/data/webapp/jwt` | `jwt_secret`, `anon_key`, `service_role_key` | supabase job (gotrue, rest) |
| `secret/data/webapp/authentik-oidc` | `client_id`, `client_secret` | supabase job (gotrue) |
| `secret/data/webapp/authentik` | `postgres_password`, `secret_key`, `bootstrap_email`, `bootstrap_password`, `bootstrap_token` | authentik job |

The split mirrors blast radius: a compromised supabase workload identity
cannot read Authentik's bootstrap secrets, and vice versa.

## Bootstrap

```sh
# Enable KV v2 if not already
vault secrets enable -path=secret -version=2 kv

# Apply policies
vault policy write webapp-supabase  policies/webapp-supabase.hcl
vault policy write webapp-authentik policies/webapp-authentik.hcl

# Seed the values (generate fresh secrets for each environment)
vault kv put secret/webapp/postgres \
  password="$(openssl rand -hex 24)"

vault kv put secret/webapp/jwt \
  jwt_secret="$(openssl rand -hex 32)" \
  anon_key="<JWT signed with jwt_secret, role=anon>" \
  service_role_key="<JWT signed with jwt_secret, role=service_role>"

vault kv put secret/webapp/authentik-oidc \
  client_id="webapp-client" \
  client_secret="$(openssl rand -hex 32)"

vault kv put secret/webapp/authentik \
  postgres_password="$(openssl rand -hex 24)" \
  secret_key="$(openssl rand -hex 50)" \
  bootstrap_email="admin@example.com" \
  bootstrap_password="$(openssl rand -hex 16)" \
  bootstrap_token="$(openssl rand -hex 32)"
```

## Nomad ↔ Vault integration

Each task block in the Nomad jobspecs declares which policy it needs:

```hcl
vault {
  policies = ["webapp-supabase"]
}
```

Nomad's workload identity feature (Nomad 1.7+, no token files required)
authenticates each task to Vault automatically. The `template {}` blocks
in the jobspecs render secrets into env files that the container reads on
startup.

Required Nomad agent config:

```hcl
vault {
  enabled          = true
  address          = "https://vault.example.com"
  default_identity {
    aud = ["vault.io"]
    ttl = "1h"
  }
}
```

And in Vault, configure the JWT auth method to trust Nomad's signed identities:

```sh
vault auth enable jwt
vault write auth/jwt/config \
  jwks_url="https://nomad.example.com/.well-known/jwks.json"
vault write auth/jwt/role/nomad-workloads \
  role_type=jwt \
  bound_audiences=vault.io \
  user_claim=/nomad_job_id \
  user_claim_json_pointer=true \
  token_policies=webapp-supabase,webapp-authentik
```

(Adjust the role binding so each job gets only the policy it needs.)

## Generating the Supabase anon and service_role JWTs

These are JWTs signed by `jwt_secret` with role claims:

```sh
JWT_SECRET="$(vault kv get -field=jwt_secret secret/webapp/jwt)"

ANON_PAYLOAD='{"role":"anon","iss":"supabase","iat":1700000000,"exp":2000000000}'
ANON_JWT=$(echo -n "$ANON_PAYLOAD" | jose-util sign --alg HS256 --key "$JWT_SECRET")

# Repeat for service_role with "role":"service_role"
```

The anon JWT also becomes the `VITE_SUPABASE_PUBLISHABLE_KEY` baked into
the frontend bundle at CI build time.
