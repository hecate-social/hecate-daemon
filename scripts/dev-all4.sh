#!/usr/bin/env bash
#
# Start dev node 4: hecate_dev4 on port 4454
# Data dir: ~/.hecate-dev4/
# Identity: mri:agent:io.macula/hecate-dev4
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 4
