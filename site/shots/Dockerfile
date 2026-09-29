# Chromium and Playwright for `task shots`, which screenshots the figures on
# the built site. Kept apart from the site's build image so the site build
# does not carry a browser. The Playwright package must match the browsers
# the base image ships.
FROM mcr.microsoft.com/playwright/python:v1.52.0-noble
RUN python3 -m pip install --no-cache-dir --break-system-packages playwright==1.52.0
