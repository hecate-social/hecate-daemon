#!/usr/bin/env bash
#
# Start dev node 1: hecate_dev1 on port 4451
# Data dir: ~/.hecate-dev1/
# Identity: mri:agent:io.macula/hecate-dev1
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 1
