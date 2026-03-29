### lSign

An actually LIGHTWEIGHT app that gives you the signing without install feature when distributing IPA's!

---
## App Preview

- Context: lSign is running inside LiveContainer, hence why the duplicate container IDs.
- For LiveContainer users, toggle on "Fix File Picker" in App Settings before trying to sign an IPA.

- 1st Screenshot
![SS1](screenshotsNTBC/IMG_0424.jpeg)

- 2nd Screenshot
![SS2](screenshotsNTBC/IMG_0425.jpeg)

---

## Performance

- Small IPAs (~5–10 MB): ~1 second  
- Medium IPAs (~20–50 MB): 5–15 seconds  
- Large IPAs (>50 MB): depends on size and embedded frameworks

---

## How to get IPA

- Without Building
  1. Go to "Releases" tab.
  2. Download the latest IPA.
     
- With Building (macOS)
  1. Clone the repository.
  2. Open the `lSign.xcodeproj` folder in XCode.
  3. Sign the app with your certificate.
  4. Build and install to your iOS/iPadOS device.
     
- With Building (Github Actions)
  1. Clone the repository via Use Template.
  2. Go to "Actions" tab.
  3. Press on "Workflows" then "Build lSign IPA" listed.
  4. Press "Run Workflow".
  5. Wait for all the jobs to finish, then go to Artifacts (scroll to bottom), then download the IPA zip file.
  6. Unzip the file locally and install.

---

**DISCLAIMER** : You are responsible for how you use this tool, including piracy or other illegal activities.
