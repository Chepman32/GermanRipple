#!/bin/sh
set -eu

# Run after a signed archive in release CI. Symbols are developer build artifacts;
# runtime diagnostics remain controlled by the learner's in-app consent.
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
archive=${1:?Usage: sh tools/upload_symbols.sh /absolute/path/Ripple.xcarchive}
config=${RIPPLE_FIREBASE_CONFIG_PATH:-"${root}/App/Resources/GoogleService-Info.plist"}
sdk=${RIPPLE_FIREBASE_SDK_PATH:-"${root}/.build/SourcePackages/checkouts/firebase-ios-sdk"}
if [ ! -d "${archive}/dSYMs" ] || [ ! -f "${config}" ] || [ ! -x "${sdk}/Crashlytics/upload-symbols" ]; then
  echo 'A real archive with dSYMs, Firebase configuration and Firebase SDK checkout are required.' >&2
  exit 1
fi
bundle=$(/usr/bin/plutil -extract BUNDLE_ID raw -o - "${config}")
if [ "${bundle}" != 'app.ripple.grammar' ]; then
  echo 'Firebase configuration must match app.ripple.grammar.' >&2
  exit 1
fi
exec "${sdk}/Crashlytics/upload-symbols" -gsp "${config}" -p ios "${archive}/dSYMs"
