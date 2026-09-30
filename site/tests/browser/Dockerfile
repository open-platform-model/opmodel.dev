# QA image for the opmodel.dev site: Chromium driven by Playwright for Python
# (screenshots, the search smoke test) and axe-core (the accessibility smoke
# test). Kept apart from the build image, so the site build carries no
# browser. Built with no context (docker build -t <tag> - < this file) and
# tagged opmodel-dev-qa:<first 12 hex of the sha256 of this file>
# (site/scripts/run-in-image.sh qa-image); the test scripts are read from the
# mounted repo at run time, so they are not part of the image.
#
# Every input is pinned: the base image by digest (its browsers match
# Playwright 1.63.0), the Python wheels by version and hash, and axe-core by
# the SHA-256 of its npm registry tarball, fetched with curl (no npm).
FROM mcr.microsoft.com/playwright/python:v1.63.0-noble@sha256:72bd171a9ffc2b4b59532aaa6210e21014d07093120dc25528870c0b840da1f0
ARG AXE_VERSION=4.10.3
ARG AXE_SHA256=0f2b4d7dcdf7d1219df8d1959ad68e565f51d14c3f0d88bb71cd59abeb956292
RUN printf '%s\n' \
      'playwright==1.63.0 --hash=sha256:ad21bc07516b187965a7521c5cf0df0bd657b17482eaad74335272d35a2b07de' \
      'greenlet==3.5.6 --hash=sha256:975736b002ed080d124cf81a79cb7e05cb26d6b3f5c7a7b651c0fcce70353aa1' \
      'pyee==13.0.1 --hash=sha256:af2f8fede4171ef667dfded53f96e2ed0d6e6bd7ee3bb46437f77e3b57689228' \
      'typing-extensions==4.16.0 --hash=sha256:481caa481374e813c1b176ada14e97f1f67a4539ce9cfeb3f350d78d6370c2e8' \
      > /tmp/requirements.txt \
 && python3 -m pip install --no-cache-dir --break-system-packages --only-binary=:all: --require-hashes -r /tmp/requirements.txt \
 && rm /tmp/requirements.txt \
 && curl -fsSL "https://registry.npmjs.org/axe-core/-/axe-core-${AXE_VERSION}.tgz" -o /tmp/axe.tgz \
 && echo "${AXE_SHA256}  /tmp/axe.tgz" | sha256sum -c - \
 && mkdir -p /opt/axe \
 && tar -xzf /tmp/axe.tgz -C /opt/axe --strip-components=1 package/axe.min.js package/LICENSE \
 && rm /tmp/axe.tgz \
 && python3 -c "import playwright; from importlib.metadata import version; assert version('playwright') == '1.63.0'"
