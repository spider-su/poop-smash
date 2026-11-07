# Poop Smash — Play Console Release Checklist

**Prepared:** 7 November 2026. Review all declarations against the **actual signed release AAB**, not only the source repository.

## Identity and URLs
- Package ID: `com.spidersu.poopsmash`
- Name: Poop Smash
- Developer display name: smart-box
- Publisher: Alex Kotik (individual)
- Contact: alex.kotik.net@gmail.com
- Privacy: https://spider-su.github.io/poop-smash/privacy/
- Terms: https://spider-su.github.io/poop-smash/terms/
- Support: https://spider-su.github.io/poop-smash/support/
- Notices: https://spider-su.github.io/poop-smash/licenses/

**All github.io URLs require GitHub Pages to be enabled and publicly verified before submission.**

## Suggested App Content disclosures — verify first
- App access: no login or special access needed.
- Ads: no ads in the current app.
- Data safety: no data transferred to developer-operated servers; local scores/preferences only. Inspect final AAB/SDK list before selecting exact answers.
- Account deletion: not applicable while the app does not create accounts.
- Permissions: `android.permission.VIBRATE` expected; no INTERNET. Verify merged manifest.
- Target audience: choose the actual audience; selecting children triggers Families policy requirements.
- Content rating: answer the official questionnaire truthfully, including cartoon toilet/crude humor. Do not invent PEGI/IARC ratings.
- Privacy: a public policy webpage must be linked in Play Console and the privacy notice must be accessible from the app.
- Developer identity and address: review Google Play's and EU trader/non-trader disclosure requirements applicable to the personal publisher account.

## Release technical gates
- Production AAB must be release-signed; the currently CI-produced debug-signed AAB is not a production release artifact.
- New mobile applications submitted after 31 August 2026 must target Android 16 / API 36 or higher.
- Verify final package name, version code, min/target SDK, signing certificate, manifest and Play App Signing configuration.
- Check required closed testing rules for the developer account directly in Play Console.
- Validate screenshots and actual Android installation; no CI simulation substitutes for a device test.
- Ensure Fredoka SIL OFL notice, Godot MIT/third-party notices and MIT template attribution are retained.

## GitHub Pages activation
1. Open https://github.com/spider-su/poop-smash/settings/pages
2. Under Build and deployment choose Deploy from a branch.
3. Select main and /docs; save.
4. Confirm Pages build succeeds.
5. Open all four HTTPS URLs in a private browser before putting the privacy link into Play Console.

## Official references
- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/9859152
- https://developer.android.com/google/play/requirements/target-sdk
