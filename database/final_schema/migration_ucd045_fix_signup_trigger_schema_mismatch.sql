-- ======================================================================
-- MIGRATION UCD045: FIX SIGNUP TRIGGER SCHEMA MISMATCH (id vs user_id)
--
-- Purpose:
-- - Prevent Supabase auth signup 500 errors caused by trigger insert failures
-- - Support both legacy profiles.user_id and newer profiles.id schemas
-- - Normalize unsupported roles (e.g. organization) to caregiver for DB CHECK
--
-- Run this in Supabase SQL Editor after UCD044.
-- ======================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS account_type TEXT,
ADD COLUMN IF NOT EXISTS parent_pin_hash TEXT;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  target_role TEXT;
  has_user_id_column BOOLEAN;
BEGIN
  target_role := COALESCE(NEW.raw_user_meta_data->>'role', 'caregiver');
  IF target_role NOT IN ('caregiver', 'therapist', 'admin') THEN
    target_role := 'caregiver';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'user_id'
  )
  INTO has_user_id_column;

  IF has_user_id_column THEN
    UPDATE public.profiles
    SET
      email = NEW.email,
      name = COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'),
      role = target_role,
      phone = NEW.raw_user_meta_data->>'phone',
      account_type = NEW.raw_user_meta_data->>'account_type',
      parent_pin_hash = NEW.raw_user_meta_data->>'parent_pin_hash',
      updated_at = NOW()
    WHERE user_id = NEW.id;

    IF NOT FOUND THEN
      INSERT INTO public.profiles (
        user_id,
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
        target_role,
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'account_type',
        NEW.raw_user_meta_data->>'parent_pin_hash'
      );
    END IF;
  ELSE
    UPDATE public.profiles
    SET
      email = NEW.email,
      name = COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown User'),
      role = target_role,
      phone = NEW.raw_user_meta_data->>'phone',
      account_type = NEW.raw_user_meta_data->>'account_type',
      parent_pin_hash = NEW.raw_user_meta_data->>'parent_pin_hash',
      updated_at = NOW()
    WHERE id = NEW.id;

    IF NOT FOUND THEN
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
        target_role,
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'account_type',
        NEW.raw_user_meta_data->>'parent_pin_hash'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
DECLARE
  trigger_name TEXT;
BEGIN
  FOR trigger_name IN
    SELECT t.tgname
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth'
      AND c.relname = 'users'
      AND NOT t.tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users;', trigger_name);
  END LOOP;
END
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
