#!/usr/bin/env bash
#
# Copies the freshly built app into /Applications before Xcode launches it.
#
# macOS only activates a system extension (the VPN) when the app that contains
# it lives in /Applications, so running straight from DerivedData fails with
# OSSystemExtensionErrorDomain code 3. Called from the Run pre-action of the
# InternxtDesktop scheme, which then launches the copy in /Applications.
#
# Pre-action output is not shown in Xcode, so it is logged to
# $TMPDIR/internxt-install-to-applications.log.

set -euo pipefail

exec >"${TMPDIR:-/tmp}/internxt-install-to-applications.log" 2>&1

source_app="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
destination_app="/Applications/${FULL_PRODUCT_NAME}"

staging_dir="$(mktemp -d)"
trap 'rm -rf "${staging_dir}"' EXIT
staging_app="${staging_dir}/${FULL_PRODUCT_NAME}"
ditto "${source_app}" "${staging_app}"

pkill -x "${EXECUTABLE_NAME}" || true
rm -rf "${destination_app}"
mv "${staging_app}" "${destination_app}"

echo "Installed ${source_app} -> ${destination_app}"
