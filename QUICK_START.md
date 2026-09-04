# Grow a Garden - Quick Start Guide

Run the app against the shared Grow a Garden backend in a few minutes.

## 📋 Prerequisites

- Flutter SDK installed
- Android Studio or VS Code with Flutter plugin

## ⚡ Quick Setup (2 Steps)

### Step 1: Clone and install dependencies

```bash
git clone https://github.com/tanth123-h/argi.git
cd c:\Users\tankh\Downloads\argi
flutter pub get
```

### Step 2: Run the app

```bash
# Run on Android device/emulator
flutter run
```

Create an account from the app. The shared Supabase project separates each
user's data through Row Level Security, so a clone does not need database
setup or a Google Maps API key.

For ESP32/MQTT use and the optional independent backend, read
[CLONE_AND_RUN.md](CLONE_AND_RUN.md).

## 🎯 First Use

### 1. Create Account
- Open the app
- Tap "Sign Up"
- Enter email and password
- Tap "Sign Up"

### 2. Add Your First Farm
- Tap the "+" button
- Fill in:
  - **Farm Name**: e.g., "North Field"
  - **Location**: e.g., "Pampanga, Philippines"
  - **Size**: e.g., "2.5" (hectares)
- Tap "Add"

### 3. Map Your Farm Boundary
- Tap on your farm card
- Tap the **Map** button
- Tap the **Edit** icon (top right)
- Tap on the map to mark corners of your farm
- Drag markers to adjust
- View real-time area calculation
- Tap **Save Area**

### 4. Plan Your Planting
- While on map screen, tap the **Calculator** icon
- Adjust plant spacing (10-100 cm)
- Adjust row spacing (20-150 cm)
- View estimated plant count
- Tap "Apply"

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── farm.dart               # Farm data model
│   └── crop.dart               # Crop data model
├── services/
│   └── supabase_service.dart   # Database operations
└── screens/
    ├── auth_screen.dart        # Login/Sign up
    ├── farms_list_screen.dart  # All farms
    ├── farm_detail_screen.dart # Farm overview
    └── farm_map_screen.dart    # 🗺️ Interactive map
```

## ✨ Key Features

### 🗺️ Interactive Farm Mapping
- Draw farm boundaries by tapping
- Drag markers to adjust
- Real-time area calculation
- GPS-accurate measurements

### 📐 Area Calculator
- Automatic calculation in m² and hectares
- Uses Shoelace formula
- Accounts for Earth's curvature

### 🌱 Planting Strategy
- Configurable spacing
- Automatic plant count
- Optimize planting density

### 📊 Farm Management
- Track multiple farms
- Manage crops
- Log activities
- Monitor harvest dates

## 🔐 Configuration Files

### Required Setup:
```
android/local.properties
MAPS_API_KEY=your_google_maps_key

lib/main.dart
url: 'your_supabase_url'
anonKey: 'your_supabase_anon_key'
```

### Auto-configured (no changes needed):
- ✅ `android/app/build.gradle.kts`
- ✅ `android/app/src/main/AndroidManifest.xml`
- ✅ `pubspec.yaml`

## 🐛 Common Issues

### Map shows blank/gray screen
**Fix**: Add valid Google Maps API key to `android/local.properties`

### "relation does not exist" error
**Fix**: Run SQL commands from `SUPABASE_SETUP.md` in Supabase SQL Editor

### Location not working
**Fix**: Grant location permissions when app asks

### Build errors
```bash
flutter clean
flutter pub get
cd android && gradlew clean && cd ..
flutter run
```

## 📖 Detailed Documentation

- **[SUPABASE_SETUP.md](SUPABASE_SETUP.md)** - Complete Supabase configuration
- **[GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md)** - Google Maps setup details
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical overview

## 🎬 Usage Flow

```
1. Sign Up/Login (auth_screen.dart)
   ↓
2. View Farms List (farms_list_screen.dart)
   ↓
3. Add New Farm
   ↓
4. Open Farm Details (farm_detail_screen.dart)
   ↓
5. Map Farm Boundary (farm_map_screen.dart)
   ↓
6. Calculate Planting Strategy
   ↓
7. Add Crops
   ↓
8. Log Activities
```

## 🚀 Production Deployment

### Before releasing to users:

1. **Secure API Keys**
   - Use environment variables
   - Never commit keys to git

2. **Enable Email Verification**
   - Supabase → Authentication → Settings
   - Enable email confirmation

3. **Test thoroughly**
   - Different farm sizes
   - Various polygon shapes
   - Multiple devices
   - Offline scenarios

4. **Optimize performance**
   - Add database indexes
   - Implement pagination
   - Cache map tiles

5. **Set up monitoring**
   - Supabase dashboard
   - Google Cloud Console
   - Error tracking (e.g., Sentry)

## 💡 Tips for Best Results

### Mapping Tips
- Zoom in close before drawing
- Walk the perimeter with GPS for accuracy
- Draw in daylight for better satellite view
- Mark 10-20 points for smooth boundaries

### Accuracy Tips
- Use physical device (not emulator) for GPS
- Enable high-accuracy location
- Wait for GPS to stabilize before marking points
- Compare calculated area with known measurements

### Performance Tips
- Limit polygon to ~20 points
- Clear old cached data periodically
- Use WiFi for initial data load
- Enable battery optimization exemption

## 📞 Support

**Issues with setup?**
- Check detailed guides in `SUPABASE_SETUP.md` and `GOOGLE_MAPS_SETUP.md`
- Review `IMPLEMENTATION_SUMMARY.md` for technical details

**Need help?**
- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Google Maps Platform](https://developers.google.com/maps)

## 🎯 Next Steps

Once everything is working:

1. ✅ Add more farms
2. ✅ Invite team members (add multi-user support)
3. ✅ Export data to CSV/PDF
4. ✅ Add weather integration
5. ✅ Implement offline mode
6. ✅ Add crop recommendations
7. ✅ Create harvest predictions
8. ✅ Build analytics dashboard

## 📊 Free Tier Limits

### Supabase (Free)
- 500 MB database
- 1 GB file storage
- 50,000 monthly active users
- 2 GB bandwidth

### Google Maps (Free)
- $200 monthly credit
- ~28,000 map loads
- ~40,000 API calls

**Both are more than enough for personal/small business use!**

---

**Status**: ✅ Ready to use
**Estimated total setup time**: 15-20 minutes
**Difficulty**: Easy to Moderate

Enjoy managing your farm! 🌾🚜
