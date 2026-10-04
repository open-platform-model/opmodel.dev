#!/bin/sh
# A lock without tab bundles: a docs page's link into the Catalogs tab has
# nothing to resolve to, and the failure names the task that pulls them.
. "$BP"
drop_tabs "$SITE/.bundles"
