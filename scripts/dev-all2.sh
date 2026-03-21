#!/usr/bin/env bash
#
# Start dev node 2: hecate_dev2 on port 4452
# Data dir: ~/.hecate-dev2/
# Identity: mri:agent:io.macula/hecate-dev2
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 2
