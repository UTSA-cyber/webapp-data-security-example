# Nomad job: Authentik (SSO IdP) + its own Postgres + Redis
# ============================================================================
# Authentik's data is intentionally separate from the app's Postgres so the
# IdP can be upgraded/restored independently.

job "authentik" {
  type = "service"

  group "db" {
    count = 1

    network {
      mode = "bridge"
      port "pg" { to = 5432 }
    }

    volume "authentik-db-data" {
      type      = "host"
      source    = "authentik-db-data"
      read_only = false
    }

    service {
      name     = "authentik-db"
      provider = "nomad"
      port     = "pg"
    }

    task "postgres" {
      driver = "docker"

      vault {
        policies = ["webapp-authentik"]
      }

      config {
        image = "postgres:16-alpine"
        ports = ["pg"]
      }

      volume_mount {
        volume      = "authentik-db-data"
        destination = "/var/lib/postgresql/data"
      }

      template {
        destination = "secrets/db.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/authentik" }}
POSTGRES_USER     = "authentik"
POSTGRES_DB       = "authentik"
POSTGRES_PASSWORD = "{{ .Data.data.postgres_password }}"
{{ end }}
EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  group "redis" {
    count = 1

    network {
      mode = "bridge"
      port "redis" { to = 6379 }
    }

    service {
      name     = "authentik-redis"
      provider = "nomad"
      port     = "redis"
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:7-alpine"
        args  = ["--save", "60", "1", "--loglevel", "warning"]
        ports = ["redis"]
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  group "server" {
    count = 1

    network {
      mode = "bridge"
      port "http" { to = 9000 }
    }

    service {
      name     = "authentik-server"
      provider = "nomad"
      port     = "http"
      check {
        type     = "http"
        path     = "/-/health/live/"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "server" {
      driver = "docker"

      vault {
        policies = ["webapp-authentik"]
      }

      config {
        image = "ghcr.io/goauthentik/server:2024.10"
        args  = ["server"]
        ports = ["http"]
      }

      template {
        destination = "secrets/authentik.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/authentik" }}
AUTHENTIK_REDIS__HOST              = "{{ range nomadService "authentik-redis" }}{{ .Address }}{{ end }}"
AUTHENTIK_POSTGRESQL__HOST         = "{{ range nomadService "authentik-db" }}{{ .Address }}{{ end }}"
AUTHENTIK_POSTGRESQL__USER         = "authentik"
AUTHENTIK_POSTGRESQL__NAME         = "authentik"
AUTHENTIK_POSTGRESQL__PASSWORD     = "{{ .Data.data.postgres_password }}"
AUTHENTIK_SECRET_KEY               = "{{ .Data.data.secret_key }}"
AUTHENTIK_BOOTSTRAP_EMAIL          = "{{ .Data.data.bootstrap_email }}"
AUTHENTIK_BOOTSTRAP_PASSWORD       = "{{ .Data.data.bootstrap_password }}"
AUTHENTIK_BOOTSTRAP_TOKEN          = "{{ .Data.data.bootstrap_token }}"
AUTHENTIK_ERROR_REPORTING__ENABLED = "false"
{{ end }}
EOF
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  group "worker" {
    count = 1

    task "worker" {
      driver = "docker"

      vault {
        policies = ["webapp-authentik"]
      }

      config {
        image = "ghcr.io/goauthentik/server:2024.10"
        args  = ["worker"]
      }

      template {
        destination = "secrets/authentik.env"
        env         = true
        data        = <<EOF
{{ with secret "secret/data/webapp/authentik" }}
AUTHENTIK_REDIS__HOST              = "{{ range nomadService "authentik-redis" }}{{ .Address }}{{ end }}"
AUTHENTIK_POSTGRESQL__HOST         = "{{ range nomadService "authentik-db" }}{{ .Address }}{{ end }}"
AUTHENTIK_POSTGRESQL__USER         = "authentik"
AUTHENTIK_POSTGRESQL__NAME         = "authentik"
AUTHENTIK_POSTGRESQL__PASSWORD     = "{{ .Data.data.postgres_password }}"
AUTHENTIK_SECRET_KEY               = "{{ .Data.data.secret_key }}"
AUTHENTIK_ERROR_REPORTING__ENABLED = "false"
{{ end }}
EOF
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }
}
