# Database Migration Guide
## Upgrading to Unified Child-Caregiver Architecture

### ⚠️ Important Notes
- This migration involves **breaking changes**
- Backup your data before proceeding
- This is suitable for early development; production migrations need more careful handling
- All existing child user accounts will need to be converted to profiles

---

## Step 1: Backup Existing Data (If Any)

If you have existing data in your development database:

```sql
-- Backup existing children data
CREATE TABLE children_backup AS SELECT * FROM children;

-- Backup existing activity progress
CREATE TABLE activity_progress_backup AS SELECT * FROM activity_progress;

-- Backup existing emotion entries
CREATE TABLE emotion_entries_backup AS SELECT * FROM emotion_entries;
```

---

## Step 2: Drop Old Schema

Run this in your Supabase SQL Editor:

```sql
-- Drop all existing tables in reverse dependency order
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS insights CASCADE;
DROP TABLE IF EXISTS activity_progress CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS emotion_entries CASCADE;
DROP TABLE IF EXISTS emotion_colors CASCADE;
DROP TABLE IF EXISTS children CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop old functions if they exist
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;
DROP FUNCTION IF EXISTS get_child_total_points CASCADE;
DROP FUNCTION IF EXISTS get_child_activity_stats CASCADE;
```

---

## Step 3: Run New Schema

1. Open Supabase Dashboard → SQL Editor
2. Copy the **entire contents** of `supabase_schema.sql`
3. Paste into a new query
4. Click **Run**

This will create:
- ✅ New `users` table (caregiver, therapist, admin only)
- ✅ New `child_profiles` table (replaces `children`)
- ✅ Updated `emotion_colors`, `emotion_entries`, `sessions` tables
- ✅ Enhanced `activity_progress` table
- ✅ New `rewards` table
- ✅ Updated `insights` and `notifications` tables
- ✅ All RLS policies
- ✅ Helper functions
- ✅ Sample activities

---

## Step 4: Create Test Accounts

### Option A: Through Supabase Dashboard

1. Go to **Authentication → Users**
2. Click **Add User**
3. Create accounts with these roles:

**Test Caregiver:**
- Email: `parent@test.com`
- Password: `test123456`
- After creation, run:
```sql
INSERT INTO users (id, email, name, role) 
VALUES 
  ('your-auth-user-id-here', 'parent@test.com', 'Test Parent', 'caregiver');
```

**Test Therapist:**
- Email: `therapist@test.com`
- Password: `test123456`
- After creation, run:
```sql
INSERT INTO users (id, email, name, role) 
VALUES 
  ('your-auth-user-id-here', 'therapist@test.com', 'Dr. Sarah', 'therapist');
```

### Option B: Through SQL (Development Only)

```sql
-- This is a simplified approach for development
-- In production, users should sign up through your app

-- Assuming you've manually created auth users, link them to roles:
INSERT INTO users (id, email, name, role) VALUES
  ('YOUR_CAREGIVER_AUTH_ID', 'parent@test.com', 'Test Parent', 'caregiver'),
  ('YOUR_THERAPIST_AUTH_ID', 'therapist@test.com', 'Dr. Sarah', 'therapist'),
  ('YOUR_ADMIN_AUTH_ID', 'admin@test.com', 'Admin User', 'admin');
```

---

## Step 5: Create Test Child Profiles

After logging in as a caregiver, you can create profiles through the app, OR run:

```sql
-- Replace 'YOUR_CAREGIVER_AUTH_ID' with actual caregiver user ID
INSERT INTO child_profiles (caregiver_id, name, age, date_of_birth, avatar_url) VALUES
  ('YOUR_CAREGIVER_AUTH_ID', 'Emma', 6, '2019-03-15', '👧'),
  ('YOUR_CAREGIVER_AUTH_ID', 'Leo', 8, '2017-07-22', '👦');
```

---

## Step 6: Create Test Activity Progress

```sql
-- Get IDs first
-- SELECT id FROM child_profiles WHERE name = 'Emma';
-- SELECT id FROM activities WHERE title = 'Emotion Color Wheel';

INSERT INTO activity_progress 
  (child_profile_id, activity_id, status, completion_percentage, time_spent_seconds, stars_earned, completed_at)
VALUES
  (
    'EMMA_PROFILE_ID', 
    'ACTIVITY_ID',
    'completed',
    100,
    420, -- 7 minutes
    3,
    NOW()
  );
```

---

## Step 7: Create Test Rewards

```sql
INSERT INTO rewards 
  (child_profile_id, reward_type, title, description, points, icon, metadata)
VALUES
  (
    'EMMA_PROFILE_ID',
    'completion',
    'Activity Master!',
    'Completed your first activity',
    50,
    '🏆',
    '{"activity_id": "ACTIVITY_ID"}'::jsonb
  ),
  (
    'EMMA_PROFILE_ID',
    'time_milestone',
    'Getting Started',
    'Spent 5 minutes learning',
    10,
    '⏱️',
    '{"minutes": 5}'::jsonb
  );
```

---

## Step 8: Verify Setup

Run these queries to verify everything is set up correctly:

```sql
-- Check users
SELECT id, email, role, name FROM users;

-- Check child profiles
SELECT cp.*, u.name as caregiver_name 
FROM child_profiles cp
JOIN users u ON cp.caregiver_id = u.id;

-- Check activities
SELECT id, title, activity_type, age_range_min, age_range_max 
FROM activities 
WHERE is_active = true;

-- Check activity progress
SELECT 
  cp.name as child_name,
  a.title as activity_name,
  ap.status,
  ap.stars_earned,
  ap.time_spent_seconds / 60 as minutes_spent
FROM activity_progress ap
JOIN child_profiles cp ON ap.child_profile_id = cp.id
JOIN activities a ON ap.activity_id = a.id;

-- Check rewards
SELECT 
  cp.name as child_name,
  r.reward_type,
  r.title,
  r.points
FROM rewards r
JOIN child_profiles cp ON r.child_profile_id = cp.id
ORDER BY r.earned_at DESC;

-- Test helper functions
SELECT get_child_total_points('EMMA_PROFILE_ID');
SELECT * FROM get_child_activity_stats('EMMA_PROFILE_ID');
```

---

## Step 9: Test RLS Policies

Log in as the caregiver in your app and verify:
- ✅ Can see only their own child profiles
- ✅ Can create new child profiles
- ✅ Can view their children's progress
- ✅ Can view their children's rewards
- ❌ Cannot see other caregivers' children
- ❌ Cannot access therapist-only data

Log in as the therapist and verify:
- ✅ Can see assigned children
- ✅ Can view children's progress and data
- ✅ Can create sessions
- ❌ Cannot edit child profiles
- ❌ Cannot see non-assigned children

---

## Step 10: Set Up Storage Buckets

1. Go to **Storage** in Supabase Dashboard
2. Create these buckets:

### Avatars Bucket (Public)
- Name: `avatars`
- Public: ✅ Yes
- File size limit: 1 MB
- Allowed MIME types: `image/jpeg, image/png, image/webp`

**RLS Policies:**
```sql
-- Anyone can view avatars
CREATE POLICY "Public avatars are viewable by everyone"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- Authenticated users can upload avatars
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
);
```

### Activity Content Bucket (Public)
- Name: `activity_content`
- Public: ✅ Yes
- File size limit: 10 MB

**RLS Policies:**
```sql
-- Anyone can view activity content
CREATE POLICY "Public activity content is viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'activity_content');

-- Only admins can upload activity content
CREATE POLICY "Only admins can upload activity content"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'activity_content'
  AND EXISTS (
    SELECT 1 FROM users 
    WHERE users.id = auth.uid() 
    AND users.role = 'admin'
  )
);
```

### Session Attachments Bucket (Private)
- Name: `session_attachments`
- Public: ❌ No
- File size limit: 5 MB

**RLS Policies:**
```sql
-- Therapists can upload session attachments
CREATE POLICY "Therapists can upload session attachments"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'session_attachments'
  AND EXISTS (
    SELECT 1 FROM users 
    WHERE users.id = auth.uid() 
    AND users.role = 'therapist'
  )
);

-- Users can view session attachments they have access to
CREATE POLICY "Users can view accessible session attachments"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'session_attachments'
  AND (
    -- Therapists who created it
    (storage.foldername(name))[1] = auth.uid()::text
    OR
    -- Admins can see all
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'admin'
    )
  )
);
```

---

## Common Issues & Solutions

### Issue: "Row Level Security policy violation"
**Solution:** Make sure you're logged in with the correct role user. Caregivers can only access their own children.

### Issue: "Foreign key constraint violation"
**Solution:** Ensure parent records exist before inserting child records. Order: users → child_profiles → progress/rewards

### Issue: "UUID not found"
**Solution:** Replace placeholder UUIDs (`YOUR_CAREGIVER_AUTH_ID`, etc.) with actual UUIDs from your database.

### Issue: Helper functions not working
**Solution:** Make sure you ran the entire schema including the function definitions at the bottom.

### Issue: Activities not showing in app
**Solution:** Check `is_active = true` and verify age ranges match your test child's age.

---

## Data Migration Script (If You Have Existing Data)

If you had data in the old schema:

```sql
-- Migrate children to child_profiles
-- Note: This assumes you have a caregiver account already
INSERT INTO child_profiles (id, caregiver_id, name, age, date_of_birth, avatar_url, created_at, updated_at)
SELECT 
  cb.id,
  'YOUR_DEFAULT_CAREGIVER_ID', -- You'll need to set this
  cb.name,
  cb.age,
  cb.date_of_birth,
  cb.avatar_url,
  cb.created_at,
  cb.updated_at
FROM children_backup cb;

-- Note: You'll need to manually assign correct caregiver_id for each child
-- UPDATE child_profiles SET caregiver_id = 'CORRECT_CAREGIVER_ID' WHERE ...

-- Migrate activity progress
INSERT INTO activity_progress (id, child_profile_id, activity_id, status, completion_percentage, time_spent_seconds, completed_at, created_at, updated_at)
SELECT 
  apb.id,
  apb.child_id, -- This maps to child_profile_id now
  apb.activity_id,
  apb.status,
  apb.completion_percentage,
  apb.time_spent_minutes * 60, -- Convert to seconds
  apb.completed_at,
  apb.created_at,
  apb.updated_at
FROM activity_progress_backup apb;
```

---

## Verification Checklist

After migration, verify:

- [ ] Can log in as caregiver
- [ ] Profile selection screen shows up
- [ ] Can create new child profile
- [ ] Can select child profile
- [ ] Caregiver dashboard shows children
- [ ] Can log in as therapist (separate login)
- [ ] Therapist can see assigned children
- [ ] Activities load correctly
- [ ] Progress tracking works
- [ ] Rewards are displayed
- [ ] RLS policies prevent unauthorized access

---

## Rollback Plan

If something goes wrong:

```sql
-- Restore from backup
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS child_profiles CASCADE;
-- ... drop all new tables

-- Restore old tables
CREATE TABLE users AS SELECT * FROM users_backup;
CREATE TABLE children AS SELECT * FROM children_backup;
-- ... restore other tables
```

---

## Next Steps After Migration

1. Update Flutter app dependencies: `flutter pub get`
2. Run the app: `flutter run`
3. Test the complete flow
4. Create additional test data as needed
5. Begin implementing remaining features (child home, activities, rewards display)

---

**Migration complete! Your database is now ready for the unified child-caregiver architecture. 🎉**
