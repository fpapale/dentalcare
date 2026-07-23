package com.dentalcare.service;

import com.dentalcare.dto.AnamnesisCategoryDto;
import com.dentalcare.dto.AnamnesisDiffDto;
import com.dentalcare.dto.AnamnesisItemDto;
import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class AnamnesisService {

    private final NamedParameterJdbcTemplate jdbc;

    public AnamnesisService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    @Transactional(readOnly = true)
    public List<AnamnesisCategoryDto> getPatientAnamnesis(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        // anamnesis_categories, anamnesis_items and patient_anamnesis_item_selections
        // are all tenant data — every table below uses the dynamic per-tenant schema.
        String sql = """
            SELECT
                ac.id AS category_id,
                ac.code AS category_code,
                ac.name AS category_name,
                ac.description AS category_description,
                ac.icon AS category_icon,
                ac.sort_order AS category_sort_order,
                ai.id AS item_id,
                ai.code AS item_code,
                ai.label AS item_label,
                ai.description AS item_description,
                ai.severity,
                ai.sort_order AS item_sort_order,
                s.id AS selection_id,
                s.notes AS selection_notes
            FROM %s.anamnesis_categories ac
            JOIN %s.anamnesis_items ai
                ON ai.category_id = ac.id
               AND ai.enabled = true
            LEFT JOIN %s.patient_anamnesis_item_selections s
                ON s.item_id = ai.id
               AND s.patient_id = :patientId
               AND s.clinic_id = :clinicId
               AND s.resolved_at IS NULL
            WHERE ac.enabled = true
            ORDER BY ac.sort_order, ac.code, ai.sort_order, ai.code
            """.formatted(s(), s(), s());

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("patientId", patientId)
                .addValue("clinicId", clinicId);

        List<Map<String, Object>> rows = jdbc.queryForList(sql, params);

        return buildCategoryList(rows);
    }

    @Transactional
    public void savePatientAnamnesis(UUID patientId, SaveAnamnesisRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        Set<UUID> currentlyActive = new HashSet<>(jdbc.queryForList("""
                SELECT item_id FROM %s.patient_anamnesis_item_selections
                WHERE clinic_id = :clinicId AND patient_id = :patientId AND resolved_at IS NULL
                """.formatted(s()),
                new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
                UUID.class));

        List<SaveAnamnesisRequest.ItemSelection> selections =
                request.selections() != null ? request.selections() : List.of();
        Map<UUID, String> newNotesByItem = new HashMap<>();
        for (SaveAnamnesisRequest.ItemSelection sel : selections) {
            newNotesByItem.put(sel.itemId(), sel.notes());
        }
        Set<UUID> newActive = newNotesByItem.keySet();

        // Voci nuove o ricomparse: INSERT (mai riattivazione della vecchia riga — fedeltà storica)
        for (UUID itemId : newActive) {
            if (!currentlyActive.contains(itemId)) {
                jdbc.update("""
                    INSERT INTO %s.patient_anamnesis_item_selections
                        (clinic_id, patient_id, item_id, notes)
                    VALUES (:clinicId, :patientId, :itemId, :notes)
                    """.formatted(s()),
                    new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("itemId", itemId)
                        .addValue("notes", newNotesByItem.get(itemId)));
            } else {
                // Voce già attiva: solo aggiornamento note, nessuna nuova versione
                jdbc.update("""
                    UPDATE %s.patient_anamnesis_item_selections
                    SET notes = :notes, updated_at = now()
                    WHERE clinic_id = :clinicId AND patient_id = :patientId
                      AND item_id = :itemId AND resolved_at IS NULL
                    """.formatted(s()),
                    new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("itemId", itemId)
                        .addValue("notes", newNotesByItem.get(itemId)));
            }
        }

        // Voci non più selezionate: risoluzione, mai DELETE
        for (UUID itemId : currentlyActive) {
            if (!newActive.contains(itemId)) {
                jdbc.update("""
                    UPDATE %s.patient_anamnesis_item_selections
                    SET resolved_at = now()
                    WHERE clinic_id = :clinicId AND patient_id = :patientId
                      AND item_id = :itemId AND resolved_at IS NULL
                    """.formatted(s()),
                    new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("itemId", itemId));
            }
        }

        syncLegacyAnamnesis(patientId, clinicId, request);
    }

    /**
     * Versiona patient_anamnesis: marca il record corrente come non corrente
     * e inserisce una nuova versione con i boolean derivati dalle selezioni strutturate.
     */
    private void syncLegacyAnamnesis(UUID patientId, UUID clinicId, SaveAnamnesisRequest request) {
        jdbc.update("""
                UPDATE %s.patient_anamnesis
                   SET is_current = false, updated_at = now()
                 WHERE clinic_id = :clinicId
                   AND patient_id = :patientId
                   AND is_current = true
                """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId));

        // Subqueries join tenant selections with tenant catalog items — entrambe le tabelle usano s() (schema per-tenant).
        // I codici sotto DEVONO corrispondere al seed ricostruito del catalogo (database/install.sql,
        // 15 categorie / 87 voci): un boolean derivato = true se e' attiva ALMENO una voce del gruppo clinico.
        // Alcuni boolean legacy mappano su piu' voci nuove (IN (...)): diabete tipo1/2/NS, cardiopatie,
        // coagulopatie, disfunzioni tiroidee. Boolean legacy senza voce corrispondente nel seed:
        // hiv_positive e autoimmune_disease restano false (nessun item dedicato distinto da IMM_HIV / patologie autoimmuni).
        jdbc.update("""
                INSERT INTO %s.patient_anamnesis (
                    clinic_id, patient_id,
                    blood_type,
                    smoker, alcohol_use, drug_use,
                    hypertension, diabetes, heart_disease,
                    coagulopathy, immunodeficiency, osteoporosis,
                    thyroid_disease, epilepsy, hepatitis,
                    hiv_positive, tumor_history, autoimmune_disease,
                    taking_anticoagulants, taking_bisphosphonates, taking_cortisone,
                    allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin,
                    bruxism, nail_biting,
                    general_notes, is_current, recorded_at
                )
                SELECT
                    :clinicId, :patientId,
                    :bloodType,
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_FUMATORE_ATTIVO'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_ALCOL'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_DROGHE'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'CAR_IPERTENSIONE'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code IN ('END_DIABETE1', 'END_DIABETE2', 'END_DIABETE_NS')),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code IN ('CAR_ENDOCARDITE', 'CAR_VALVOLARE', 'CAR_CONGENITA', 'CAR_PACEMAKER', 'CAR_FIBRILLAZIONE', 'CAR_INFARTO', 'CAR_ANGINA', 'CAR_SCOMPENSO', 'CAR_BYPASS')),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code IN ('IMM_COAGULOPATIA', 'IMM_EMOFILIA', 'IMM_TROMBOCITOPENIA')),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'IMM_HIV'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'END_OSTEOPOROSI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code IN ('END_IPOTIROIDISMO', 'END_IPERTIROIDISMO')),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'NEU_EPILESSIA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'EPA_EPATITE'),
                    false,
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'IMM_ONCOLOGICA'),
                    false,
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FAR_ANTICOAGULANTI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FAR_BISFOSFONATI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FAR_CORTISONICI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALL_PENICILLINA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALL_LATEX'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALL_ANESTETICI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALL_FANS'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_BRUXISMO'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN %s.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_ONICOFAGIA'),
                    :generalNotes,
                    true,
                    now()
                """.formatted(s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(),
                        s(), s(), s(), s()),
                new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("bloodType", request.bloodType())
                        .addValue("generalNotes", request.generalNotes()));
    }

    /**
     * Confronta le voci di anamnesi attive ora con quelle attive all'ultimo punto nel tempo,
     * precedente a ora, in cui qualcosa e' cambiato (una voce e' diventata attiva o e' stata
     * risolta). "Punto di cambiamento" = valore distinto tra tutti i recorded_at e resolved_at
     * non nulli della cronologia del paziente: il piu' recente rappresenta "ora", il secondo piu'
     * recente rappresenta l'ultima visita precedente da usare come confronto.
     * <p>
     * Se il paziente non ha mai avuto un'anamnesi registrata, o ne ha avuta una sola (nessun
     * punto di cambiamento precedente disponibile), non esiste un "prima" con cui confrontare:
     * tutte le voci attualmente attive vengono riportate come "nuove" rispetto al nulla, e le
     * altre due liste sono vuote.
     */
    @Transactional(readOnly = true)
    public AnamnesisDiffDto getDiffSinceLastVisit(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        List<OffsetDateTime> changePoints = jdbc.queryForList("""
            SELECT DISTINCT change_at FROM (
                SELECT recorded_at AS change_at FROM %s.patient_anamnesis_item_selections
                WHERE clinic_id = :clinicId AND patient_id = :patientId
                UNION
                SELECT resolved_at AS change_at FROM %s.patient_anamnesis_item_selections
                WHERE clinic_id = :clinicId AND patient_id = :patientId AND resolved_at IS NOT NULL
            ) t
            ORDER BY change_at DESC
            """.formatted(s(), s()),
            new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
            OffsetDateTime.class);

        if (changePoints.size() < 2) {
            List<AnamnesisDiffDto.AnamnesisDiffItem> allActive = activeItemsAt(patientId, clinicId, null);
            return new AnamnesisDiffDto(allActive, List.of(), List.of());
        }

        OffsetDateTime previousVisitAt = changePoints.get(1);
        List<AnamnesisDiffDto.AnamnesisDiffItem> activeNow = activeItemsAt(patientId, clinicId, null);
        List<AnamnesisDiffDto.AnamnesisDiffItem> activeBefore = activeItemsAt(patientId, clinicId, previousVisitAt);

        Set<String> codesNow = activeNow.stream().map(AnamnesisDiffDto.AnamnesisDiffItem::code).collect(Collectors.toSet());
        Set<String> codesBefore = activeBefore.stream().map(AnamnesisDiffDto.AnamnesisDiffItem::code).collect(Collectors.toSet());

        List<AnamnesisDiffDto.AnamnesisDiffItem> newItems = activeNow.stream()
                .filter(i -> !codesBefore.contains(i.code())).toList();
        List<AnamnesisDiffDto.AnamnesisDiffItem> resolvedItems = activeBefore.stream()
                .filter(i -> !codesNow.contains(i.code())).toList();
        List<AnamnesisDiffDto.AnamnesisDiffItem> unchangedItems = activeNow.stream()
                .filter(i -> codesBefore.contains(i.code())).toList();

        return new AnamnesisDiffDto(newItems, resolvedItems, unchangedItems);
    }

    /** Voci attive al momento asOf (o ora, se null): recorded_at <= asOf AND (resolved_at IS NULL OR resolved_at > asOf). */
    private List<AnamnesisDiffDto.AnamnesisDiffItem> activeItemsAt(UUID patientId, UUID clinicId, OffsetDateTime asOf) {
        String timeFilter = asOf != null
                ? "AND s.recorded_at <= :asOf AND (s.resolved_at IS NULL OR s.resolved_at > :asOf)"
                : "AND s.resolved_at IS NULL";
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId).addValue("patientId", patientId);
        if (asOf != null) params.addValue("asOf", asOf);
        return jdbc.query("""
            SELECT ai.code, ai.label, ai.severity
            FROM %s.patient_anamnesis_item_selections s
            JOIN %s.anamnesis_items ai ON ai.id = s.item_id
            WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId
            %s
            """.formatted(s(), s(), timeFilter),
            params,
            (rs, n) -> new AnamnesisDiffDto.AnamnesisDiffItem(
                    rs.getString("code"), rs.getString("label"), rs.getString("severity")));
    }

    private List<AnamnesisCategoryDto> buildCategoryList(List<Map<String, Object>> rows) {
        Map<UUID, AnamnesisCategoryDto> categoryMap = new LinkedHashMap<>();
        Map<UUID, List<AnamnesisItemDto>> itemsMap = new LinkedHashMap<>();

        for (Map<String, Object> row : rows) {
            UUID categoryId = (UUID) row.get("category_id");

            if (!categoryMap.containsKey(categoryId)) {
                categoryMap.put(categoryId, new AnamnesisCategoryDto(
                        categoryId,
                        (String) row.get("category_code"),
                        (String) row.get("category_name"),
                        (String) row.get("category_description"),
                        (String) row.get("category_icon"),
                        (Integer) row.get("category_sort_order"),
                        new ArrayList<>(),
                        false
                ));
                itemsMap.put(categoryId, new ArrayList<>());
            }

            boolean selected = row.get("selection_id") != null;
            itemsMap.get(categoryId).add(new AnamnesisItemDto(
                    (UUID) row.get("item_id"),
                    (String) row.get("item_code"),
                    (String) row.get("item_label"),
                    (String) row.get("item_description"),
                    (String) row.get("severity"),
                    (Integer) row.get("item_sort_order"),
                    selected,
                    (String) row.get("selection_notes")
            ));
        }

        List<AnamnesisCategoryDto> result = new ArrayList<>();
        for (Map.Entry<UUID, AnamnesisCategoryDto> entry : categoryMap.entrySet()) {
            UUID catId = entry.getKey();
            AnamnesisCategoryDto cat = entry.getValue();
            List<AnamnesisItemDto> items = itemsMap.get(catId);
            boolean hasSelections = items.stream().anyMatch(AnamnesisItemDto::selected);
            result.add(new AnamnesisCategoryDto(
                    cat.id(),
                    cat.code(),
                    cat.name(),
                    cat.description(),
                    cat.icon(),
                    cat.sortOrder(),
                    items,
                    hasSelections
            ));
        }
        return result;
    }
}
