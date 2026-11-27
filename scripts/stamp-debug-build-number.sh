#!/usr/bin/env bash
#
# Gives the VPN extension a unique build number on every Debug build.
#
# sysextd only replaces an installed system extension when its version changes.
# Without this, a Debug run keeps an extension with the same version that is
# already installed (an older Debug build, or a Beta/Release signed with
# Developer ID, which then fails to connect), and extension code changes don't
# take effect. Beta and Release keep the project's build number.

set -euo pipefail

[ "${CONFIGURATION}" = "Debug" ] || exit 0

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion ${CURRENT_PROJECT_VERSION}.$(date +%s)" \
    "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
