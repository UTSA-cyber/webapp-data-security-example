# Nomad job: the web app
# ============================================================================
# nginx serving the built Vite SPA, also reverse-proxying /auth/v1 → GoTrue
# and /rest/v1 → PostgREST. The Vite bundle bakes in VITE_SUPABASE_URL and
# VITE_SUPABASE_PUBLISHABLE_KEY at build time — those values must be set
# during the image build (CI) before this jobspec runs.

job "webapp" {
  type = "service"

  group "app" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 80
        to     = 80
      }
    }

    service {
      name     = "webapp"
      provider = "nomad"
      port     = "http"
      check {
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        # Replace with your registry path once CI publishes the image.
        # The image is built from deploy/Dockerfile.app with VITE_*
        # build args pinned to production values.
        image = "ghcr.io/your-org/webapp-data-security:latest"
        ports = ["http"]
      }

      # No Vault stanza: the app container has no secrets. All sensitive
      # values are server-side (GoTrue / PostgREST). The public anon JWT
      # is baked into the build at CI time.

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
