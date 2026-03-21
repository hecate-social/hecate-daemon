#!/usr/bin/env bash
#
# Start dev node 0: hecate_dev0 on port 4450
# Data dir: ~/.hecate-dev0/
# Identity: mri:agent:io.macula/hecate-dev0
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 0
