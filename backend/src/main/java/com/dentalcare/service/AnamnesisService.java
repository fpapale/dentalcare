package com.dentalcare.service;

import com.dentalcare.dto.AnamnesisCategoryDto;
import com.dentalcare.dto.AnamnesisItemDto;
import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

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

        // anamnesis_categories and anamnesis_items are global catalog — stay in dentalcare schema
        // patient_anamnesis_item_selections is tenant data — uses dynamic schema
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
                ai.is_alert,
                ai.sort_order AS item_sort_order,
                s.id AS selection_id,
                s.notes AS selection_notes
            FROM dentalcare.anamnesis_categories ac
            JOIN dentalcare.anamnesis_items ai
                ON ai.category_id = ac.id
               AND ai.enabled = true
            LEFT JOIN %s.patient_anamnesis_item_selections s
                ON s.item_id = ai.id
               AND s.patient_id = :patientId
               AND s.clinic_id = :clinicId
            WHERE ac.enabled = true
            ORDER BY ac.sort_order, ac.code, ai.sort_order, ai.code
            """.formatted(s());

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("patientId", patientId)
                .addValue("clinicId", clinicId);

        List<Map<String, Object>> rows = jdbc.queryForList(sql, params);

        return buildCategoryList(rows);
    }

    @Transactional
    public void savePatientAnamnesis(UUID patientId, SaveAnamnesisRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        jdbc.update("""
                DELETE FROM %s.patient_anamnesis_item_selections
                WHERE clinic_id = :clinicId AND patient_id = :patientId
                """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId));

        List<SaveAnamnesisRequest.ItemSelection> selections =
                request.selections() != null ? request.selections() : List.of();

        if (!selections.isEmpty()) {
            String insertSql = """
                INSERT INTO %s.patient_anamnesis_item_selections
                    (clinic_id, patient_id, item_id, notes)
                VALUES
                    (:clinicId, :patientId, :itemId, :notes)
                ON CONFLICT (clinic_id, patient_id, item_id) DO UPDATE
                    SET notes = EXCLUDED.notes,
                        updated_at = now()
                """.formatted(s());
            for (SaveAnamnesisRequest.ItemSelection sel : selections) {
                jdbc.update(insertSql, new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("itemId", sel.itemId())
                        .addValue("notes", sel.notes()));
            }
        }

        syncLegacyAnamnesis(patientId, clinicId, request);
        syncPatientSummary(patientId, clinicId);
    }

    /**
     * Propaga i dati generali e i flag derivati dalla versione corrente di patient_anamnesis
     * verso le colonne "cache" della tabella patients, lette dal dettaglio/panoramica paziente.
     * Non tocca other_allergies, che non è derivato dall'anamnesi strutturata.
     */
    private void syncPatientSummary(UUID patientId, UUID clinicId) {
        String sql = """
                UPDATE %s.patients
                   SET blood_type              = (SELECT pa.blood_type FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       anamnesis_notes         = (SELECT pa.general_notes FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       anamnesis_date          = now(),
                       smoker                  = (SELECT pa.smoker FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       hypertension            = (SELECT pa.hypertension FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       diabetes                = (SELECT pa.diabetes FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       heart_disease           = (SELECT pa.heart_disease FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       allergy_penicillin      = (SELECT pa.allergy_penicillin FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       allergy_latex           = (SELECT pa.allergy_latex FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       allergy_anesthetic      = (SELECT pa.allergy_anesthetic FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       taking_anticoagulants   = (SELECT pa.taking_anticoagulants FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true),
                       taking_bisphosphonates  = (SELECT pa.taking_bisphosphonates FROM %s.patient_anamnesis pa
                                                     WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true)
                 WHERE id = :patientId AND clinic_id = :clinicId
                   AND EXISTS (SELECT 1 FROM %s.patient_anamnesis pa
                                WHERE pa.clinic_id = :clinicId AND pa.patient_id = :patientId AND pa.is_current = true)
                """.formatted(s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s());

        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId));
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

        // Subqueries join tenant selections with global catalog items — tenant table uses s(), catalog stays dentalcare.
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
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_FUMO'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_ALCOL'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_DROGHE'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_IPERTENSIONE'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_DIABETE'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_CARDIOPATIA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_COAGULOP'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_IMMUNODEF'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_OSTEOPOROSI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_TIROIDEA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_EPILESSIA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_EPATOPATIA'),
                    false,
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'PAT_ONCOLOGICA'),
                    false,
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FARMACI_ANTICOAG'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FARMACI_BISFOSFONATI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'FARMACI_CORTISONICI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALLERG_PENICILLINA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALLERG_LATEX'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALLERG_ANESTETICI'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ALLERG_ASPIRINA'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_BRUXISMO'),
                    EXISTS (SELECT 1 FROM %s.patient_anamnesis_item_selections s JOIN dentalcare.anamnesis_items ai ON ai.id = s.item_id WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId AND ai.code = 'ABT_ONICOFAGIA'),
                    :generalNotes,
                    true,
                    now()
                """.formatted(s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s(),
                        s(), s(), s(), s(), s(), s(), s(), s(), s(), s(), s()),
                new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", patientId)
                        .addValue("bloodType", request.bloodType())
                        .addValue("generalNotes", request.generalNotes()));
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
                    Boolean.TRUE.equals(row.get("is_alert")),
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
