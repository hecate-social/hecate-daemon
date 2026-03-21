#!/usr/bin/env bash
#
# Start dev node 3: hecate_dev3 on port 4453
# Data dir: ~/.hecate-dev3/
# Identity: mri:agent:io.macula/hecate-dev3
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 3
