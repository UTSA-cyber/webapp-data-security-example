# =========================================================================
# Multi-stage build for the Vite React app.
#
# Vite bakes VITE_* env vars into the JS bundle at build time, so the build
# stage needs them as ARGs. The runtime stage is just nginx serving static
# files with an SPA fallback.
# =========================================================================

# ---- Stage 1: build ------------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /app

# Vite env vars baked into the bundle at build time
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_PUBLISHABLE_KEY
ENV VITE_SUPABASE_URL=${VITE_SUPABASE_URL}
ENV VITE_SUPABASE_PUBLISHABLE_KEY=${VITE_SUPABASE_PUBLISHABLE_KEY}

# Install dependencies first so we can cache the layer.
# Build context is the project root; the web app lives in frontend/.
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

# Build
COPY frontend/ ./
RUN npm run build

# ---- Stage 2: serve ------------------------------------------------------
FROM nginx:1.27-alpine AS serve

COPY --from=build /app/dist /usr/share/nginx/html
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Drop privileges where possible — nginx:alpine's default user is root,
# but the worker processes run as `nginx`.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/healthz >/dev/null || exit 1
