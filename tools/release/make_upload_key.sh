#!/bin/sh
# Makes the Play upload key on YOUR machine and prints what to put in the
# repository's GitHub Actions secrets, so .github/workflows/android.yml
# signs the AAB for Play. Run it once, on a trusted computer (not a cloud
# session or CI), then keep the .jks and its password safe offline:
# losing them means asking Play support to reset the upload key.
#
#   sh tools/release/make_upload_key.sh ["CN=..., O=<publisher>, C=<country>"]
#
# With the GitHub CLI signed in, it can set the secrets for you.
set -e
DNAME=${1:-"CN=CLIMB UP"}
OUT=${OUT:-"$HOME/climbup-upload.jks"}
ALIAS=climbup-upload
if [ -e "$OUT" ]; then echo "$OUT already exists: not overwriting it." >&2; exit 1; fi
PASS=$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-32)
keytool -genkeypair -keystore "$OUT" -alias "$ALIAS" -storepass "$PASS" -keypass "$PASS" \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "$DNAME"
chmod 600 "$OUT"
echo
echo "Upload key: $OUT (alias $ALIAS)"
echo "Password:   $PASS"
echo "Save the password in your password manager now, and back up the .jks offline."
echo
if command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
  printf "Set the GitHub secrets for this repository with gh? [y/N] "
  read -r yes
  if [ "$yes" = y ]; then
    base64 < "$OUT" | tr -d '\n' | gh secret set ANDROID_UPLOAD_KEYSTORE_BASE64
    printf %s "$ALIAS" | gh secret set ANDROID_UPLOAD_KEY_ALIAS
    printf %s "$PASS" | gh secret set ANDROID_UPLOAD_KEY_PASSWORD
    echo "Secrets set. The next run of the Android workflow signs the AAB for Play."
    exit 0
  fi
fi
echo "Add these in GitHub: Settings > Secrets and variables > Actions > New repository secret"
echo "  ANDROID_UPLOAD_KEY_ALIAS        $ALIAS"
echo "  ANDROID_UPLOAD_KEY_PASSWORD     (the password above)"
printf '%s\n' "  ANDROID_UPLOAD_KEYSTORE_BASE64  the output of: base64 < $OUT | tr -d '\\n'"
