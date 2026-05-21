# Google Play Store setup

End-to-end checklist for shipping BabyGuard to Google Play. The codebase is already mostly Play-ready: package is `com.hundd.babyguard`, release signing is wired in [android/app/build.gradle.kts](../android/app/build.gradle.kts), and `make aab` produces a signed App Bundle. What's left is mostly Play Console clicks + listing copy.

Prerequisite: complete [firebase_upgrade.md](firebase_upgrade.md) first — without the renamed Firebase Android app the released APK crashes on startup.

---

## 1. Save the upload key somewhere safe (CRITICAL)

The upload keystore lives at `~/.android/babyguard-release.jks`. Credentials are in the gitignored `android/key.properties`.

**Back both up immediately**:
- Copy the `.jks` file to a second location (1Password / iCloud Drive / encrypted USB).
- Copy the password and SHA fingerprints into a password manager.

Get the fingerprints if you need them again:
```bash
keytool -list -v -keystore ~/.android/babyguard-release.jks -alias upload \
  -storepass "$(grep storePassword android/key.properties | cut -d= -f2)" \
  | grep -E "SHA1:|SHA256:"
```

> If you lose this and haven't enabled Play App Signing, you can never update the app on the Store again. Play App Signing (step 4 below) is the safety net.

---

## 2. Create a Google Play Developer account ($25, one-time)

1. https://play.google.com/console/signup
2. Sign in with the Google account you want to own this app.
3. Account type: **Personal** (or Organization — Organization requires a D-U-N-S number).
4. Pay the $25 one-time fee.
5. Identity verification: Google requires a government ID. Approval is usually < 48 h but can take a week.
6. Wait for the "you're approved" email before continuing.

---

## 3. Create the app in Play Console

1. Play Console → **Create app**.
2. **App name**: `BabyGuard` (50 char max — visible in Play Store).
3. **Default language**: English (United States).
4. **App or game**: App.
5. **Free or paid**: Free.
6. Confirm the two declarations (Developer Program Policies + US export laws).

---

## 4. Enable Play App Signing (do this FIRST in the new app)

Under **App integrity** → **App signing**:

1. Choose **Use Play App Signing**.
2. Upload key: choose **Export and upload a key from Android Studio** path → upload your local `~/.android/babyguard-release.jks` AND enter the credentials. (Alternative paths exist but this is the simplest.)
3. Google generates an **app signing key** they keep in escrow. Note both fingerprints:
   - **Upload key certificate** — what your local keystore produces, what AABs must be signed with.
   - **App signing key certificate** — what Play uses to re-sign before distribution. This is the SHA-1 your installed app actually reports at runtime, so **add it to Firebase Console** (see [firebase_upgrade.md](firebase_upgrade.md) §1).
4. Once enabled: if you ever lose `babyguard-release.jks`, Google can reset the upload key on request. Without Play App Signing, that's a hard dead end.

---

## 5. Fill out app content (this gates internal testing)

Play Console → **Policy** → **App content**. Each row links to a form:

| Section | What it wants | Note for BabyGuard |
|---------|---------------|---------------------|
| **Privacy policy** | URL of a public privacy policy page | See §8 — must be hosted publicly, HTTPS, in the listing language |
| **App access** | Test credentials if your app gates content | None — anonymous auth, no login |
| **Ads** | Whether the app shows ads | No |
| **Content rating** | Quiz, generates IARC rating | Pick "Utility/Productivity"; declares no user-generated content, no violence, etc. → typically rated "Everyone" |
| **Target audience** | Age groups | 18+; do **not** target children — that triggers COPPA/Designed for Families requirements |
| **News app** | Are you a news app | No |
| **COVID-19 contact tracing** | No |
| **Data safety** | Big form — see §7 | |
| **Government app** | No |
| **Financial features** | None |
| **Health features** | Optional but a baby monitor arguably qualifies — declaring it doesn't hurt |

---

## 6. Sensitive permission declarations (the one that can sink the listing)

**Play Console → Policy → App content → Sensitive permissions and APIs.**

BabyGuard requests:

- `RECORD_AUDIO`
- `FOREGROUND_SERVICE_MICROPHONE`
- `USE_FULL_SCREEN_INTENT`
- `POST_NOTIFICATIONS`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

The `RECORD_AUDIO` + `FOREGROUND_SERVICE_MICROPHONE` pair triggers Google's mic policy review. You'll need to declare:

- **Core functionality** → "Audio monitoring (baby monitor)".
- **Demo video** (~30 s) showing the in-app indicator while monitoring is active. Upload to YouTube as Unlisted.
- **Privacy policy** must explicitly state:
  - The app uses the microphone to detect loud sounds.
  - Audio is **not recorded or transmitted** — only a numeric dB level is processed on-device.
  - Only the dB number (not audio) is sent to Firebase to alert the paired device.

Template paragraph for the listing's "How your app uses these permissions" box:

> BabyGuard uses the microphone solely to measure the ambient sound level on the device acting as the baby unit. Audio is never recorded, stored, or transmitted. The app computes a decibel reading locally and, when that reading exceeds a user-configured threshold for 800 ms or longer, sends a notification to the paired parent device via Firebase Cloud Messaging. A persistent foreground notification is shown the entire time monitoring is active so the user knows the microphone is in use.

`USE_FULL_SCREEN_INTENT` is also Play-policy-restricted as of Android 14+. Justification: "Critical user notification (baby crying alert that wakes the parent's phone)."

---

## 7. Data safety form

Play Console → **App content → Data safety**.

For BabyGuard, declare:

| Data type | Collected? | Shared? | Optional? | Purpose |
|-----------|-----------|---------|-----------|---------|
| User ID (anonymous Firebase UID) | Yes | No | No | App functionality |
| Device or other IDs (FCM token) | Yes | No | No | App functionality |
| Approximate sound level (dB) | Yes | No | No | App functionality |
| Audio recordings | **No** | No | — | We never record audio |
| Name, email, phone, address | No | — | — | |
| Photos, videos, contacts, location | No | — | — | |

Encryption in transit: **Yes** (Firebase uses TLS).
Users can request data deletion: **Yes** — provide a contact email and document the "Unpair" button in [lib/features/settings/settings_screen.dart](../lib/features/settings/settings_screen.dart) which clears local state.

---

## 8. Privacy policy

Required because of `RECORD_AUDIO` + collected data. Must be:
- Publicly reachable HTTPS URL (no auth, no robots.txt block).
- In the same language as the listing.
- Linked both in the Play listing and in-app (Settings is a fine place).

Cheapest hosting options:
- **GitHub Pages** from this repo: enable on the `main` branch, drop `docs/privacy.md` (with Jekyll front matter), serves at `https://hundd.github.io/BabyGuard/privacy/`.
- **Notion** page published as a public site.
- **Pastebin / Carrd** — works but feels unserious to reviewers.

Minimum sections required:
1. App name + your contact email.
2. What you collect (anonymous UID, FCM token, dB readings, pair code).
3. What you do **not** collect (no audio, no PII, no location).
4. Where the data goes (Firebase / Google).
5. Retention policy (pair docs deleted when user taps Unpair).
6. How to request deletion / export (email).
7. Children's data: declare "not directed at children under 13".
8. Last updated date.

A starter template lives at https://app-privacy-policy-generator.firebaseapp.com (ironic) — generate, customise, host.

---

## 9. Store listing assets

| Asset | Spec | How to produce |
|-------|------|----------------|
| **App icon** | 512×512 PNG, no transparency, max 1 MB | Already have it: re-export `assets/icons/app_icon.png` at 512 with `sips -z 512 512 assets/icons/app_icon.png --out /tmp/icon_512.png` |
| **Feature graphic** | 1024×500 PNG/JPEG, no text | Use any quick design tool (Figma, Canva). Just the stroller on the soft-blue background works. |
| **Phone screenshots** | 2–8 images, ≥ 320 px short side, max 3840 px, 16:9 or 9:16 | `adb -s <device> exec-out screencap -p > screenshot1.png` — capture: onboarding, baby unit monitoring (dB meter live), parent unit "Listening" state, settings, alert full-screen |
| **Short description** | 80 chars | "Turn two phones into a baby monitor with loud alerts and a sound-level meter." |
| **Full description** | 4000 chars | Explain what it does, key features, permissions, link to privacy policy |
| **Application category** | dropdown | "Parenting" (best match — `app_category=PARENTING`) |
| **Tags** | up to 5 | "baby monitor", "alerts", "parents", "infant", "sound monitor" |
| **Email** | required | Your support email |

---

## 10. Internal testing — first upload

Don't go straight to production. Use the testing tracks ladder:

1. **Test and release → Testing → Internal testing → Create new release**.
2. Upload `build/app/outputs/bundle/release/app-release.aab` (`make aab`).
3. **Release name**: `0.1.0+1 internal-1` (or whatever the `pubspec.yaml` versionName + versionCode are).
4. **Release notes**: one line ok for internal.
5. **Testers**: create an email list, add your own account + family.
6. Save → Review → Start rollout.
7. After ~20–30 min, the testers will get an opt-in link by email. Open on the test phone in Chrome, follow the Play Store link, install.
8. Verify on real device.

Iterate here as much as you want — internal track has no human review.

---

## 11. Promotion ladder

| Track | Approval | Audience | Use when |
|-------|----------|----------|----------|
| Internal | None | up to 100 listed testers | Daily dev |
| Closed | Human review, 1–7 days | invite list or Google Groups | Beta with friends |
| Open | Human review | anyone with the opt-in URL | Public beta |
| Production | Human review, deeper policy check | everyone in selected countries | GA |

Promote a build via **Test and release → Production → Promote release → from Internal**. No re-upload needed if the AAB is unchanged.

---

## 12. Things Google will probably push back on first time

Heads up so you're not surprised:

1. **Mic permission justification too thin** → resubmit with the §6 paragraph + demo video.
2. **Foreground service type missing/wrong** → already correct (`android:foregroundServiceType="microphone"` in [AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml)).
3. **Privacy policy doesn't mention mic / audio explicitly** → add the sentence "The app accesses the device microphone to compute ambient sound level. Audio is not recorded."
4. **Target API mismatch** → already on `targetSdk = 34`, which satisfies Google's 2024+ requirements. Bump to 35 when their Aug 2025 cutoff hits.
5. **64-bit requirement** → Flutter handles this automatically (builds arm64 + armeabi-v7a in the AAB).

---

## 13. Going live

Once production is approved:
- Listing appears in Play Store search within a few hours.
- Updates: bump `version:` in [pubspec.yaml](../pubspec.yaml) (both name like `0.1.1` and the `+N` build code — every upload needs a higher build code), `make aab`, upload to the same Production track.

---

## Reference

- [Play Console](https://play.google.com/console/)
- [App Bundle docs](https://developer.android.com/guide/app-bundle)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Sensitive permission policy](https://support.google.com/googleplay/android-developer/answer/9888170)
- [Data safety form](https://support.google.com/googleplay/android-developer/answer/10787469)
