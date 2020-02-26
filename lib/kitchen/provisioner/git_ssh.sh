#!/bin/sh
# Workaround: GIT_SSH_COMMAND isn't supported by Git < 2.3
exec "${GIT_SSH_COMMAND:-ssh}" "$@"
