#!/bin/sh
set -eu

# A clone without the ignored environment file must remain a working offline app.
# Never leave a previous build's Firebase configuration inside a reused bundle.
config="${SRCROOT}/App/Resources/GoogleService-Info.plist"
destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
if [ "${RIPPLE_BUNDLE_FIREBASE_CONFIGURATION:-YES}" != "NO" ] && [ -f "${config}" ]; then
  mkdir -p "$(dirname "${destination}")"
  /bin/cat "${config}" > "${destination}"
else
  /bin/rm -f "${destination}"
fi
