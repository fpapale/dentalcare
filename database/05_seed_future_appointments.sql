-- =============================================================================
-- DentalCare Pro - Appuntamenti prossimi 10 giorni lavorativi (tenant demo)
-- Schema: t_9d754153  |  Clinica: 9d754153-6579-4b7e-a56b-025f00299cd9
--
-- Idempotente: elimina e ricrea gli appuntamenti futuri demo (range +0..+20 gg).
-- Uso: pgAdmin Query Tool oppure
--      psql -U postgres -d dentalcarepro -f 05_seed_future_appointments.sql
-- =============================================================================

BEGIN;

SET search_path TO t_9d754153, dentalcare, public;

-- Rimuove appuntamenti futuri demo nel range sicuro
DELETE FROM t_9d754153.appointments
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
  AND starts_at >= CURRENT_DATE::timestamptz
  AND starts_at <  (CURRENT_DATE + 21)::timestamptz;

DO $$
DECLARE
    v_clinic uuid := '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;

    -- Providers
    v_pr1 uuid := 'b1000001-0000-0000-0000-000000000001'::uuid; -- Ferretti Laura   (dentist)
    v_pr2 uuid := 'b1000001-0000-0000-0000-000000000002'::uuid; -- Marchetti Paolo  (surgeon)
    v_pr3 uuid := 'b1000001-0000-0000-0000-000000000003'::uuid; -- Amato Serena     (orthodontist)
    v_pr4 uuid := 'b1000001-0000-0000-0000-000000000004'::uuid; -- Gentili Michele  (hygienist)

    -- Patients
    v_p01  uuid := 'c1000001-0000-0000-0000-000000000001'::uuid;
    v_p02  uuid := 'c1000001-0000-0000-0000-000000000002'::uuid;
    v_p03  uuid := 'c1000001-0000-0000-0000-000000000003'::uuid;
    v_p04  uuid := 'c1000001-0000-0000-0000-000000000004'::uuid;
    v_p05  uuid := 'c1000001-0000-0000-0000-000000000005'::uuid;
    v_p06  uuid := 'c1000001-0000-0000-0000-000000000006'::uuid;
    v_p07  uuid := 'c1000001-0000-0000-0000-000000000007'::uuid;
    v_p08  uuid := 'c1000001-0000-0000-0000-000000000008'::uuid;
    v_p09  uuid := 'c1000001-0000-0000-0000-000000000009'::uuid;
    v_p10  uuid := 'c1000001-0000-0000-0000-000000000010'::uuid;
    v_p11  uuid := 'c1000001-0000-0000-0000-000000000011'::uuid;
    v_p12  uuid := 'c1000001-0000-0000-0000-000000000012'::uuid;
    v_p13  uuid := 'c1000001-0000-0000-0000-000000000013'::uuid;
    v_p14  uuid := 'c1000001-0000-0000-0000-000000000014'::uuid;
    v_p15  uuid := 'c1000001-0000-0000-0000-000000000015'::uuid;
    v_p16  uuid := 'c1000001-0000-0000-0000-000000000016'::uuid;
    v_p17  uuid := 'c1000001-0000-0000-0000-000000000017'::uuid;
    v_p18  uuid := 'c1000001-0000-0000-0000-000000000018'::uuid;
    v_p19  uuid := 'c1000001-0000-0000-0000-000000000019'::uuid;
    v_p20  uuid := 'c1000001-0000-0000-0000-000000000020'::uuid;

    v_wd     int  := 0;
    v_offset int  := 0;
    v_d      date;
    v_status dentalcare.appointment_status;

BEGIN
    WHILE v_wd < 10 LOOP
        v_offset := v_offset + 1;
        v_d      := CURRENT_DATE + v_offset;
        CONTINUE WHEN EXTRACT(DOW FROM v_d) IN (0, 6);
        v_wd     := v_wd + 1;
        v_status := CASE WHEN v_wd <= 2
                         THEN 'confirmed'::dentalcare.appointment_status
                         ELSE 'scheduled'::dentalcare.appointment_status
                    END;

        CASE v_wd

        WHEN 1 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p06, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '10:30', v_status,
               'Devitalizzazione 26 pluriradicolare - prima seduta'),
              (gen_random_uuid(), v_clinic, v_p09, v_pr4, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:15', v_status,
               'Igiene professionale semestrale'),
              (gen_random_uuid(), v_clinic, v_p07, v_pr3, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '11:00', v_status,
               'Controllo mensile apparecchio fisso multibrackets'),
              (gen_random_uuid(), v_clinic, v_p13, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '16:00', v_status,
               'Estrazione 38 incluso - chirurgia programmata'),
              (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '15:30', v_d + TIME '16:30', v_status,
               'Otturazione 37 trifacciale OML composito'),
              (gen_random_uuid(), v_clinic, v_p19, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '16:00', v_d + TIME '16:45', v_status,
               'Igiene professionale - prima visita igienista');

        WHEN 2 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p04, v_pr4, NULL, 'Poltrona 1',
               v_d + TIME '08:30', v_d + TIME '09:15', v_status,
               'Igiene professionale programmata post-visita'),
              (gen_random_uuid(), v_clinic, v_p16, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '09:00', v_d + TIME '10:30', v_status,
               'Inserimento impianto 46 - procedura chirurgica'),
              (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '10:30', v_d + TIME '11:15', v_status,
               'Otturazione 35 monofacciale composito'),
              (gen_random_uuid(), v_clinic, v_p11, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '11:00', v_d + TIME '12:00', v_status,
               'Levigatura radicolare I quadrante (terapia parodontale)'),
              (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 2',
               v_d + TIME '15:00', v_d + TIME '16:00', v_status,
               'Prima valutazione ortodontica + foto intraorali + impronte'),
              (gen_random_uuid(), v_clinic, v_p17, v_pr2, NULL, 'Poltrona 1',
               v_d + TIME '16:00', v_d + TIME '17:00', v_status,
               'Chirurgia parodontale quadrante inf. destro - paziente fragile');

        WHEN 3 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p01, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '09:45', v_status,
               'Otturazione composito 14 - completamento piano cura'),
              (gen_random_uuid(), v_clinic, v_p05, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:15', v_status,
               'Otturazione 24 monofacciale composito'),
              (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '11:00', v_status,
               'Igiene profonda - completamento II quadrante'),
              (gen_random_uuid(), v_clinic, v_p08, v_pr2, NULL, 'Poltrona 1',
               v_d + TIME '11:00', v_d + TIME '11:30', v_status,
               'Controllo post-estrazione 18 - guarigione mucosa'),
              (gen_random_uuid(), v_clinic, v_p18, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '16:00', v_status,
               'Devitalizzazione 26 monoradicolare - dolore acuto'),
              (gen_random_uuid(), v_clinic, v_p02, v_pr3, NULL, 'Poltrona 3',
               v_d + TIME '15:30', v_d + TIME '16:30', v_status,
               'Consulenza estetica - sbiancamento e faccette 11-21');

        WHEN 4 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p10, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '10:00', v_status,
               'Otturazione bifacciale 35 OM composito'),
              (gen_random_uuid(), v_clinic, v_p03, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:00', v_status,
               'Controllo post-chirurgia impianto 36 - guarigione regolare'),
              (gen_random_uuid(), v_clinic, v_p11, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:30', v_d + TIME '11:30', v_status,
               'Levigatura radicolare II quadrante (terapia parodontale)'),
              (gen_random_uuid(), v_clinic, v_p06, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '14:00', v_d + TIME '15:30', v_status,
               'Devitalizzazione 26 - seconda seduta completamento'),
              (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 2',
               v_d + TIME '15:00', v_d + TIME '16:00', v_status,
               'Consegna apparecchio mobile rimovibile + istruzioni uso'),
              (gen_random_uuid(), v_clinic, v_p09, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '16:00', v_d + TIME '16:45', v_status,
               'Controllo igiene trimestrale');

        WHEN 5 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p07, v_pr3, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '10:00', v_status,
               'Controllo mensile ortodonzia - cambio archwire'),
              (gen_random_uuid(), v_clinic, v_p04, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:00', v_status,
               'Visita di controllo + RX bite wing'),
              (gen_random_uuid(), v_clinic, v_p14, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '10:45', v_status,
               'Igiene professionale semestrale'),
              (gen_random_uuid(), v_clinic, v_p19, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '11:00', v_d + TIME '12:00', v_status,
               'Otturazione 46 trifacciale - OMD composito'),
              (gen_random_uuid(), v_clinic, v_p13, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '15:00', v_status,
               'Controllo post-estrazione 38 - rimozione sutura'),
              (gen_random_uuid(), v_clinic, v_p16, v_pr2, NULL, 'Poltrona 3',
               v_d + TIME '15:30', v_d + TIME '16:30', v_status,
               'Controllo post-impianto 46 - integrazione ossea');

        WHEN 6 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p05, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '09:45', v_status,
               'Igiene professionale semestrale'),
              (gen_random_uuid(), v_clinic, v_p17, v_pr4, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:15', v_status,
               'Igiene professionale - paziente cardiopatico (gel clorossidina)'),
              (gen_random_uuid(), v_clinic, v_p10, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '10:30', v_d + TIME '11:15', v_status,
               'Otturazione 45 monofacciale composito'),
              (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '11:00', v_d + TIME '11:45', v_status,
               'Igiene profonda completamento III quadrante'),
              (gen_random_uuid(), v_clinic, v_p01, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '14:30', v_d + TIME '15:15', v_status,
               'Igiene di mantenimento - completamento piano cura Rossi'),
              (gen_random_uuid(), v_clinic, v_p18, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '15:30', v_d + TIME '17:00', v_status,
               'Corona 26 post-devitalizzazione - preparazione moncone');

        WHEN 7 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '09:30', v_status,
               'Controllo post-otturazione 37 - margini OK'),
              (gen_random_uuid(), v_clinic, v_p02, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '11:00', v_status,
               'Sbiancamento professionale LED - sessione completa'),
              (gen_random_uuid(), v_clinic, v_p11, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '11:00', v_status,
               'Igiene profonda parodontale III-IV quadrante'),
              (gen_random_uuid(), v_clinic, v_p08, v_pr2, NULL, 'Poltrona 1',
               v_d + TIME '14:00', v_d + TIME '14:30', v_status,
               'Rimozione punti sutura 18 - mucosa integra'),
              (gen_random_uuid(), v_clinic, v_p03, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '16:00', v_status,
               'Posizionamento moncone implantare 36'),
              (gen_random_uuid(), v_clinic, v_p07, v_pr3, NULL, 'Poltrona 3',
               v_d + TIME '16:00', v_d + TIME '17:00', v_status,
               'Controllo mensile ortodonzia - verifica spazi');

        WHEN 8 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p06, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '10:00', v_status,
               'Corona 26 post-devitalizzazione - cementazione definitiva'),
              (gen_random_uuid(), v_clinic, v_p04, v_pr4, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:15', v_status,
               'Igiene semestrale di routine'),
              (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '11:00', v_status,
               'Controllo mensile apparecchio mobile rimovibile'),
              (gen_random_uuid(), v_clinic, v_p09, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '11:00', v_d + TIME '11:45', v_status,
               'Visita controllo + pianificazione endodonzia 36'),
              (gen_random_uuid(), v_clinic, v_p19, v_pr4, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '15:15', v_status,
               'Igiene professionale semestrale - ottima igiene domiciliare'),
              (gen_random_uuid(), v_clinic, v_p05, v_pr1, NULL, 'Poltrona 3',
               v_d + TIME '15:30', v_d + TIME '16:15', v_status,
               'Visita controllo piano cura - aggiornamento');

        WHEN 9 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p01, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '09:30', v_status,
               'Controllo finale piano cura - tutte le voci completate'),
              (gen_random_uuid(), v_clinic, v_p17, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '10:30', v_status,
               'Revisione parodontale di mantenimento'),
              (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '10:45', v_status,
               'Igiene profonda completamento IV quadrante'),
              (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 1',
               v_d + TIME '11:00', v_d + TIME '11:45', v_status,
               'Otturazione 25 bifacciale - carie secondaria'),
              (gen_random_uuid(), v_clinic, v_p16, v_pr2, NULL, 'Poltrona 2',
               v_d + TIME '14:00', v_d + TIME '14:30', v_status,
               'Rimozione tappo di guarigione impianto 46'),
              (gen_random_uuid(), v_clinic, v_p10, v_pr1, NULL, 'Poltrona 3',
               v_d + TIME '15:00', v_d + TIME '15:45', v_status,
               'Visita riepilogativa piano Conti - nuova RX bite wing');

        WHEN 10 THEN
            INSERT INTO t_9d754153.appointments
                (id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
                 chair_label, starts_at, ends_at, status, notes)
            VALUES
              (gen_random_uuid(), v_clinic, v_p03, v_pr2, NULL, 'Poltrona 1',
               v_d + TIME '09:00', v_d + TIME '09:30', v_status,
               'Controllo impianto 36 - verifica osseointegrazione 2 settimane'),
              (gen_random_uuid(), v_clinic, v_p02, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '09:30', v_d + TIME '11:00', v_status,
               'Preparazione faccette ceramica 11-21 - diga di gomma'),
              (gen_random_uuid(), v_clinic, v_p11, v_pr4, NULL, 'Poltrona 3',
               v_d + TIME '10:00', v_d + TIME '11:00', v_status,
               'Seduta igiene di mantenimento parodontale'),
              (gen_random_uuid(), v_clinic, v_p07, v_pr3, NULL, 'Poltrona 1',
               v_d + TIME '11:00', v_d + TIME '12:00', v_status,
               'Controllo mensile ortodonzia - rivalutazione caso'),
              (gen_random_uuid(), v_clinic, v_p18, v_pr1, NULL, 'Poltrona 2',
               v_d + TIME '14:30', v_d + TIME '16:00', v_status,
               'Corona 26 provvisoria - prova e adattamento'),
              (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 3',
               v_d + TIME '16:00', v_d + TIME '16:30', v_status,
               'Visita programmazione impianto 46 - studio diagnostico');

        END CASE;
    END LOOP;
END $$;

COMMIT;
--rollback