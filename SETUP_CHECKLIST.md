# ✅ Argi Setup Checklist

Use this checklist to ensure everything is configured correctly.

## 📋 Pre-Setup

- [ ] Flutter SDK installed and working (`flutter doctor`)
- [ ] Android Studio or VS Code with Flutter plugin installed
- [ ] Android device or emulator available
- [ ] Google account (for Google Maps)
- [ ] Supabase account created (supabase.com)
- [ ] Git installed (optional, for version control)

## 🗄️ Supabase Setup

### Account & Project
- [ ] Supabase account created
- [ ] New project created
- [ ] Project name: `argi` (or your choice)
- [ ] Database password saved securely
- [ ] Region selected

### API Credentials
- [ ] Project URL copied (Settings → API)
- [ ] Anon public key copied (Settings → API)
- [ ] Credentials added to `lib/main.dart`

### Database Tables
- [ ] SQL Editor opened
- [ ] `farms` table created
- [ ] `crops` table created  
- [ ] `activities` table created
- [ ] Indexes created on all tables
- [ ] RLS (Row Level Security) enabled on all tables
- [ ] Policies created for SELECT, INSERT, UPDATE, DELETE
- [ ] `updated_at` triggers created

### Verification
- [ ] Tables visible in Table Editor
- [ ] Shield icon visible (RLS enabled)
- [ ] Test user created (Authentication → Users)
- [ ] Can login to Supabase dashboard

## 🗺️ Google Maps Setup

### Google Cloud Project
- [ ] Google Cloud account created
- [ ] New project created or existing selected
- [ ] Project name noted

### APIs Enabled
- [ ] Maps SDK for Android enabled
- [ ] Geocoding API enabled (optional)
- [ ] Places API enabled (optional)

### API Key
- [ ] API key created (Credentials → Create Credentials)
- [ ] API key copied
- [ ] API key restrictions configured (recommended)
  - [ ] Application restrictions: Android apps
  - [ ] Package name added: `com.example.argi`
  - [ ] SHA-1 fingerprint added

### SHA-1 Fingerprint
- [ ] Debug keystore SHA-1 obtained:
  ```bash
  keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
  ```
- [ ] SHA-1 added to API key restrictions
- [ ] Release keystore SHA-1 obtained (for production)

### Flutter Configuration
- [ ] `android/local.properties` file exists
- [ ] `MAPS_API_KEY=your_key` added to local.properties
- [ ] `android/app/build.gradle.kts` reads from local.properties
- [ ] `AndroidManifest.xml` has maps API key meta-data

## 📱 Flutter Project Setup

### Dependencies
- [ ] `flutter pub get` completed successfully
- [ ] No dependency conflicts
- [ ] All packages downloaded

### File Structure
- [ ] `lib/main.dart` exists and configured
- [ ] `lib/models/farm.dart` exists
- [ ] `lib/models/crop.dart` exists
- [ ] `lib/services/supabase_service.dart` exists
- [ ] `lib/screens/auth_screen.dart` exists
- [ ] `lib/screens/farms_list_screen.dart` exists
- [ ] `lib/screens/farm_detail_screen.dart` exists
- [ ] `lib/screens/farm_map_screen.dart` exists

### Configuration Files
- [ ] `pubspec.yaml` has all required dependencies
- [ ] `android/app/build.gradle.kts` configured
- [ ] `android/app/src/main/AndroidManifest.xml` configured
- [ ] `android/local.properties` created with API key

### Permissions
- [ ] Location permissions in AndroidManifest.xml
- [ ] Internet permission in AndroidManifest.xml
- [ ] Network state permission in AndroidManifest.xml

## 🔧 Build & Run

### Pre-Build
- [ ] `flutter clean` executed
- [ ] `flutter pub get` re-run
- [ ] No analyzer errors (`flutter analyze`)

### Build
- [ ] `flutter build apk` successful (optional)
- [ ] OR `flutter run` successful
- [ ] App installs on device/emulator
- [ ] No build errors in console

### Runtime
- [ ] App launches without crashing
- [ ] Splash screen displays
- [ ] Redirects to login screen
- [ ] No runtime errors in console

## 🧪 Feature Testing

### Authentication
- [ ] Can access sign up screen
- [ ] Can create new account
- [ ] Email validation works
- [ ] Password validation works (min 6 chars)
- [ ] Can login with created account
- [ ] Invalid credentials show error
- [ ] Can toggle password visibility
- [ ] Can switch between login/signup

### Farms List
- [ ] Farms list screen loads
- [ ] Empty state shows if no farms
- [ ] Can tap "Add Farm" button
- [ ] Add farm dialog opens
- [ ] Can enter farm name
- [ ] Can enter location
- [ ] Can enter size in hectares
- [ ] Form validation works
- [ ] Can save new farm
- [ ] Farm appears in list
- [ ] Can pull to refresh
- [ ] Can tap farm card to view details

### Farm Details
- [ ] Farm detail screen loads
- [ ] Farm name displays correctly
- [ ] Location displays correctly
- [ ] Size displays correctly
- [ ] "Map Farm Boundary" button visible
- [ ] Can tap map button
- [ ] Crops section visible
- [ ] Quick actions visible
- [ ] Can return to farms list

### Farm Map (Main Feature!)
- [ ] Map screen loads
- [ ] Google Maps displays correctly
- [ ] Hybrid view (satellite + roads) shows
- [ ] Can see current location blue dot
- [ ] Can tap edit icon to enable drawing
- [ ] Orange "Drawing" badge appears
- [ ] Can tap map to add points
- [ ] Green markers appear at tap points
- [ ] Green polygon fills after 3+ points
- [ ] Info card shows area in m² and hectares
- [ ] Area updates as points added
- [ ] Can drag markers to adjust
- [ ] Undo button removes last point
- [ ] Clear button removes all points
- [ ] Save button saves to database
- [ ] Can reload and see saved polygon

### Planting Strategy
- [ ] Calculator icon visible after drawing
- [ ] Calculator dialog opens
- [ ] Shows current area
- [ ] Plant spacing slider works (10-100 cm)
- [ ] Row spacing slider works (20-150 cm)
- [ ] Estimated plants count updates
- [ ] Display shows count in green box
- [ ] Can apply strategy
- [ ] Can close dialog

### Location Services
- [ ] App requests location permission
- [ ] Location permission granted
- [ ] GPS icon shows in status bar
- [ ] Current location blue dot visible
- [ ] "My Location" button works
- [ ] Map centers on current location

## 🔍 Verification Tests

### Data Persistence
- [ ] Create farm, close app, reopen - farm still there
- [ ] Draw boundary, close app, reopen - boundary saved
- [ ] Logout, login - data still accessible
- [ ] Add multiple farms - all saved
- [ ] Delete farm - removed from list

### Accuracy Tests
- [ ] Draw known area (e.g., football field)
- [ ] Compare calculated area to actual
- [ ] Difference < 5%
- [ ] Test with different shaped polygons
- [ ] Test with large areas (> 1 hectare)
- [ ] Test with small areas (< 1000 m²)

### Performance Tests
- [ ] Map loads in < 2 seconds
- [ ] Can draw 10 points smoothly
- [ ] No lag when dragging markers
- [ ] Area calculation instant
- [ ] Switching between screens smooth
- [ ] No memory leaks (test with many actions)

## 🐛 Troubleshooting Checks

### If Map is Blank/Gray
- [ ] API key in `local.properties` is correct
- [ ] No extra spaces in API key
- [ ] Maps SDK for Android is enabled
- [ ] Internet connection is working
- [ ] App has internet permission
- [ ] API key restrictions allow app package

### If Location Not Working
- [ ] Location permission granted in app settings
- [ ] Device GPS is enabled
- [ ] Testing on physical device (not emulator)
- [ ] Emulator has mock location set
- [ ] `geolocator` package installed

### If Database Errors
- [ ] Supabase URL is correct in main.dart
- [ ] Supabase anon key is correct
- [ ] All tables created in Supabase
- [ ] RLS policies created
- [ ] User is authenticated
- [ ] Internet connection working

### If Build Errors
- [ ] `flutter clean` executed
- [ ] `flutter pub get` re-run
- [ ] Android SDK installed
- [ ] Java JDK installed
- [ ] `android/local.properties` exists
- [ ] API key format correct (no quotes)

## 📝 Documentation Review

- [ ] Read `README.md`
- [ ] Read `QUICK_START.md`
- [ ] Read `SUPABASE_SETUP.md`
- [ ] Read `GOOGLE_MAPS_SETUP.md`
- [ ] Read `IMPLEMENTATION_SUMMARY.md`
- [ ] Understand project structure
- [ ] Know where to find help

## 🚀 Production Readiness (Optional)

### Security
- [ ] Email verification enabled in Supabase
- [ ] API keys not committed to git
- [ ] `.gitignore` includes `local.properties`
- [ ] Release keystore created
- [ ] Release build signed
- [ ] ProGuard rules configured

### Optimization
- [ ] Database indexes verified
- [ ] Image assets optimized
- [ ] Unused dependencies removed
- [ ] Code obfuscation enabled
- [ ] App size minimized

### Monitoring
- [ ] Error tracking setup (e.g., Sentry)
- [ ] Analytics added (e.g., Firebase)
- [ ] Supabase billing alerts configured
- [ ] Google Cloud billing alerts configured
- [ ] Backup strategy defined

## ✨ Final Verification

### End-to-End Test
1. [ ] Open app
2. [ ] Create new account
3. [ ] Add first farm
4. [ ] Open farm map
5. [ ] Draw boundary (at least 4 points)
6. [ ] View calculated area
7. [ ] Open planting calculator
8. [ ] Adjust spacing sliders
9. [ ] View plant estimate
10. [ ] Save farm area
11. [ ] Return to farm list
12. [ ] Open farm again
13. [ ] Verify boundary is saved
14. [ ] Logout
15. [ ] Login again
16. [ ] Verify data persists

### Success Criteria
- [ ] All features work as expected
- [ ] No crashes or errors
- [ ] UI is responsive
- [ ] Data persists correctly
- [ ] Map displays properly
- [ ] Location services work
- [ ] Area calculation accurate
- [ ] Planting calculator functional

## 🎉 Completion

- [ ] All checkboxes above are checked
- [ ] App is fully functional
- [ ] Documentation reviewed
- [ ] Ready to use or deploy!

---

**Congratulations! Your Argi app is ready! 🌾**

If any items are unchecked, refer to:
- **Setup issues**: `QUICK_START.md`
- **Supabase issues**: `SUPABASE_SETUP.md`
- **Google Maps issues**: `GOOGLE_MAPS_SETUP.md`
- **Technical details**: `IMPLEMENTATION_SUMMARY.md`

**Need help?** Check the troubleshooting sections in each guide!
