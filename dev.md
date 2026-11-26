# MyBasic Education (MBEd)

## Build & Deployment Commands

### Android APK Build
Run from `kalinga-proj/frontend/frontend_flutter/`:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://scarsyvi-kalinga-proj.onrender.com/api/v1
```

### Web Build & GitHub Pages Deployment
Run from the repository root (`kalinga-proj/`):

```bash
cd frontend/frontend_flutter

flutter build web --release --base-href "/scarsyvi-kalinga-proj/" --dart-define=API_BASE_URL=https://scarsyvi-kalinga-proj.onrender.com/api/v1

cd ../../

git add -f frontend/frontend_flutter/build/web
git commit -m "update web build for gh-pages"
git subtree push --prefix frontend/frontend_flutter/build/web origin gh-pages
```

---

## TODO

- [ ] System Documentation
- [ ] User Manual

### Fixes (26/11/26)
- [x] `Queued` label does not resolve upon sync
- [x] Form screens too small for mobile use
- [x] Android not registering lack of connection properly
- [x] Appearance settings not saved on app exit
- [x] Android dependency fix (AGP / Gradle version alignment)