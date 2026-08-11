# 🏗️ Argi - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        USER DEVICE                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Flutter Application (Argi)               │  │
│  │                                                       │  │
│  │  ┌──────────────────┐  ┌──────────────────────────┐  │  │
│  │  │   Presentation   │  │     Business Logic       │  │  │
│  │  │     Layer        │  │        Layer             │  │  │
│  │  ├──────────────────┤  ├──────────────────────────┤  │  │
│  │  │ • AuthScreen     │  │ • SupabaseService        │  │  │
│  │  │ • FarmsListScreen│  │ • Farm Model             │  │  │
│  │  │ • FarmDetailScr. │  │ • Crop Model             │  │  │
│  │  │ • FarmMapScreen  │  │ • Area Calculator        │  │  │
│  │  │                  │  │ • Plant Count Logic      │  │  │
│  │  └────────┬─────────┘  └───────────┬──────────────┘  │  │
│  │           │                        │                  │  │
│  └───────────┼────────────────────────┼──────────────────┘  │
│              │                        │                     │
└──────────────┼────────────────────────┼─────────────────────┘
               │                        │
               │ HTTP/REST              │ HTTP/REST
               │                        │
    ┌──────────▼─────────┐   ┌─────────▼──────────┐
    │   Google Maps      │   │     Supabase       │
    │   Platform API     │   │   (Backend)        │
    │                    │   │                    │
    │ • Maps SDK         │   │ • PostgreSQL       │
    │ • Geocoding        │   │ • Authentication   │
    │ • Places (opt)     │   │ • Storage          │
    │ • Directions (opt) │   │ • Real-time        │
    └────────────────────┘   │ • Row-Level Sec.   │
                             └────────────────────┘
```

## Application Flow

### 1. Authentication Flow
```
┌─────────┐
│  Start  │
└────┬────┘
     │
     ▼
┌──────────────┐
│ Splash Screen│
└──────┬───────┘
       │
       ▼
   ┌───────────┐
   │User logged│
   │   in?     │
   └─────┬─────┘
         │
    ┌────┴────┐
    │         │
   No        Yes
    │         │
    ▼         ▼
┌────────┐  ┌──────────┐
│  Auth  │  │  Farms   │
│ Screen │  │   List   │
└────┬───┘  └──────────┘
     │
     ▼
┌─────────────┐
│ Login/Signup│
└──────┬──────┘
       │
       ▼
┌────────────────┐
│ Supabase Auth  │
└────────┬───────┘
         │
         ▼
┌─────────────────┐
│  Farms List     │
│  Screen         │
└─────────────────┘
```

### 2. Farm Management Flow
```
┌──────────────┐
│  Farms List  │
└──────┬───────┘
       │
       ├───── Add Farm ────► ┌──────────────┐
       │                     │ Add Dialog   │
       │                     └──────┬───────┘
       │                            │
       │                            ▼
       │                     ┌──────────────┐
       │                     │ Save to DB   │
       │                     └──────┬───────┘
       │                            │
       │◄───────────────────────────┘
       │
       ├───── View Farm ───► ┌──────────────┐
       │                     │ Farm Detail  │
       │                     └──────┬───────┘
       │                            │
       │                     ┌──────┴──────┐
       │                     │             │
       │                  Map Btn      Add Crop
       │                     │             │
       │                     ▼             ▼
       │              ┌────────────┐  ┌────────┐
       │              │ Farm Map   │  │ Crop   │
       │              │  Screen    │  │ Dialog │
       │              └────────────┘  └────────┘
       │
       └───── Delete Farm ──► ┌──────────────┐
                               │ Confirm      │
                               │ Dialog       │
                               └──────────────┘
```

### 3. Farm Mapping Flow (Core Feature)
```
┌──────────────┐
│   Farm Map   │
│   Screen     │
└──────┬───────┘
       │
       ├── Load Existing Polygon ──► ┌────────────────┐
       │                              │ Fetch from DB  │
       │                              │ Parse JSON     │
       │                              │ Draw Polygon   │
       │                              └────────────────┘
       │
       ├── Start Drawing Mode ──────► ┌────────────────┐
       │                              │ Enable Taps    │
       │                              │ Show Indicator │
       │                              └────────────────┘
       │
       ├── User Taps Map ───────────► ┌────────────────┐
       │                              │ Add LatLng     │
       │                              │ Create Marker  │
       │                              │ Update Polygon │
       │                              │ Calculate Area │
       │                              └────────────────┘
       │
       ├── Drag Marker ─────────────► ┌────────────────┐
       │                              │ Update LatLng  │
       │                              │ Redraw Polygon │
       │                              │ Recalculate    │
       │                              └────────────────┘
       │
       ├── Calculate Strategy ──────► ┌────────────────┐
       │                              │ Open Dialog    │
       │                              │ Adjust Sliders │
       │                              │ Estimate Plants│
       │                              └────────────────┘
       │
       └── Save Boundary ───────────► ┌────────────────┐
                                      │ Convert to JSON│
                                      │ Save to DB     │
                                      │ Update Farm    │
                                      └────────────────┘
```

## Data Flow

### Farm Creation
```
User Input → Validation → SupabaseService.createFarm()
    ↓
INSERT INTO farms (user_id, name, location, size)
    ↓
Returns Farm object with UUID
    ↓
Update UI (add to farms list)
```

### Polygon Mapping
```
User Taps → Add LatLng to List → Update Markers & Polygon
    ↓
Points >= 3? → Calculate Area (Shoelace Formula)
    ↓
Convert degrees to meters (consider Earth curvature)
    ↓
Display in m² and hectares
    ↓
User Saves → Convert to JSON → Update Supabase
```

### Area Calculation Algorithm
```
Input: List<LatLng> points

Step 1: Shoelace Formula
  area = 0
  for i = 0 to n-1:
    j = (i - 1 + n) % n
    area += (points[j].lng + points[i].lng) * 
            (points[j].lat - points[i].lat)
  area = abs(area) / 2

Step 2: Convert to Meters
  avgLat = mean(all latitudes)
  latMeters = 111,320 (constant)
  lngMeters = 111,320 * cos(avgLat * π/180)
  areaM² = area * latMeters * lngMeters

Output: Area in square meters
```

### Plant Count Estimation
```
Input:
  - totalArea (m²)
  - plantSpacing (cm)
  - rowSpacing (cm)

Process:
  plantSpacingM = plantSpacing / 100
  rowSpacingM = rowSpacing / 100
  areaPerPlant = plantSpacingM × rowSpacingM
  plantCount = floor(totalArea / areaPerPlant)

Output: Estimated number of plants
```

## Database Schema

```sql
┌─────────────────┐
│   auth.users    │ (Supabase built-in)
│   ─────────     │
│   • id (PK)     │
│   • email       │
│   • password    │
│   • created_at  │
└────────┬────────┘
         │
         │ 1:N
         ▼
┌────────────────────────┐
│        farms           │
│   ───────────────      │
│   • id (PK)            │
│   • user_id (FK)       │◄──┐
│   • name               │   │
│   • location           │   │
│   • size (DECIMAL)     │   │ 1:N
│   • polygon_coords     │   │
│   │   (JSONB)          │   │
│   • created_at         │   │
│   • updated_at         │   │
└────────┬───────────────┘   │
         │                   │
         │ 1:N               │
         ▼                   │
┌────────────────────────┐   │
│        crops           │   │
│   ───────────────      │   │
│   • id (PK)            │   │
│   • farm_id (FK)       │───┘
│   • name               │
│   • variety            │   ┌──┐
│   • planted_at         │   │  │ 1:N
│   • expected_harvest   │   │  │
│   • actual_harvest     │   │  │
│   • status             │   │  │
│   • notes              │   │  │
│   • created_at         │   │  │
│   • updated_at         │   │  │
└────────┬───────────────┘   │  │
         │                   │  │
         │ 1:N               │  │
         ▼                   │  │
┌────────────────────────┐   │  │
│      activities        │   │  │
│   ───────────────      │   │  │
│   • id (PK)            │   │  │
│   • farm_id (FK)       │───┘  │
│   • crop_id (FK)       │──────┘
│   • activity_type      │
│   • description        │
│   • metadata (JSONB)   │
│   • performed_at       │
└────────────────────────┘
```

## Component Hierarchy

```
ArgiApp (main.dart)
│
├─ SplashScreen
│  └─ AuthCheck
│     ├─ [Logged In] → FarmsListScreen
│     └─ [Not Logged In] → AuthScreen
│
├─ AuthScreen
│  ├─ Email TextField
│  ├─ Password TextField
│  ├─ Login Button → SupabaseService.signIn()
│  └─ Signup Toggle
│
├─ FarmsListScreen
│  ├─ AppBar
│  │  └─ Refresh Button
│  ├─ ListView
│  │  └─ FarmCard (foreach farm)
│  │     ├─ Farm Info
│  │     ├─ Details Button → FarmDetailScreen
│  │     ├─ Map Button → FarmMapScreen
│  │     └─ Delete Menu
│  └─ FloatingActionButton → Add Farm Dialog
│
├─ FarmDetailScreen
│  ├─ AppBar
│  │  ├─ Map Button → FarmMapScreen
│  │  └─ Edit Button
│  ├─ Farm Info Card
│  │  ├─ Location
│  │  ├─ Size
│  │  └─ Boundary Status
│  ├─ Crops Card
│  │  └─ CropsList
│  └─ Quick Actions Card
│     ├─ Irrigation Button
│     ├─ Fertilizer Button
│     ├─ Pest Control Button
│     └─ Harvest Button
│
└─ FarmMapScreen ⭐ (Main Feature)
   ├─ AppBar
   │  ├─ Calculator Button → Planting Dialog
   │  └─ Edit Toggle
   ├─ GoogleMap
   │  ├─ Polygon (farm boundary)
   │  ├─ Markers (boundary points)
   │  ├─ OnTap Handler
   │  └─ OnMarkerDrag Handler
   ├─ Info Card Overlay
   │  ├─ Area in hectares
   │  └─ Area in m²
   ├─ Drawing Status Badge
   └─ BottomAppBar
      ├─ Undo Button
      ├─ Clear Button
      └─ Save Button
```

## State Management

```
Current Implementation: StatefulWidget + setState

┌─────────────────┐
│  Screen State   │
├─────────────────┤
│ • _farms        │
│ • _isLoading    │
│ • _polygonPts   │
│ • _markers      │
│ • _calculatedA. │
└────────┬────────┘
         │
         ▼
    setState() triggers rebuild
         │
         ▼
┌─────────────────┐
│   UI Updates    │
└─────────────────┘

Future Enhancement Options:
• Riverpod for global state
• Provider for dependency injection
• Bloc for complex state logic
```

## Security Architecture

```
┌──────────────────────────────────────┐
│         Flutter App (Client)         │
└─────────────┬────────────────────────┘
              │
              │ HTTPS + JWT
              │
┌─────────────▼────────────────────────┐
│        Supabase API Layer            │
│  ┌────────────────────────────────┐  │
│  │     Authentication Check       │  │
│  │  (JWT token validation)        │  │
│  └──────────────┬─────────────────┘  │
│                 │                     │
│                 ▼                     │
│  ┌────────────────────────────────┐  │
│  │   Row Level Security (RLS)     │  │
│  │                                │  │
│  │  SELECT: user_id = auth.uid()  │  │
│  │  INSERT: user_id = auth.uid()  │  │
│  │  UPDATE: user_id = auth.uid()  │  │
│  │  DELETE: user_id = auth.uid()  │  │
│  └──────────────┬─────────────────┘  │
│                 │                     │
│                 ▼                     │
│  ┌────────────────────────────────┐  │
│  │     PostgreSQL Database        │  │
│  │                                │  │
│  │  Only returns rows where       │  │
│  │  user_id matches current user  │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘

Security Features:
✅ JWT authentication
✅ Row-level security
✅ HTTPS encryption
✅ SQL injection prevention
✅ XSS protection
✅ Rate limiting (Supabase)
```

## Technology Stack

### Frontend
```
┌────────────────────┐
│      Flutter       │
│    Framework       │
├────────────────────┤
│ • Dart Language    │
│ • Material Design  │
│ • Hot Reload       │
│ • Cross-platform   │
└────────────────────┘
```

### Key Packages
```
google_maps_flutter (2.5.0)
  └─ Google Maps integration

geolocator (10.1.0)
  └─ GPS & location services

supabase_flutter (2.16.0)
  └─ Backend integration

permission_handler (11.0.1)
  └─ Runtime permissions
```

### Backend
```
┌────────────────────┐
│     Supabase       │
├────────────────────┤
│ • PostgreSQL DB    │
│ • Auth Service     │
│ • REST API         │
│ • Real-time        │
│ • Storage          │
└────────────────────┘
```

### External APIs
```
┌────────────────────┐
│   Google Maps      │
│    Platform        │
├────────────────────┤
│ • Maps SDK         │
│ • Geocoding        │
│ • Places           │
└────────────────────┘
```

## Performance Considerations

### Optimizations Implemented
```
✅ Lazy loading (farms list)
✅ Pagination ready (database)
✅ Indexed queries (user_id, dates)
✅ Efficient polygon rendering
✅ Debounced area calculation
✅ Cached map tiles
```

### Future Optimizations
```
⏳ Image compression
⏳ Offline data caching
⏳ Background sync
⏳ Query result caching
⏳ Optimistic UI updates
```

## Deployment Architecture

```
Development
  └─ Local Device/Emulator
     └─ Debug APK

Staging (Optional)
  └─ TestFlight / Firebase App Distribution
     └─ Beta APK

Production
  └─ Google Play Store
     └─ Release APK (Signed)

Backend (All Environments)
  └─ Supabase Cloud
     ├─ Development Project
     ├─ Staging Project (optional)
     └─ Production Project
```

## Error Handling Flow

```
User Action
    ↓
Try Block
    ↓
API Call / Operation
    ↓
┌───────┴───────┐
│               │
Success       Error
│               │
▼               ▼
Update       Catch Block
State            │
│                ▼
│           Log Error
│                │
│                ▼
│         Show SnackBar
│                │
│                ▼
│         Maintain State
│                │
└────────┬───────┘
         ▼
     UI Updates
```

---

This architecture is designed to be:
- **Scalable**: Can handle thousands of users
- **Maintainable**: Clear separation of concerns
- **Secure**: Row-level security + authentication
- **Performant**: Optimized queries and rendering
- **Extensible**: Easy to add new features
