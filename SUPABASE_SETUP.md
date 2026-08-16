# Supabase Setup Guide for Argi

## Step 1: Create Supabase Project

1. Go to [Supabase](https://supabase.com/)
2. Sign up or log in
3. Click **"New Project"**
4. Fill in:
   - **Project Name**: `argi` (or your preferred name)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Free tier is fine for development

5. Wait for project to be created (~2 minutes)

## Step 2: Get Your API Credentials

1. In your Supabase project dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon public** key (long string starting with `eyJ...`)

3. Update `lib/main.dart`:
```dart
await Supabase.initialize(
  url: 'https://xxxxx.supabase.co',  // Your Project URL
  anonKey: 'eyJ...',                  // Your anon public key
);
```

## Step 3: Create Database Tables

If the app shows `PGRST205` or says it cannot find `public.farms`, run the
complete file `docs/supabase/farms_table_setup.sql` in Supabase SQL Editor
first. It creates the `farms` table, grants the authenticated app access, and
adds owner-only RLS policies.

After the farm table works, run `docs/supabase/monitoring_setup.sql`. It creates
the `plots` and `soil_readings` tables used by both handheld and stationary ESP32
monitoring.

See `docs/hardware/ESP32_MONITORING_WORKFLOW.md` for the app workflow and MQTT
payload expected by the monitor.

Go to **SQL Editor** in Supabase dashboard and run these SQL commands:

### 1. Create Farms Table
```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Farms table
CREATE TABLE farms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  size DECIMAL NOT NULL,
  polygon_coordinates JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ
);

-- Used by the create-farm form to store the main crop.
ALTER TABLE farms ADD COLUMN IF NOT EXISTS crop_type TEXT NOT NULL DEFAULT 'rice';

-- Index for faster queries
CREATE INDEX idx_farms_user_id ON farms(user_id);
CREATE INDEX idx_farms_created_at ON farms(created_at DESC);

-- Row Level Security (RLS)
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only see their own farms
CREATE POLICY "Users can view their own farms"
  ON farms FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own farms"
  ON farms FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own farms"
  ON farms FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own farms"
  ON farms FOR DELETE
  USING (auth.uid() = user_id);
```

### 2. Create Crops Table
```sql
-- Crops table
CREATE TABLE crops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  variety TEXT NOT NULL,
  planted_at TIMESTAMPTZ NOT NULL,
  expected_harvest TIMESTAMPTZ,
  actual_harvest TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'growing',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ,
  CONSTRAINT valid_status CHECK (status IN ('growing', 'harvested', 'failed'))
);

-- Indexes
CREATE INDEX idx_crops_farm_id ON crops(farm_id);
CREATE INDEX idx_crops_planted_at ON crops(planted_at DESC);
CREATE INDEX idx_crops_status ON crops(status);

-- RLS
ALTER TABLE crops ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only see crops from their farms
CREATE POLICY "Users can view crops from their farms"
  ON crops FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = crops.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert crops to their farms"
  ON crops FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = crops.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update crops in their farms"
  ON crops FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = crops.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete crops from their farms"
  ON crops FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = crops.farm_id
      AND farms.user_id = auth.uid()
    )
  );
```

### 3. Create Activities Table
```sql
-- Activities/logs table
CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  farm_id UUID REFERENCES farms(id) ON DELETE CASCADE NOT NULL,
  crop_id UUID REFERENCES crops(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,
  description TEXT NOT NULL,
  metadata JSONB,
  performed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_activities_farm_id ON activities(farm_id);
CREATE INDEX idx_activities_crop_id ON activities(crop_id);
CREATE INDEX idx_activities_performed_at ON activities(performed_at DESC);
CREATE INDEX idx_activities_type ON activities(activity_type);

-- RLS
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view activities from their farms"
  ON activities FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = activities.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert activities to their farms"
  ON activities FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = activities.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update activities in their farms"
  ON activities FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = activities.farm_id
      AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete activities from their farms"
  ON activities FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = activities.farm_id
      AND farms.user_id = auth.uid()
    )
  );
```

### 4. Create Helpful Functions (Optional)
```sql
-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to farms table
CREATE TRIGGER update_farms_updated_at
  BEFORE UPDATE ON farms
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Apply to crops table
CREATE TRIGGER update_crops_updated_at
  BEFORE UPDATE ON crops
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

## Step 4: Enable Email Authentication

1. Go to **Authentication** → **Providers**
2. Enable **Email** provider (should be enabled by default)
3. Configure email templates if desired:
   - Go to **Authentication** → **Email Templates**
   - Customize confirmation and password reset emails

## Step 5: Test Your Setup

### Test Database Connection
1. Go to **Table Editor** in Supabase
2. You should see: `farms`, `crops`, `activities` tables
3. Check that RLS is enabled (shield icon should be visible)

### Test Authentication
1. Go to **Authentication** → **Users**
2. Click **"Add user"** → **"Create new user"**
3. Create a test user
4. Try logging in with the app

## Step 6: Verify Data Structure

Your database structure should look like this:

```
auth.users (built-in)
  └── farms (your table)
      ├── id (UUID, PK)
      ├── user_id (UUID, FK → auth.users)
      ├── name (TEXT)
      ├── location (TEXT)
      ├── size (DECIMAL)
      ├── polygon_coordinates (JSONB)
      │   └── [{"lat": 14.xxx, "lng": 120.xxx}, ...]
      ├── created_at (TIMESTAMPTZ)
      └── updated_at (TIMESTAMPTZ)
      
      └── crops (your table)
          ├── id (UUID, PK)
          ├── farm_id (UUID, FK → farms)
          ├── name (TEXT)
          ├── variety (TEXT)
          ├── planted_at (TIMESTAMPTZ)
          ├── expected_harvest (TIMESTAMPTZ)
          ├── actual_harvest (TIMESTAMPTZ)
          ├── status (TEXT: growing|harvested|failed)
          ├── notes (TEXT)
          ├── created_at (TIMESTAMPTZ)
          └── updated_at (TIMESTAMPTZ)
          
          └── activities (your table)
              ├── id (UUID, PK)
              ├── farm_id (UUID, FK → farms)
              ├── crop_id (UUID, FK → crops)
              ├── activity_type (TEXT)
              ├── description (TEXT)
              ├── metadata (JSONB)
              └── performed_at (TIMESTAMPTZ)
```

## Step 7: Test with Sample Data (Optional)

Run this SQL to create test data:

```sql
-- Insert a test farm (replace 'YOUR_USER_ID' with actual user UUID from auth.users)
INSERT INTO farms (user_id, name, location, size, polygon_coordinates)
VALUES (
  'YOUR_USER_ID',
  'Test Farm',
  'Pampanga, Philippines',
  15000,
  '[
    {"lat": 14.5995, "lng": 120.9842},
    {"lat": 14.5996, "lng": 120.9843},
    {"lat": 14.5997, "lng": 120.9842},
    {"lat": 14.5996, "lng": 120.9841}
  ]'::jsonb
);

-- Insert a test crop
INSERT INTO crops (farm_id, name, variety, planted_at, expected_harvest, status)
VALUES (
  (SELECT id FROM farms WHERE name = 'Test Farm' LIMIT 1),
  'Rice',
  'IR64',
  NOW() - INTERVAL '30 days',
  NOW() + INTERVAL '90 days',
  'growing'
);
```

## Security Notes

### Row Level Security (RLS)
- ✅ **Enabled** on all tables
- ✅ Users can only access their own data
- ✅ Prevents unauthorized access even if API keys leak

### API Keys
- **anon key**: Safe to use in Flutter app (public)
- **service_role key**: ⚠️ NEVER use in Flutter app (server-only)

### Best Practices
1. Never commit API keys to public repositories
2. Use environment variables for production
3. Enable email verification in production
4. Set up backup policies
5. Monitor usage in Supabase dashboard

## Troubleshooting

### "relation does not exist" error
- Run the CREATE TABLE SQL commands again
- Check you're in the correct project

### "row-level security policy" error
- Ensure RLS policies are created
- Check user is authenticated
- Verify user_id matches auth.uid()

### Can't see data in app
- Check Supabase credentials in main.dart
- Verify user is logged in
- Check RLS policies allow SELECT

### "permission denied" errors
- RLS policies might be too restrictive
- Check user_id in data matches authenticated user
- Verify foreign key relationships

## Production Checklist

Before deploying to production:

- [ ] Update Supabase URL and keys in main.dart
- [ ] Enable email verification
- [ ] Set up custom domain (optional)
- [ ] Configure email templates
- [ ] Set up database backups
- [ ] Monitor usage and set billing alerts
- [ ] Add indexes for performance
- [ ] Test RLS policies thoroughly
- [ ] Set up error monitoring
- [ ] Create admin user

## Next Steps

1. ✅ Complete Google Maps setup (see GOOGLE_MAPS_SETUP.md)
2. Test authentication flow
3. Create your first farm
4. Map farm boundaries
5. Add crops and start tracking!

## Support

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Flutter Documentation](https://supabase.com/docs/reference/dart)
- [Community Discord](https://discord.supabase.com/)
