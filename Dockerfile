# syntax=docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed

# The constant --platform on the build stage is the point rather than an
# oversight, hence the skip above. See the note on that stage.

# ---------------------------------------------------------------------------
# Build stage.
#
# Pinned to amd64 because Flutter ships an x64 Linux SDK and nothing else.
# That is free on an amd64 host and harmless anywhere else: this stage emits
# JavaScript, wasm and assets, none of it architecture-specific, so the
# runtime stage below still builds natively for whatever the host happens to be.
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 debian:bookworm-slim AS build

# Bump these together — the checksum comes from
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
ARG FLUTTER_VERSION=3.44.9
ARG FLUTTER_SHA256=a9120fa4a01048bdef438ddc3a2d4b7389662ea98a95db86eeaf10382bc4efcb

# Set this if the app is served from a subpath rather than a domain root,
# e.g. --build-arg BASE_HREF=/score/ — leading and trailing slash both required.
ARG BASE_HREF=/

# With CI gone, the suite runs here and a red test fails the deploy.
# Pass --build-arg RUN_TESTS=0 to skip it.
ARG RUN_TESTS=1

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Unpacks the Dart SDK and the web engine into this layer so neither is
# fetched again on a source-only rebuild.
RUN flutter --version && flutter precache --web

WORKDIR /app

# Dependencies resolve from the lockfile alone, so this layer is reused across
# every change that is not a dependency change.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# *.g.dart is gitignored and kept out of the build context, so the drift code
# is generated here, against the dependencies this image actually resolved.
RUN dart run build_runner build --delete-conflicting-outputs

RUN if [ "${RUN_TESTS}" = "1" ]; then flutter test; fi

# --no-web-resources-cdn is what makes this a self-contained deployment. Left on
# its default, the loader ignores the canvaskit/ directory sitting right here
# and pulls the engine from www.gstatic.com instead — so the app would need
# Google reachable to render at all, and every byte below would be dead weight.
RUN flutter build web --release --no-web-resources-cdn --base-href "${BASE_HREF}"

# Trim, then precompress. The .symbols files are stack-trace maps for
# `flutter symbolize`, several MB the browser never asks for. Everything
# compressible gets a sibling .gz for nginx's gzip_static, which keeps 7 MB of
# engine wasm off the CPU on every cold load.
RUN find build/web -name '*.symbols' -delete \
 && find build/web -type f \
      \( -name '*.js' -o -name '*.wasm' -o -name '*.json' -o -name '*.css' \
         -o -name '*.html' -o -name '*.svg' -o -name '*.ttf' -o -name '*.otf' \
         -o -name 'NOTICES' \) \
      -exec gzip -9 -k {} +

# ---------------------------------------------------------------------------
# Runtime stage: static files and an nginx to hand them out. Nothing else.
# ---------------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.29-alpine AS serve

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

# Non-root nginx, so an unprivileged port. Point Coolify at this one.
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || exit 1
