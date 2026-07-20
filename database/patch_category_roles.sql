-- Patch: assegna i ruoli abilitati alle categorie di prestazione (#36).
--
-- Una categoria con allowed_roles valorizzato e' selezionabile solo dai ruoli
-- elencati; categoria NULL o vuota = nessun vincolo, visibile a tutti.
-- Il filtro e' applicato lato backend in ServiceCatalogService.findAll, sul
-- ruolo del JWT: secretary/admin/tenant_admin non filtrano mai.
--
-- Idempotente e conservativo: scrive SOLO dove allowed_roles e' ancora NULL,
-- quindi non sovrascrive le scelte fatte a mano da Impostazioni > Prestazioni.
-- Il match sul nome categoria e' case-insensitive.
--
-- Prerequisito: il backend deve essere gia' ripartito almeno una volta dopo il
-- deploy, cosi' patchSchema ha creato service_categories e la colonna
-- allowed_roles su ogni schema tenant.
--
-- Uso:
--   psql -U postgres -h <host-db> -d dentalcare_prod -f database/patch_category_roles.sql
--
-- Le categorie non presenti in mappa restano senza vincolo (visibili a tutti):
-- e' voluto, meglio permissivo che nascondere prestazioni per errore.

\echo '=== 1. Stato PRIMA della patch ==='

DO $$
DECLARE r record; tot integer; gia integer; ha_colonna boolean;
BEGIN
    FOR r IN
        SELECT n.nspname
        FROM pg_namespace n
        JOIN pg_class t ON t.relnamespace = n.oid AND t.relname = 'service_categories'
        WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
        ORDER BY n.nspname
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = r.nspname
              AND table_name   = 'service_categories'
              AND column_name  = 'allowed_roles'
        ) INTO ha_colonna;

        IF NOT ha_colonna THEN
            RAISE WARNING 'schema % : colonna allowed_roles ASSENTE — il backend non e'' ancora ripartito, patch non applicabile', r.nspname;
            CONTINUE;
        END IF;

        EXECUTE format('SELECT count(*), count(*) FILTER (WHERE allowed_roles IS NOT NULL) FROM %1$I.service_categories', r.nspname)
            INTO tot, gia;
        RAISE NOTICE 'schema % : % categorie, % gia'' configurate', r.nspname, tot, gia;
    END LOOP;
END$$;

\echo '=== 2. Applicazione mappa ruoli ==='

DO $$
DECLARE
    r        record;
    mappa    CONSTANT jsonb := jsonb_build_object(
        'igiene',          'hygienist,dentist',
        'parodontologia',  'hygienist,dentist',
        'estetica',        'hygienist,dentist',
        'ortodonzia',      'orthodontist,dentist',
        'chirurgia',       'surgeon,dentist',
        'implantologia',   'surgeon,dentist',
        'conservativa',    'dentist',
        'endodonzia',      'dentist',
        'protesi',         'dentist'
        -- 'diagnostica' volutamente assente: nessun vincolo, la vedono tutti
    );
    aggiornate integer;
BEGIN
    FOR r IN
        SELECT n.nspname
        FROM pg_namespace n
        JOIN pg_class t ON t.relnamespace = n.oid AND t.relname = 'service_categories'
        WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
        ORDER BY n.nspname
    LOOP
        EXECUTE format($sql$
            UPDATE %1$I.service_categories c
            SET allowed_roles = m.roles, updated_at = now()
            FROM (SELECT key AS nome, value #>> '{}' AS roles
                  FROM jsonb_each($1)) m
            WHERE lower(c.name) = m.nome
              AND c.allowed_roles IS NULL
        $sql$, r.nspname) USING mappa;

        GET DIAGNOSTICS aggiornate = ROW_COUNT;
        RAISE NOTICE 'schema % : % categorie aggiornate', r.nspname, aggiornate;
    END LOOP;
END$$;

\echo '=== 3. Stato DOPO: ruoli per categoria ==='

DO $$
DECLARE r record; riga record;
BEGIN
    FOR r IN
        SELECT n.nspname
        FROM pg_namespace n
        JOIN pg_class t ON t.relnamespace = n.oid AND t.relname = 'service_categories'
        WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
        ORDER BY n.nspname
    LOOP
        RAISE NOTICE '--- % ---', r.nspname;
        FOR riga IN EXECUTE format(
            'SELECT name, coalesce(allowed_roles, ''(tutti)'') AS ruoli
               FROM %1$I.service_categories ORDER BY name', r.nspname)
        LOOP
            RAISE NOTICE '  % -> %', rpad(riga.name, 18), riga.ruoli;
        END LOOP;
    END LOOP;
END$$;

\echo '=== 4. Prestazioni visibili per ruolo (controllo finale) ==='

DO $$
DECLARE r record; ruolo text; visibili integer; totale integer;
BEGIN
    FOR r IN
        SELECT n.nspname
        FROM pg_namespace n
        JOIN pg_class t ON t.relnamespace = n.oid AND t.relname = 'service_categories'
        WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
        ORDER BY n.nspname
    LOOP
        EXECUTE format('SELECT count(*) FROM %1$I.service_catalog WHERE active = true', r.nspname)
            INTO totale;
        RAISE NOTICE '--- %  (prestazioni attive: %) ---', r.nspname, totale;

        FOREACH ruolo IN ARRAY ARRAY['dentist','hygienist','orthodontist','surgeon','assistant']
        LOOP
            EXECUTE format($sql$
                SELECT count(*) FROM %1$I.service_catalog sc
                WHERE sc.active = true
                  AND NOT EXISTS (
                      SELECT 1 FROM %1$I.service_categories cat
                      WHERE cat.clinic_id = sc.clinic_id
                        AND lower(cat.name) = lower(sc.category)
                        AND btrim(coalesce(cat.allowed_roles, '')) <> ''
                        AND $1 <> ALL (string_to_array(lower(replace(cat.allowed_roles, ' ', '')), ','))
                  )
            $sql$, r.nspname) INTO visibili USING ruolo;

            RAISE NOTICE '  % -> % / %', rpad(ruolo, 13), visibili, totale;
        END LOOP;
        RAISE NOTICE '  % -> % / %  (non filtrano mai)', rpad('secretary/admin', 15), totale, totale;
    END LOOP;
END$$;
