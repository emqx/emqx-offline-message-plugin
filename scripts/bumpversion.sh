#!/bin/bash

set -uo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <patch|minor|major>"
    exit 1
fi

level="$1"

if [ "$level" != "patch" ] && [ "$level" != "minor" ] && [ "$level" != "major" ]; then
    echo "Usage: $0 <patch|minor|major>"
    exit 1
fi

bump2version_present=$(command -v bump2version || echo "false")
if [ "$bump2version_present" = "false" ]; then
    echo "Please install bump2version first: pip install bump2version"
    exit 1
fi

exec bump2version "$level"

