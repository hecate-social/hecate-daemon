#!/usr/bin/env bash
#
# Start dev node 5: hecate_dev5 on port 4455
# Data dir: ~/.hecate-dev5/
# Identity: mri:agent:io.macula/hecate-dev5
#
# Open this in a separate terminal alongside your main dev daemon.
#
exec "$(dirname "$0")/dev-node.sh" 5
