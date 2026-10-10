# Build image for the opmodel.dev Hugo site: the static (non-extended) Hugo
# binary, Pagefind (musl), opm-docs (docs-kit, static) and git on Alpine. Hextra ships precompiled CSS, so
# Hugo "extended" is not needed; Node and Go are not needed either (the theme
# is vendored as files, not a Hugo module). Every download is checked against
# a pinned SHA-256, and the base image is pinned by digest.
#
# Built with no context (`docker build -t <tag> - < site/Dockerfile`), so it
# COPYs nothing from the repo. The tag is opmodel-dev-hugo:<first 12 hex of the
# sha256 of this file> (site/scripts/run-in-image.sh image, task image).
ARG ALPINE=alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

FROM ${ALPINE} AS fetch
ARG HUGO_VERSION=0.167.0
ARG HUGO_SHA256=4d84519b9f619e6d4c3fb45a50157abeabeb724f859c60605f44c23def6e1169
ARG PAGEFIND_VERSION=1.5.2
ARG PAGEFIND_SHA256=afb824a9e7f64905a934900481cea5be679c03975e527329e0e5e6cc70f5feda
# opm-docs pulls, verifies and lints every signed docs bundle of
# site/bundles.cue (task bundles:pull, the only step that runs it with
# network), re-pulls the test fixtures offline and rebuilds the Enhancements
# fixture (test-site.sh). The SHA-256 is the linux_amd64 archive's line in
# the release's checksums.txt, checked by hand against a second download
# (docs-kit contract C12, build-image pattern). The page dialect is
# docs-kit's C11, enforced by this binary; the site keeps no copy of its
# conformance cases.
ARG OPM_DOCS_VERSION=0.7.1
ARG OPM_DOCS_SHA256=78e08059d4d6698f264f0832be94c0919a3a78532c265f0f96a8fa3dbae4f2ea
WORKDIR /dl
RUN wget -q "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" -O hugo.tgz \
 && echo "${HUGO_SHA256}  hugo.tgz" | sha256sum -c - \
 && tar -xzf hugo.tgz hugo \
 && wget -q "https://github.com/Pagefind/pagefind/releases/download/v${PAGEFIND_VERSION}/pagefind-v${PAGEFIND_VERSION}-x86_64-unknown-linux-musl.tar.gz" -O pagefind.tgz \
 && echo "${PAGEFIND_SHA256}  pagefind.tgz" | sha256sum -c - \
 && tar -xzf pagefind.tgz pagefind \
 && wget -q "https://github.com/open-platform-model/docs-kit/releases/download/v${OPM_DOCS_VERSION}/opm-docs_${OPM_DOCS_VERSION}_linux_amd64.tar.gz" -O opm-docs.tgz \
 && echo "${OPM_DOCS_SHA256}  opm-docs.tgz" | sha256sum -c - \
 && tar -xzf opm-docs.tgz opm-docs \
 && ./hugo version && ./pagefind --version && ./opm-docs version

# git builds the Enhancements fixture bundle from a throwaway repository
# (tests/fixtures/regen-enhancements.sh) and the shallow-clone test of
# scripts/gen-site-dates.sh, which dates the site-owned pages on the host;
# no build step runs it. busybox-extras brings the
# static httpd that serves site/public/ for preview; it is pinned to the
# busybox build the base image carries, so a newer Alpine package fails the
# image build instead of floating. jq reads the docs bundles' lock and
# manifests and the data/opm/catalogs.json derived from them (the build and
# check scripts under scripts/, and test-site.sh); it is pinned to the
# Alpine 3.24 package, so a newer one fails the image build too.
FROM ${ALPINE}
RUN apk add --no-cache git busybox-extras=1.37.0-r31 jq=1.8.2-r0 \
 && git config --system --add safe.directory '*'
COPY --from=fetch /dl/hugo /dl/pagefind /dl/opm-docs /usr/local/bin/
ENTRYPOINT ["hugo"]
