# Build tools for the opmodel.dev site: Node, git and the site's npm packages.
#
# The packages are installed in /work, one directory above where the
# repository is mounted (/work/repo), so Node and Vite find them by walking up
# from the site and the checkout never holds a node_modules directory. The
# Taskfile mounts the repository and runs as the calling user.

FROM node:24-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && git config --system --add safe.directory '*'

WORKDIR /work
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund && npm cache clean --force

ENV PATH=/work/node_modules/.bin:$PATH \
    NODE_MODULES_DIR=/work/node_modules \
    ASTRO_TELEMETRY_DISABLED=1 \
    HOME=/tmp \
    NPM_CONFIG_UPDATE_NOTIFIER=false

WORKDIR /work/repo/site
EXPOSE 4321
