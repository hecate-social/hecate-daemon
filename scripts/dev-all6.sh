#!/usr/bin/env bash
#
# Start dev node 6: hecate_dev6 on port 4456
# Data dir: ~/.hecate-dev6/
# Identity: mri:agent:io.macula/hecate-dev6
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 6
