# Android Signing Setup for Play Store

This guide will help you set up signing for your Android app to publish to the Play Store.

## Step 1: Generate a Keystore

Run the following command in the `android` directory to generate your keystore:

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted to:
- Enter a password for the keystore (save this securely!)
- Enter a password for the key alias (can be the same or different)
- Enter your name, organizational unit, organization, city, state, and country code

**Important:** 
- Keep your keystore file and passwords secure. If you lose them, you won't be able to update your app on the Play Store.
- The keystore file (`upload-keystore.jks`) is already in `.gitignore` and won't be committed to version control.

## Step 2: Create key.properties

Copy the template file and fill in your passwords:

```bash
cp key.properties.template key.properties
```

Then edit `key.properties` and replace:
- `YOUR_KEYSTORE_PASSWORD` with the keystore password you entered
- `YOUR_KEY_PASSWORD` with the key password you entered

The file should look like:
```
storePassword=your_actual_keystore_password
keyPassword=your_actual_key_password
keyAlias=upload
storeFile=../upload-keystore.jks
```

**Note:** The `key.properties` file is also in `.gitignore` and won't be committed.

## Step 3: Build Release APK/AAB

Once the keystore and key.properties are set up, you can build a signed release:

```bash
# For App Bundle (recommended for Play Store)
flutter build appbundle --release

# Or for APK
flutter build apk --release
```

The signed release files will be in:
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Backup Your Keystore

**CRITICAL:** Make secure backups of:
1. The `upload-keystore.jks` file
2. Your keystore password
3. Your key password
4. The key alias name (usually "upload")

Store these backups in a secure location. If you lose them, you cannot update your app on the Play Store and will need to publish a new app with a new package name.

