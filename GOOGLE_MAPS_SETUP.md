# Google Maps Setup Guide for Argi

## Prerequisites
- Google Cloud Platform account
- Flutter development environment

## Step 1: Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS** (if building for iOS)
   - **Geocoding API** (optional, for address lookups)
   - **Places API** (optional, for location search)

4. Go to **Credentials** → **Create Credentials** → **API Key**
5. Copy your API key
6. **Restrict the API key** (recommended):
   - Click on the API key you just created
   - Under "Application restrictions", select "Android apps"
   - Add your package name: `com.example.argi`
   - Add your SHA-1 certificate fingerprint (see below)

## Step 2: Get SHA-1 Fingerprint

### For Debug Certificate:
```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### For Release Certificate:
```bash
keytool -list -v -keystore your-release-key.jks -alias your-alias
```

Copy the SHA-1 fingerprint and add it to your API key restrictions.

## Step 3: Configure the App

1. Open `android/local.properties`
2. Add your API key:
```properties
MAPS_API_KEY=YOUR_API_KEY_HERE
```

**Note:** The `local.properties` file is already in `.gitignore` so your API key won't be committed.

## Step 4: Verify Configuration

The configuration is already set up in these files:
- ✅ `android/app/src/main/AndroidManifest.xml` - Meta-data tag added
- ✅ `android/app/build.gradle.kts` - Reads key from local.properties
- ✅ `pubspec.yaml` - Dependencies added

## Step 5: Test the Map

1. Make sure you have a physical device or emulator running
2. Run the app:
```bash
flutter run
```

3. Navigate to any farm and tap the map icon to open the farm map screen

## Features Implemented

### Farm Map Screen (`lib/screens/farm_map_screen.dart`)

✅ **Interactive Map**
- Google Maps with hybrid view (satellite + roads)
- Current location tracking
- Custom map markers

✅ **Polygon Drawing**
- Tap to add boundary points
- Drag markers to adjust positions
- Visual feedback during drawing mode
- Undo/clear functions

✅ **Area Calculator**
- Automatic area calculation using Shoelace formula
- Converts GPS coordinates to square meters
- Displays area in hectares and square meters
- Real-time updates as polygon changes

✅ **Planting Strategy**
- Configurable plant spacing (10-100 cm)
- Configurable row spacing (20-150 cm)
- Automatic plant count estimation
- Interactive slider controls
- Visual summary of planting plan

✅ **Data Persistence**
- Save polygon coordinates to Supabase
- Load existing farm boundaries
- Update farm size automatically

## Troubleshooting

### Map shows blank or gray tiles
- Verify API key is correct in `local.properties`
- Ensure Maps SDK for Android is enabled
- Check API key restrictions aren't too strict
- Verify internet connection

### Location not working
- Grant location permissions when prompted
- Check device location services are enabled
- For emulator, set location in extended controls

### Build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run
```

### API Key not found
- Make sure `local.properties` exists in `android/` folder
- Verify the key format: `MAPS_API_KEY=your_key` (no quotes)
- Rebuild the app after adding the key

## Billing & Quotas

Google Maps has a **$200 monthly credit** which covers:
- ~28,000 map loads per month
- ~40,000 API calls per month

For a farm management app, this is typically more than enough for personal/small business use.

Monitor usage at: [Google Cloud Console - APIs & Services](https://console.cloud.google.com/apis/dashboard)

## Next Steps

1. **Add Search Functionality**
   - Integrate Places API for location search
   - Add search bar to find farms by address

2. **Enhanced Mapping**
   - Add weather overlay layers
   - Show soil moisture zones
   - Display crop health heatmaps

3. **Offline Support**
   - Cache map tiles for offline viewing
   - Store polygon data locally
   - Sync when connection available

4. **Advanced Features**
   - Multiple polygons per farm
   - Crop-specific zoning
   - Irrigation planning overlays
   - Field history visualization

## Support

If you encounter issues:
1. Check the [Flutter Google Maps Plugin docs](https://pub.dev/packages/google_maps_flutter)
2. Review [Google Maps Platform documentation](https://developers.google.com/maps/documentation)
3. Verify your Supabase configuration is correct
