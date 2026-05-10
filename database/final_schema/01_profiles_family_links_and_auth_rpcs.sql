-- Run this in Supabase SQL Editor
-- Replaces broken trigger with a reliable RPC function approach

-- 1. Drop the broken trigger (no longer needed)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. Create a SECURITY DEFINER function that inserts the profile
--    Called directly from the Flutter app after signUp()
--    SECURITY DEFINER = runs as postgres (superuser), bypasses RLS entirely
CREATE OR REPLACE FUNCTION public.create_profile(
  p_user_id   UUID,
  p_email     TEXT,
  p_full_name TEXT,
  p_role      TEXT      DEFAULT 'caregiver',
  p_phone_number    TEXT DEFAULT NULL,
  p_account_type    TEXT DEFAULT NULL,
  p_parent_pin_hash TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    user_id,
    email,
    full_name,
    role,
    phone_number,
    account_type,
    parent_pin_hash
  )
  VALUES (
    p_user_id,
    p_email,
    p_full_name,
    p_role::user_role,
    p_phone_number,
    p_account_type,
    p_parent_pin_hash
  );
EXCEPTION
  WHEN unique_violation THEN
    -- Profile already exists, ignore (idempotent)
    NULL;
END;
$$;

-- 3. Allow anon and authenticated roles to call this function
GRANT EXECUTE ON FUNCTION public.create_profile TO anon, authenticated;

-- 4. RPC to fetch user role (bypasses RLS to avoid infinite recursion)
DROP FUNCTION IF EXISTS public.get_user_role(UUID);
CREATE OR REPLACE FUNCTION public.get_user_role(p_user_id UUID)
RETURNS TABLE(role TEXT, account_type TEXT, full_name TEXT, avatar_url TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT p.role::TEXT, p.account_type, p.full_name, p.avatar_url
  FROM public.profiles p
  WHERE p.user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_role TO anon, authenticated;

-- 5. RPC to create a child profile + family_link (bypasses RLS, handles ENUM)
CREATE OR REPLACE FUNCTION public.create_child_profile(
  p_caregiver_id  UUID,
  p_full_name     TEXT,
  p_date_of_birth DATE DEFAULT NULL,
  p_avatar_url    TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_child_user_id UUID := gen_random_uuid();
  v_profile_id UUID;
BEGIN
  INSERT INTO public.profiles (user_id, full_name, date_of_birth, avatar_url, role)
  VALUES (v_child_user_id, p_full_name, p_date_of_birth, p_avatar_url, 'child'::user_role)
  RETURNING profile_id INTO v_profile_id;

  INSERT INTO public.family_links (caregiver_id, child_id)
  VALUES (p_caregiver_id, v_child_user_id);

  RETURN json_build_object(
    'profile_id', v_profile_id,
    'user_id', v_child_user_id,
    'full_name', p_full_name,
    'date_of_birth', p_date_of_birth,
    'avatar_url', p_avatar_url,
    'role', 'child'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_child_profile TO authenticated;

-- 6. RPC to get child profiles for a caregiver (bypasses RLS)
CREATE OR REPLACE FUNCTION public.get_child_profiles(p_caregiver_id UUID)
RETURNS SETOF JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT row_to_json(p.*)
  FROM public.profiles p
  INNER JOIN public.family_links fl ON fl.child_id = p.user_id
  WHERE fl.caregiver_id = p_caregiver_id
  ORDER BY p.full_name;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_child_profiles TO authenticated;
