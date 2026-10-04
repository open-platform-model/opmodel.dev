#!/bin/sh
# A section page whose /docs/ link names no page: the site's link hook
# resolves it through the default version and fails the build.
printf '\nSee [nowhere](/docs/nowhere/).\n' >> "$SITE/.bundles/enhancements/edge/content/0001/questions.md"
