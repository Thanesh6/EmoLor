-- ==============================================================================
-- MIGRATION: ADD MISSING PROFILE FIELDS & FIX REGISTRATION TRIGGER
-- Run this script in the Supabase SQL Editor to fix the 500 Registration Error.
-- ==============================================================================

-- 1. Add the missing columns that the Flutter app is trying to save
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS account_type TEXT,
ADD COLUMN IF NOT EXISTS parent_pin_hash TEXT;

-- 2. Create/Update the trigger function that transfers auth metadata to profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id, 
    email, 
    name, 
    role, 
    phone, 
    account_type, 
    parent_pin_hash
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'caregiver'),
    NEW.raw_user_meta_data->>'phone',
    NEW.raw_user_meta_data->>'account_type',
    NEW.raw_user_meta_data->>'parent_pin_hash'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Ensure the trigger is actively attached to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
