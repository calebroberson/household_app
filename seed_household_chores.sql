-- Seeds 8 areas and 99 chores for Caleb + Matthew's household.
-- Run once, after Matthew has joined the household via invite code.
-- Not idempotent -- running it twice will duplicate everything (the
-- unique-name-per-household index on areas will stop duplicate AREAS,
-- but chores have no such constraint). Delete this file's rows first
-- if you need to re-run it.

do $$
declare
  v_household_id uuid;
  v_caleb_id uuid := '3bf30ca6-ba9b-4a96-b8a7-b8232af3cdc5';
  v_matthew_id uuid;
  v_kitchen_id uuid;
  v_half_bath_id uuid;
  v_living_room_id uuid;
  v_stairs_id uuid;
  v_entryway_id uuid;
  v_calebs_room_id uuid;
  v_calebs_bathroom_id uuid;
  v_home_id uuid;
  v_today text := to_char(current_date, 'YYYY-MM-DD');
begin
  select household_id into v_household_id from household_members where user_id = v_caleb_id limit 1;

  if v_household_id is null then
    raise exception 'Could not find a household for Caleb (%). Nothing seeded.', v_caleb_id;
  end if;

  select user_id into v_matthew_id
  from household_members
  where household_id = v_household_id and user_id <> v_caleb_id
  limit 1;

  if v_matthew_id is null then
    raise exception 'Matthew has not joined this household yet. Run this again after he joins.';
  end if;

  -- Areas
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Kitchen', 0, 'shared') returning id into v_kitchen_id;
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Half Bath', 1, 'shared') returning id into v_half_bath_id;
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Living Room', 2, 'shared') returning id into v_living_room_id;
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Stairs', 3, 'shared') returning id into v_stairs_id;
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Entryway', 4, 'shared') returning id into v_entryway_id;
  insert into areas (household_id, name, sort_order, visibility, owner_id) values
    (v_household_id, 'Caleb''s Room', 5, 'private', v_caleb_id) returning id into v_calebs_room_id;
  insert into areas (household_id, name, sort_order, visibility, owner_id) values
    (v_household_id, 'Caleb''s Bathroom', 6, 'private', v_caleb_id) returning id into v_calebs_bathroom_id;
  insert into areas (household_id, name, sort_order, visibility) values
    (v_household_id, 'Home', 7, 'shared') returning id into v_home_id;

  -- Kitchen (29 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_kitchen_id, 'Wipe counters and backsplash', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wipe stovetop', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wipe sink, faucet, and clear drain catch', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Sweep floor', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Run dishwasher / hand-wash what''s left', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Empty dishwasher', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Take out kitchen trash', '{"type":"weekly","days":[1,4]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Take out recycling', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wipe cabinet fronts and handles', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wipe appliance exteriors', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean microwave interior', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Empty toaster crumb tray', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Fridge check: toss expired food, wipe spills', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Mop kitchen floor', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wash dish towels and cloths', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Replace sponge', '{"type":"monthly","day_of_month":1}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean range hood filter and degrease hood', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean dishwasher filter and run cleaning cycle', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean garbage disposal', '{"type":"monthly","day_of_month":1}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Replace water filter pitcher cartridge', ('{"type":"every_n_months","n":2,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Wipe door handles and light switches', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Deep clean fridge', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean oven interior', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Pantry purge and wipe shelves', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Descale kettle', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Dust top of fridge, top of cabinets, light fixtures', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Check under sink for leaks, wipe cabinet interior', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Pull out fridge and stove, clean behind and beneath', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_kitchen_id, 'Clean out and inventory freezer', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id);

  -- Half Bath (9 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_half_bath_id, 'Wipe sink, faucet, and counter', '{"type":"weekly","days":[7]}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Swap hand towel', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Clean toilet bowl', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Wipe toilet exterior', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Wipe door handle and light switch', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Empty trash', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Check and restock toilet paper and hand soap', '{"type":"weekly","days":[7]}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Mop floor', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_half_bath_id, 'Wipe door', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id);

  -- Living Room (12 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_living_room_id, 'Nightly reset: cushions, blankets, remotes, cups, clutter', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Wipe dining table', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Coffee station: empty grounds, wipe drip tray and counter', '{"type":"daily"}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Dust mop floor', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Wet mop floor', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Dust TV stand, end tables, coffee table, coffee station', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Wash coffee carafe, basket, and reservoir', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Wipe dining chairs', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Wipe remotes, door handles, and light switches', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Dust HVAC vents and returns', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Move furniture, clean underneath and behind', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_living_room_id, 'Spot-clean upholstery', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id);

  -- Stairs (5 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_stairs_id, 'Dust mop treads', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_stairs_id, 'Wipe handrail and banister', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_stairs_id, 'Damp mop treads', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_stairs_id, 'Wipe risers', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_stairs_id, 'Check for loose treads', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id);

  -- Entryway (7 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_entryway_id, 'Tidy shoes, coats, bags, and mail', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Sweep or dust mop floor', '{"type":"weekly","days":[1,4]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Shake out or vacuum doormats', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Wet mop floor', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Wipe door and door handles', '{"type":"weekly","days":[7]}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Wipe light switches', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_entryway_id, 'Put out / put away winter boot tray and salt', '{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"2026-04-01"}', 'anyone', null, null, v_caleb_id);

  -- Caleb's Room (private, 15 chores, all fixed to Caleb)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_calebs_room_id, 'Make bed', '{"type":"daily"}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Clothes reset: hamper, hang, put away', '{"type":"weekly","days":[1,4]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Laundry: wash, dry, fold, put away', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Change sheets and pillowcases', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Vacuum carpet', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Dust dresser, nightstand, desk, headboard, shelves', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Empty bedroom trash', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Desk and nightstand declutter, cable tidy', '{"type":"monthly","day_of_month":1}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Wipe door handle and light switches', '{"type":"monthly","day_of_month":1}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Vacuum under bed and behind dresser', '{"type":"monthly","day_of_month":1}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Wash duvet cover, pillow protectors, and comforter', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Wash pillows', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Closet edit: purge, donate, reorganize', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Wipe door', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_room_id, 'Rotate or flip mattress', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id);

  -- Caleb's Bathroom (private, 18 chores, all fixed to Caleb)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_calebs_bathroom_id, 'Wipe sink, faucet, and counter', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Swap hand towel', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Clean toilet bowl', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Wipe toilet exterior', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Wipe door handle and light switches', '{"type":"monthly","day_of_month":1}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Empty trash', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Check and restock toilet paper and hand soap', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Mop floor', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Scrub bathtub/shower', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Wash bath mat', ('{"type":"every_n_weeks","n":2,"weekday":7,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Wash shower towels', '{"type":"monthly","day_of_month":1}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Clean mirror', '{"type":"weekly","days":[7]}', 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Deep clean grout and caulk', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Clean exhaust fan grille', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Check under sink for leaks, wipe cabinet interior', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Wipe door', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Caulk inspection and touch-up if needed', ('{"type":"every_n_months","n":6,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id),
    (v_household_id, v_calebs_bathroom_id, 'Descale showerhead', ('{"type":"every_n_months","n":12,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'fixed', null, v_caleb_id, v_caleb_id);

  -- Home (4 chores)
  insert into chores (household_id, area_id, title, recurrence_rule, assignment_strategy, assignee_order, fixed_assignee, created_by) values
    (v_household_id, v_home_id, 'Empty vacuum canister', '{"type":"weekly","days":[7]}', 'anyone', null, null, v_caleb_id),
    (v_household_id, v_home_id, 'Wash vacuum filter', '{"type":"monthly","day_of_month":1}', 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_home_id, 'Replace HVAC filter', ('{"type":"every_n_months","n":3,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'rotate', array[v_matthew_id, v_caleb_id], null, v_caleb_id),
    (v_household_id, v_home_id, 'Replace detector batteries', ('{"type":"every_n_months","n":12,"day_of_month":1,"anchor":"' || v_today || '"}')::jsonb, 'anyone', null, null, v_caleb_id);

  raise notice 'Seeded 8 areas and 99 chores for household %', v_household_id;
end $$;
