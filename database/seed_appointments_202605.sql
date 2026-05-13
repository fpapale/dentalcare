-- Seed: 6 daily appointments per clinical provider, 2026-05-14 to 2026-05-30
-- Slots: 09-10, 10-11, 11-12, 12-13, 15-16, 16-17 (no lunch 13-15)
-- Both clinics: Roma (5 providers) + Milano (5 providers)
-- Total: 10 providers x 6 slots x 17 days = 1020 appointments

-- ─── ROMA ─────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_clinic UUID := '9d754153-6579-4b7e-a56b-025f00299cd9';

  v_providers UUID[] := ARRAY[
    '93ad1019-952b-4bf1-91ec-c8dca4d0fd25'::UUID,  -- Amato Serena (orthodontist)
    'f1b8d036-d293-4038-be50-3d3c3ba42d6c'::UUID,  -- Ferri Laura (dentist)
    '82785f33-2a86-4c4e-87f8-71442236a808'::UUID,  -- Gentili Michele (hygienist)
    'c87fe9ce-3f86-4ae9-86b7-fe9aaf24edda'::UUID,  -- Marchetti Paolo (surgeon)
    '643d78e4-ec83-4a10-bb79-98a4b5417fd1'::UUID   -- Morelli Federico (dentist)
  ];

  v_patients UUID[] := ARRAY[
    '17616aa7-6f2d-4ff9-bb1a-c39820048839'::UUID,
    '78aa7063-7328-4e9f-bc2d-827fd0eda13b'::UUID,
    '32038b3e-fdd7-4b6a-8198-776116e10ee7'::UUID,
    'ba714ca7-019d-4ef2-882f-2546cbbdbef4'::UUID,
    'e4b1c2ab-2ac2-405a-a0b7-c44458cc5a0e'::UUID,
    '9e253453-8af4-46bc-bb3b-33b805b66016'::UUID,
    '6dc46038-efaa-4850-87a4-edfd462f122d'::UUID,
    'f4317176-36b2-41d1-976b-5bbbeff1c9a0'::UUID,
    '6243814c-c5e1-46d7-822b-48cab7c9bf00'::UUID,
    '8d769eb0-81c9-4feb-a426-bf2a81eaed29'::UUID,
    '7d5914a2-f83c-4db5-8f6b-805dacad6c35'::UUID,
    '39be4e35-eb65-44f0-b92c-ba89eb6a3e0f'::UUID,
    '014f4f6f-b275-4542-a73e-2331c4f864bb'::UUID,
    '7e75c9d0-33d5-4b64-b9d6-55e4ed39f0a3'::UUID,
    'cfa6d75b-cfe9-447d-b1fe-cb31348f8c50'::UUID,
    'cd4698c3-5b32-4eb2-a442-85d19b40c6af'::UUID,
    '98cb1ea3-05a5-4f6a-b43d-8bdaa4b3b8d9'::UUID,
    '5a132a13-9c1c-4ff7-a7fb-941a1a356fb4'::UUID,
    '5e8df506-c340-4432-8b63-4d0e9dbe558e'::UUID,
    'eae1d06e-9d25-4225-8211-337a12bcf84c'::UUID,
    '6113e8f1-02fb-46c8-8ce0-eb4e06bc5e92'::UUID,
    '7410dc37-1d87-4b4e-b9c5-da2f1bf1ae48'::UUID,
    '376168b3-60d4-4204-a1b8-a6ea8aa7d86f'::UUID,
    '94972827-6481-489e-8a42-2f77af1b3bd8'::UUID,
    '71c93b4c-c94e-4e31-9b68-b1e7440646fa'::UUID,
    '7dc1a692-c444-45a8-8373-6fdf0db40a30'::UUID,
    '7ffdf0b2-73c6-47f5-986a-ed2cdfcec189'::UUID,
    '55056088-974e-4a53-a1b6-385a07353672'::UUID,
    '6fc789a2-18bc-4c2e-8d59-34fed4b829c8'::UUID,
    '1986d4a6-58f4-4af5-9fc3-4d612cbd3be6'::UUID,
    'bef401ed-c428-4f93-be20-555c6eedd46b'::UUID,
    'de1280ed-6199-46b1-ac36-cc7b5449e8db'::UUID,
    'a758a215-31fc-4cf8-b1f4-605ed0d0c326'::UUID,
    '5e764956-bf74-4973-a3f7-63e491a57c5c'::UUID,
    '413c2620-ab54-4ad8-bae6-abe279a2f3dc'::UUID,
    '0462ddad-8322-4b34-9f56-8d7195f3177a'::UUID,
    '463830cb-0990-4361-b711-b8ab2224989c'::UUID,
    '127164ee-1f55-481b-96a2-5dad9f0cf752'::UUID,
    '85905e4a-cb28-4174-89dd-b8de63221be4'::UUID,
    '2901bbfa-7326-469d-bee6-f9bc674666d1'::UUID,
    '80cdf6f2-a37c-4543-a4cf-deefedb0a905'::UUID,
    'e3ee2d02-d309-4c34-ba38-43c1b1dd609e'::UUID,
    'aba5de07-4356-407f-8169-a6497c0ffc99'::UUID,
    'c1d79c70-c8d1-4410-99d6-4d626370221d'::UUID,
    '8f3b202f-77f0-4ae0-ae7e-f6865cb3da64'::UUID,
    '23319222-5250-4788-ab35-f89c0484ff27'::UUID,
    '389e5cfc-f4ad-437a-8c02-81a1f06ad81e'::UUID,
    '07b68e6a-3f96-443e-8a3b-921ed7e79310'::UUID,
    'beb17896-13b4-4eb1-b369-dec6230354d7'::UUID,
    '345cc66c-c772-4d6b-aeec-776e53b1fa41'::UUID,
    '15ff6d19-7f93-4a4d-89f5-90f66cc2de6d'::UUID,
    'fcbff274-6855-46ae-b67c-17c7a1482db8'::UUID,
    'a4f9486c-2feb-4af5-a406-07b007281ddb'::UUID,
    '3aea0ca7-209d-4601-80ad-c47370b2d009'::UUID,
    'fb60072f-43b5-41e9-ab7b-44e7b607aa5a'::UUID,
    'd82fa1f4-c980-4946-8fa6-eb74430664f4'::UUID,
    '10238070-d966-40c3-89b4-452af6fad318'::UUID,
    'bc23b5bb-c714-4cdf-b801-7d17bd1072d5'::UUID,
    'f4b21000-0000-0000-0000-000000000001'::UUID,
    '1350de8c-bc0a-4390-a368-f402258fe626'::UUID
  ];

  v_slots  TIME[] := ARRAY['09:00'::TIME,'10:00'::TIME,'11:00'::TIME,'12:00'::TIME,'15:00'::TIME,'16:00'::TIME];
  v_chairs TEXT[] := ARRAY['Poltrona 1','Poltrona 2','Poltrona 3'];

  v_date     DATE;
  v_pi       INT;
  v_si       INT;
  v_counter  INT := 0;
  v_starts   TIMESTAMPTZ;
BEGIN
  FOR v_date IN SELECT d::DATE FROM generate_series('2026-05-14'::DATE,'2026-05-30'::DATE,'1 day'::INTERVAL) d LOOP
    FOR v_pi IN 1..5 LOOP
      FOR v_si IN 1..6 LOOP
        v_counter := v_counter + 1;
        v_starts  := (v_date::TIMESTAMP + v_slots[v_si]) AT TIME ZONE 'Europe/Rome';
        INSERT INTO dentalcare.appointments (id,clinic_id,patient_id,provider_id,chair_label,starts_at,ends_at,status)
        VALUES (
          gen_random_uuid(), v_clinic,
          v_patients[((v_counter - 1) % 60) + 1],
          v_providers[v_pi],
          v_chairs[((v_pi - 1) % 3) + 1],
          v_starts,
          v_starts + INTERVAL '1 hour',
          'scheduled'
        );
      END LOOP;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'Roma: inserted % appointments', v_counter;
END $$;

-- ─── MILANO ───────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_clinic UUID := '352464ea-0b3f-47ba-a3dc-3511c6d1af4f';

  v_providers UUID[] := ARRAY[
    'e3be18af-3ab2-4981-8d96-0e75f78d1367'::UUID,  -- Cattaneo Elisa (orthodontist)
    '71636b1b-9399-40b4-af0c-d78b81d20e2c'::UUID,  -- Grassi Massimo (hygienist)
    'c28932f7-3713-498c-a15a-d4a92771c16a'::UUID,  -- Mazza Daniele (surgeon)
    '589a6320-3c6a-44b9-806d-f88e38774b68'::UUID,  -- Pellegrini Enrico (dentist)
    'a74f2434-f952-4352-8ca9-798f34e55b3d'::UUID   -- Sala Valeria (dentist)
  ];

  v_patients UUID[] := ARRAY[
    '8b8451ca-41eb-40a5-8bbf-bcc775bc14e6'::UUID,
    '2128a7e2-bd77-4120-b62d-73a638b9afeb'::UUID,
    '5d6adfd7-90d9-4728-a15e-00a1ef269d5b'::UUID,
    '72bc72f1-3890-42a8-a452-81f7569617da'::UUID,
    '716636a7-d2c1-4b4a-9a6e-522590b8e493'::UUID,
    '3693cde6-1831-4ad0-9d3c-be6ae36738ab'::UUID,
    'de74d370-517f-4e3c-b99d-599b6ea6909e'::UUID,
    '52d860d0-d8e2-4391-b147-5abc0f40284e'::UUID,
    '4bee9bad-199b-4d17-911a-8b94691b92e8'::UUID,
    '89aee451-c3a0-4e01-8db1-c4b698360f60'::UUID,
    '930a53ab-b040-454f-bf71-3611fa5136e8'::UUID,
    '2b2d5ba1-a67b-40a1-93ad-f076608502d2'::UUID,
    'a509e956-1544-4a15-b27e-e77dfa7d909a'::UUID,
    '56e2104d-045c-45c4-b127-7409e37ad853'::UUID,
    '9effc53d-f11b-4d17-93ab-4d8527e1a651'::UUID,
    '0158f1d9-b076-48c4-8921-9fa265bb9d45'::UUID,
    '2ee6ec37-979f-4c68-9758-0588e73b3f44'::UUID,
    'fcfcb199-8498-4e25-b185-bed77dacbdba'::UUID,
    '3b7014df-41ed-4ceb-b6cc-ac004ae86347'::UUID,
    '4afed657-5658-4ab2-8634-21536680b7e3'::UUID,
    '4f6025e7-3147-4a57-991b-fa9760c0fe96'::UUID,
    '4a848914-196a-4845-ad0d-45feb5436e65'::UUID,
    '264d0b84-5d45-4a2e-8df3-b03cd4d180e9'::UUID,
    '703323d1-75cc-4516-aaec-12e033681cdb'::UUID,
    'aa41c954-3686-414e-88f3-5087acceadea'::UUID,
    '443f367c-0801-4cf5-b012-750d955fed91'::UUID,
    '68ae7403-ce0f-4621-b745-cb338dc4e042'::UUID,
    '9a8de8cd-71d6-4cb7-82bd-239efeae8f50'::UUID,
    '1ee1ca8a-df12-4d6b-a09a-68ac0d65d79d'::UUID,
    'c2447907-540e-44c5-aaef-cbddd1cb3e28'::UUID,
    'b2eca728-ac53-469b-8598-97b09b0b0c05'::UUID,
    'f09ea06c-ae2a-4ecd-8635-15723ec516f9'::UUID,
    'd6c13d55-b3f9-4c9b-9d57-a5fea5e46f6d'::UUID,
    '2ee46e81-0983-4f41-923f-8e17ed127a02'::UUID,
    '11485c3d-8fde-4f05-ae25-1aada412fe7e'::UUID,
    '750379db-74f8-42f8-b02c-ebf8d4341c65'::UUID,
    'd291c019-c39e-4ddc-9475-d59af5d5530a'::UUID,
    'a9c11925-988e-4892-9e07-95b6e131dcce'::UUID,
    '7a8b3acb-f173-497e-be3f-fda6fcd1d17e'::UUID,
    '789606d8-381e-4a37-85b7-d87cd118dbf9'::UUID,
    '5a979368-eb95-43c4-9c3b-34ecdd15c806'::UUID,
    '272cd318-7090-46ef-8720-f4cfcacc4d3c'::UUID,
    'cfa7b4be-19f6-4fe2-85d8-a020771c8d5d'::UUID,
    '0a5be753-bce6-4d54-a251-033ff1c82d6b'::UUID,
    'e2ab9511-66f1-45c2-96cd-fc8ca6adbb1e'::UUID
  ];

  v_slots  TIME[] := ARRAY['09:00'::TIME,'10:00'::TIME,'11:00'::TIME,'12:00'::TIME,'15:00'::TIME,'16:00'::TIME];
  v_chairs TEXT[] := ARRAY['Poltrona 1','Poltrona 2','Poltrona 3'];

  v_date     DATE;
  v_pi       INT;
  v_si       INT;
  v_counter  INT := 0;
  v_starts   TIMESTAMPTZ;
BEGIN
  FOR v_date IN SELECT d::DATE FROM generate_series('2026-05-14'::DATE,'2026-05-30'::DATE,'1 day'::INTERVAL) d LOOP
    FOR v_pi IN 1..5 LOOP
      FOR v_si IN 1..6 LOOP
        v_counter := v_counter + 1;
        v_starts  := (v_date::TIMESTAMP + v_slots[v_si]) AT TIME ZONE 'Europe/Rome';
        INSERT INTO dentalcare.appointments (id,clinic_id,patient_id,provider_id,chair_label,starts_at,ends_at,status)
        VALUES (
          gen_random_uuid(), v_clinic,
          v_patients[((v_counter - 1) % 45) + 1],
          v_providers[v_pi],
          v_chairs[((v_pi - 1) % 3) + 1],
          v_starts,
          v_starts + INTERVAL '1 hour',
          'scheduled'
        );
      END LOOP;
    END LOOP;
  END LOOP;
  RAISE NOTICE 'Milano: inserted % appointments', v_counter;
END $$;
