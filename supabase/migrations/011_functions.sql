-- TripMate: RPC functions
-- All verify auth.uid() and trip membership where applicable

-- ---------------------------------------------------------------------------
-- Helpers (also used by RLS)
-- ---------------------------------------------------------------------------

create or replace function public.is_trip_member(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = p_trip_id
      and tm.user_id = auth.uid()
  );
$$;

create or replace function public.is_trip_owner(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = p_trip_id
      and tm.user_id = auth.uid()
      and tm.role = 'owner'
  );
$$;

revoke all on function public.is_trip_member(uuid) from public;
grant execute on function public.is_trip_member(uuid) to authenticated;

revoke all on function public.is_trip_owner(uuid) from public;
grant execute on function public.is_trip_owner(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 1. create_expense
-- ---------------------------------------------------------------------------

create or replace function public.create_expense(
  p_trip_id uuid,
  p_description text,
  p_amount bigint,
  p_category text default 'other',
  p_paid_by uuid default null,
  p_expense_date timestamptz default now(),
  p_note text default null,
  p_participants jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_paid_by uuid;
  v_expense_id uuid;
  v_share_sum bigint;
  v_participant record;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than 0';
  end if;

  if p_description is null or length(trim(p_description)) = 0 then
    raise exception 'Description is required';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip';
  end if;

  v_paid_by := coalesce(p_paid_by, v_uid);

  if not exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = p_trip_id
      and tm.user_id = v_paid_by
  ) then
    raise exception 'Payer is not a member of this trip';
  end if;

  if p_participants is null
     or jsonb_typeof(p_participants) <> 'array'
     or jsonb_array_length(p_participants) = 0 then
    raise exception 'At least one participant is required';
  end if;

  -- Validate every participant is a trip member and collect share sum
  select coalesce(sum((p->>'share_amount')::bigint), 0)
  into v_share_sum
  from jsonb_array_elements(p_participants) as p;

  if v_share_sum <> p_amount then
    raise exception 'Sum of share amounts (%) must equal expense amount (%)',
      v_share_sum, p_amount;
  end if;

  for v_participant in
    select
      (p->>'user_id')::uuid as user_id,
      (p->>'share_amount')::bigint as share_amount
    from jsonb_array_elements(p_participants) as p
  loop
    if v_participant.user_id is null then
      raise exception 'Participant user_id is required';
    end if;

    if v_participant.share_amount is null or v_participant.share_amount < 0 then
      raise exception 'Participant share_amount must be >= 0';
    end if;

    if not exists (
      select 1
      from public.trip_members tm
      where tm.trip_id = p_trip_id
        and tm.user_id = v_participant.user_id
    ) then
      raise exception 'Participant % is not a member of this trip', v_participant.user_id;
    end if;
  end loop;

  insert into public.expenses (
    trip_id,
    description,
    amount,
    category,
    paid_by,
    expense_date,
    note,
    created_by
  )
  values (
    p_trip_id,
    trim(p_description),
    p_amount,
    coalesce(nullif(trim(p_category), ''), 'other'),
    v_paid_by,
    coalesce(p_expense_date, now()),
    p_note,
    v_uid
  )
  returning id into v_expense_id;

  insert into public.expense_participants (expense_id, user_id, share_amount)
  select
    v_expense_id,
    (p->>'user_id')::uuid,
    (p->>'share_amount')::bigint
  from jsonb_array_elements(p_participants) as p;

  return v_expense_id;
end;
$$;

revoke all on function public.create_expense(
  uuid, text, bigint, text, uuid, timestamptz, text, jsonb
) from public;
grant execute on function public.create_expense(
  uuid, text, bigint, text, uuid, timestamptz, text, jsonb
) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. get_trip_balances
-- net = amount_paid - amount_owed + settlements_from - settlements_to
-- ---------------------------------------------------------------------------

create or replace function public.get_trip_balances(p_trip_id uuid)
returns table (
  user_id uuid,
  amount_paid bigint,
  amount_owed bigint,
  net_balance bigint,
  display_name text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip';
  end if;

  return query
  with members as (
    select tm.user_id, p.display_name
    from public.trip_members tm
    join public.profiles p on p.id = tm.user_id
    where tm.trip_id = p_trip_id
  ),
  paid as (
    select e.paid_by as uid, coalesce(sum(e.amount), 0)::bigint as total
    from public.expenses e
    where e.trip_id = p_trip_id
    group by e.paid_by
  ),
  owed as (
    select ep.user_id as uid, coalesce(sum(ep.share_amount), 0)::bigint as total
    from public.expense_participants ep
    join public.expenses e on e.id = ep.expense_id
    where e.trip_id = p_trip_id
    group by ep.user_id
  ),
  settled_from as (
    select s.from_user_id as uid, coalesce(sum(s.amount), 0)::bigint as total
    from public.settlements s
    where s.trip_id = p_trip_id
      and s.status = 'completed'
    group by s.from_user_id
  ),
  settled_to as (
    select s.to_user_id as uid, coalesce(sum(s.amount), 0)::bigint as total
    from public.settlements s
    where s.trip_id = p_trip_id
      and s.status = 'completed'
    group by s.to_user_id
  )
  select
    m.user_id,
    coalesce(paid.total, 0)::bigint as amount_paid,
    coalesce(owed.total, 0)::bigint as amount_owed,
    (
      coalesce(paid.total, 0)
      - coalesce(owed.total, 0)
      + coalesce(settled_from.total, 0)
      - coalesce(settled_to.total, 0)
    )::bigint as net_balance,
    m.display_name
  from members m
  left join paid on paid.uid = m.user_id
  left join owed on owed.uid = m.user_id
  left join settled_from on settled_from.uid = m.user_id
  left join settled_to on settled_to.uid = m.user_id
  order by m.display_name;
end;
$$;

revoke all on function public.get_trip_balances(uuid) from public;
grant execute on function public.get_trip_balances(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. get_trip_statistics
-- ---------------------------------------------------------------------------

create or replace function public.get_trip_statistics(p_trip_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result json;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip';
  end if;

  select json_build_object(
    'total_spent', coalesce((
      select sum(e.amount)::bigint
      from public.expenses e
      where e.trip_id = p_trip_id
    ), 0),
    'by_category', coalesce((
      select json_agg(
        json_build_object(
          'category', category,
          'amount', amount
        )
        order by amount desc
      )
      from (
        select e.category, sum(e.amount)::bigint as amount
        from public.expenses e
        where e.trip_id = p_trip_id
        group by e.category
      ) cat
    ), '[]'::json),
    'by_member', coalesce((
      select json_agg(
        json_build_object(
          'user_id', user_id,
          'display_name', display_name,
          'amount', amount
        )
        order by amount desc
      )
      from (
        select
          e.paid_by as user_id,
          p.display_name,
          sum(e.amount)::bigint as amount
        from public.expenses e
        join public.profiles p on p.id = e.paid_by
        where e.trip_id = p_trip_id
        group by e.paid_by, p.display_name
      ) mem
    ), '[]'::json),
    'by_date', coalesce((
      select json_agg(
        json_build_object(
          'date', expense_day,
          'amount', amount
        )
        order by expense_day
      )
      from (
        select
          (e.expense_date at time zone 'UTC')::date as expense_day,
          sum(e.amount)::bigint as amount
        from public.expenses e
        where e.trip_id = p_trip_id
        group by (e.expense_date at time zone 'UTC')::date
      ) day
    ), '[]'::json)
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_trip_statistics(uuid) from public;
grant execute on function public.get_trip_statistics(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. accept_trip_invitation
-- ---------------------------------------------------------------------------

create or replace function public.accept_trip_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_inv public.trip_invitations%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_token is null or length(trim(p_token)) = 0 then
    raise exception 'Invitation token is required';
  end if;

  select *
  into v_inv
  from public.trip_invitations ti
  where ti.token = trim(p_token)
  for update;

  if not found then
    raise exception 'Invitation not found';
  end if;

  if v_inv.accepted_at is not null then
    raise exception 'Invitation already accepted';
  end if;

  if v_inv.expires_at is not null and v_inv.expires_at < now() then
    raise exception 'Invitation has expired';
  end if;

  if exists (
    select 1
    from public.trip_members tm
    where tm.trip_id = v_inv.trip_id
      and tm.user_id = v_uid
  ) then
    -- Already a member: mark accepted if still open and return
    update public.trip_invitations
    set accepted_at = now()
    where id = v_inv.id
      and accepted_at is null;

    return v_inv.trip_id;
  end if;

  insert into public.trip_members (trip_id, user_id, role)
  values (v_inv.trip_id, v_uid, 'member');

  update public.trip_invitations
  set accepted_at = now()
  where id = v_inv.id;

  return v_inv.trip_id;
end;
$$;

revoke all on function public.accept_trip_invitation(text) from public;
grant execute on function public.accept_trip_invitation(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. get_journal_summary
-- ---------------------------------------------------------------------------

create or replace function public.get_journal_summary(p_trip_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result json;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not public.is_trip_member(p_trip_id) then
    raise exception 'Not a member of this trip';
  end if;

  select json_build_object(
    'memory_count', coalesce(count(*)::int, 0),
    'place_count', coalesce(
      count(distinct nullif(trim(je.location_name), ''))::int,
      0
    ),
    'day_count', coalesce(
      count(distinct (je.visited_at at time zone 'UTC')::date)::int,
      0
    )
  )
  into v_result
  from public.journal_entries je
  where je.trip_id = p_trip_id;

  return coalesce(v_result, json_build_object(
    'memory_count', 0,
    'place_count', 0,
    'day_count', 0
  ));
end;
$$;

revoke all on function public.get_journal_summary(uuid) from public;
grant execute on function public.get_journal_summary(uuid) to authenticated;
