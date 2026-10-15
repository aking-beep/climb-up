# Android signing and upload

How CLIMB UP is signed for a Google Play closed test, and how to keep the
keys safe. **No key, password or keystore is ever committed.** `.gitignore`
blocks `*.jks`, `*.keystore`, `keystore.properties` and `*.aab`.

## Identity

| | |
| --- | --- |
| Package | `com.climbup.game` (permanent: Play never lets it change) |
| Version name | `0.9.0-beta.1` (`export_presets.cfg` `version/name`, `project.godot` `config/version`) |
| Version code | `9` (raise it by 1 for every upload; Play refuses a code it has seen) |
| Min / target SDK | 24 / 36 |
| Orientation | landscape, either way up (`screenOrientation` 11, userLandscape) |
| Permissions | `INTERNET` and `ACCESS_NETWORK_STATE` (the records service), `VIBRATE` (haptics, a setting) |

## Two keys: Play App Signing

Play signs the app that players install with an **app signing key** that
Google keeps. You sign what you upload with your own **upload key**. If
the upload key is lost or leaked, Play support can reset it. The app
signing key is not affected.

1. **Make the upload key once, on a trusted machine.** Not in a cloud
   session or a CI runner.
   ```sh
   keytool -genkeypair -v -keystore climbup-upload.jks -alias climbup-upload \
     -keyalg RSA -keysize 4096 -validity 10000 \
     -dname "CN=CLIMB UP, O=ARC Transformation Group"
   ```
   Use a long random password. Keep it in a password manager.
2. **Back it up.** Keep two copies of the `.jks` and its password,
   offline and apart (for example, an encrypted USB key and the password
   manager's file storage).
3. **Opt in to Play App Signing** when you create the app in Play
   Console. It is the default for new apps. Upload the first AAB signed
   with the upload key.
4. **Never share the keystore by chat, email or the repository.** For
   CI, store it as an encrypted secret: base64 of the `.jks`, plus the
   password. Restrict it to protected branches.

## Building a signed release

```sh
export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$HOME/keys/climbup-upload.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=climbup-upload
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'   # from the password manager
tools/godot/export.sh android-release   # build/godot-android/climb-up-release.apk
tools/godot/export.sh android-aab       # build/godot-android/climb-up.aab (for Play)
```

Before a beta build that should talk to the records service, set
`records/endpoint` and `records/privacy_url` under `[climb_up]` in
`godot/project.godot` (see `server/deploy/README.md`).

### The AAB needs the Gradle build

Play accepts only Android App Bundles (`.aab`). Godot builds an AAB with
Gradle, which needs:

- the Android build template. `export.sh android-aab` installs it on
  first use (`--install-android-build-template`) into `godot/android/`,
  which is ignored by git.
- network access to `dl.google.com` and `maven.google.com`. Gradle,
  the Android Gradle plugin, `aapt2` and `bundletool` come from there.

The `Android Play (AAB)` preset (`export_presets.cfg` preset 3) is set up
for this: Gradle build on, export format AAB, the same identity and
icons as the APK preset.

## Checking a build

```sh
apksigner verify --print-certs --verbose build/godot-android/climb-up-release.apk
# AAB:
bundletool validate --bundle build/godot-android/climb-up.aab
jarsigner -verify -verbose -certs build/godot-android/climb-up.aab
```

Confirm:
- the package, version and permissions above;
- `debuggable` is absent;
- `allowBackup="false"`.

## The beta APK built in the readiness sprint

`build/godot-android/climb-up-release.apk` was signed with a **temporary**
key. The key was made in the cloud session and is discarded with it. So:

- Use that APK only for side-loaded testing on test devices.
- Do **not** upload it to Play, and don't use its key as the upload key.
- A build signed with your real upload key cannot update it in place.
  Testers uninstall it first. Uninstalling also clears the device's local
  records and progress.
