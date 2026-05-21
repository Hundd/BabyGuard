# Firebase upgrade — package rename + security follow-ups

After renaming the Android package from `com.example.baby_guard` to `com.hundd.babyguard`, the existing Firebase Android app entry no longer matches what the APK reports at runtime. Firebase rejects requests where `application.applicationId` doesn't match the registered package — symptom is an `ApiException: 10 (DEVELOPER_ERROR)` on first SDK call.

This doc walks through what to do in the Firebase Console + Google Cloud Console to get production-ready.

---

## 1. Register the new Android app in Firebase (required, ~5 min)

1. https://console.firebase.google.com/project/babyguard-4cd1e/settings/general
2. Scroll to **Your apps** → click **Add app** → **Android**.
3. **Android package name**: `com.hundd.babyguard`
4. **App nickname**: `BabyGuard (Play)` (just a label).
5. **Debug signing certificate SHA-1**: the SHA-1 of your release upload key. Get it with:
   ```bash
   keytool -list -v -keystore ~/.android/babyguard-release.jks -alias upload \
     -storepass "$(grep storePassword android/key.properties | cut -d= -f2)" \
     | grep "SHA1:"
   ```
   Paste the value (colons included).
   > After Play App Signing is enabled (see [googleplay_setup.md](googleplay_setup.md)), also add the SHA-1 that Google shows under **App signing key certificate** in Play Console → App integrity. Otherwise FCM/auth fails on Play-installed APKs.
6. **Register app** → **Download google-services.json**.
7. Replace the local file:
   ```bash
   mv ~/Downloads/google-services.json android/app/google-services.json
   ```
8. Open the new file, find `mobilesdk_app_id` (looks like `1:439753061143:android:<new-hash>`) and `current_key` (looks like `AIzaSy...`). Copy both into `firebase-config.json`:
   - `FIREBASE_APP_ID_ANDROID` ← `mobilesdk_app_id`
   - `FIREBASE_API_KEY` ← `current_key`
9. Rebuild + reinstall:
   ```bash
   make ship
   ```
10. Verify the app boots without `ApiException: 10` and that pairing still works.

## 2. (Optional) Delete the old `com.example.baby_guard` app

Once the new app works end-to-end on a real device, the old entry has no purpose. In Firebase Console → Project settings → Your apps → old app → menu → **Remove this app**. This also frees up the API key associated with it.

---

## 3. Security follow-ups — do these before going public

The current Firebase setup is fine for two phones in a household. Before exposing on the Play Store, harden these:

### 3a. Tighten Firestore rules

Today, [firestore.rules](../firestore.rules) lets any signed-in user (and anonymous auth is on) read every `pairs/*` doc, harvest FCM tokens, mute other people's alerts, and inject fake events into anyone's pair.

Replace with rules that bind access to the documented `babyUid` / `parentUid` fields:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /pairs/{pairId} {
      // Baby creates the pair doc claiming ownership.
      allow create: if request.auth != null
                    && request.resource.data.babyUid == request.auth.uid;

      // Owner pair read/update — either side of the pair.
      allow read, update: if request.auth != null
                          && (resource.data.babyUid == request.auth.uid
                              || resource.data.parentUid == request.auth.uid);

      // No client-side deletes; clean up via Cloud Function or admin.
      allow delete: if false;

      match /events/{eventId} {
        // Only the Baby unit on this pair can emit events.
        allow create: if request.auth != null
                      && get(/databases/$(database)/documents/pairs/$(pairId)).data.babyUid == request.auth.uid;
        allow read:   if request.auth != null
                      && get(/databases/$(database)/documents/pairs/$(pairId)).data.parentUid == request.auth.uid;
        allow update, delete: if false;
      }
    }
  }
}
```

Deploy:
```bash
make deploy-rules
```

Verify with the Firestore Rules Playground in the Console (Rules tab → Playground): simulate a write to `pairs/{otherPair}/events/{x}` from a UID that isn't `babyUid` on that pair — should be denied.

### 3b. Enable Firebase App Check

App Check refuses Firebase requests that don't come from a legitimate, attested copy of your app. Without it, anyone who pulls your API key from the APK can hit your Firestore from a custom client (and rules alone may not save you because they often need to look up other docs to authorize).

1. https://console.firebase.google.com/project/babyguard-4cd1e/appcheck
2. **Apps** tab → BabyGuard Android → **Register** → **Play Integrity** provider.
3. In Google Play Console (after you've created the app there): **Setup** → **App integrity** → **Play Integrity API** → enable, and link to the Firebase project.
4. Client-side: add `firebase_app_check: ^0.4.x` to `pubspec.yaml`, then in `main()` (after `Firebase.initializeApp`):
   ```dart
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.playIntegrity,
   );
   ```
5. In the Firebase Console, switch each used service (Firestore, FCM) from **Unenforced** → **Enforced** **only after** confirming the client successfully sends tokens (Console shows verified vs unverified call counts on the App Check page).

### 3c. Restrict the Android API key in Google Cloud Console

Even with App Check enforcement, locking the API key to your package + signing cert is belt-and-suspenders.

1. https://console.cloud.google.com/apis/credentials?project=babyguard-4cd1e
2. Find the API key labelled "Android key (auto created by Firebase)".
3. **Application restrictions** → **Android apps** → add:
   - Package name: `com.hundd.babyguard`
   - SHA-1: your release upload key SHA-1 (same one from step 1)
   - AND the SHA-1 from Play App Signing once enabled.
4. **API restrictions** → restrict to: Cloud Firestore API, Firebase Cloud Messaging API, Firebase Installations API, Identity Toolkit API. (Whatever the unrestricted key currently allows — list them, prune the rest.)
5. **Save**.

### 3d. Rotate the API key if it's been pasted publicly

The current key (`AIzaSy...`) has appeared in this Claude transcript and on at least two devices. For a household app it's a non-issue (the key isn't a secret per Firebase's own docs), but if any transcript will ever be shared:

1. https://console.cloud.google.com/apis/credentials?project=babyguard-4cd1e
2. Delete the current key → **Create credentials** → **API key**.
3. Apply the same restrictions from 3c.
4. Update `firebase-config.json` and `google-services.json`.
5. Rebuild + reship.

---

## Notes

- `firebase-config.json` and `android/app/google-services.json` are both gitignored. Treat them as local-only.
- The Cloud Function `onAlertEvent` does **not** care about package name changes — it runs server-side and reads pair docs by ID.
- The Cloud Function's service account, by default, has full Firestore admin access (bypasses rules). That's fine for our trigger but be aware if you add more functions.
