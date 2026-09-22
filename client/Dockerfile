# ==============================================================================
# Multi-stage Dockerfile for Flutter Web Distribution
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Build Flutter Web bundle
# ------------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# ------------------------------------------------------------------------------
# Stage 2: Serve via Lightweight Nginx
# ------------------------------------------------------------------------------
FROM nginx:alpine AS runner

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
