-- TripMate: create one confirmed dev user (run BEFORE seed.sql if auth.users is empty)
-- Run in Supabase SQL Editor. Dev only — never production.
--
-- Login in app:
--   Email:    demo@tripmate.dev
--   Password: Demo123456!

create extension if not exists pgcrypto with schema extensions;

do $$
declare
  v_user_id uuid := gen_random_uuid();
  v_email text := 'demo@tripmate.dev';
  v_password text := 'Demo123456!';
  v_instance_id uuid;
begin
  if exists (select 1 from auth.users u where u.email = v_email) then
    raise notice 'Dev user % already exists — run seed.sql next.', v_email;
    return;
  end if;

  select i.id into v_instance_id from auth.instances i limit 1;
  if v_instance_id is null then
    v_instance_id := '00000000-0000-0000-0000-000000000000';
  end if;

  insert into auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) values (
    v_user_id,
    v_instance_id,
    'authenticated',
    'authenticated',
    v_email,
    extensions.crypt(v_password, extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"display_name":"Demo Traveler"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) values (
    gen_random_uuid(),
    v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    v_user_id::text,
    now(),
    now(),
    now()
  );

  raise notice 'Created dev user: % / password: % — profile via handle_new_user trigger.', v_email, v_password;
end $$;
