package com.dentalcare.service;

import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration test contro il DB reale (schema demo {@code t_9d754153}), non un mock:
 * il rischio principale di questo task è un {@code MissingFormatArgumentException} a runtime
 * (numero di placeholder {@code %s} disallineato dal numero di argomenti passati a
 * {@code .formatted(...)} dentro {@code syncLegacyAnamnesis}) — un errore che una compilazione
 * pulita o un test con {@code NamedParameterJdbcTemplate} mockato non potrebbero rilevare, perché
 * emergerebbe solo eseguendo davvero la query.
 * <p>
 * Non usa {@code @SpringBootTest}: {@code AnamnesisService} ha un'unica dipendenza
 * ({@code NamedParameterJdbcTemplate}), quindi non serve avviare l'intero contesto applicativo —
 * che oggi, in questo repository, non parte comunque in test (vedi
 * {@code DentalcareApiApplicationTests}, disabilitato per un bean {@code ToolLayerService} non
 * configurato per l'ambiente di test) e nessun altro test in {@code service/} lo usa. Al suo posto,
 * questo test costruisce un {@link NamedParameterJdbcTemplate} reale via
 * {@link DriverManagerDataSource}, con le stesse credenziali (url/username non segreti, password
 * da {@code credentials/credential.properties} gitignored) già usate da
 * {@code application-test.properties}.
 */
class AnamnesisServiceTest {

    private static final String TEST_SCHEMA = "t_9d754153";
    private static final String DEFAULT_URL = "jdbc:postgresql://192.168.0.173:5432/dentalcarepro";
    private static final String DEFAULT_USERNAME = "postgres";

    private static NamedParameterJdbcTemplate jdbc;
    private static AnamnesisService service;

    private UUID patientId;
    private UUID itemId;

    @BeforeAll
    static void setUpDataSource() {
        Properties creds = loadCredentials();
        DriverManagerDataSource dataSource = new DriverManagerDataSource();
        dataSource.setDriverClassName("org.postgresql.Driver");
        dataSource.setUrl(creds.getProperty("spring.datasource.url", DEFAULT_URL));
        dataSource.setUsername(creds.getProperty("spring.datasource.username", DEFAULT_USERNAME));
        dataSource.setPassword(creds.getProperty("spring.datasource.password"));

        jdbc = new NamedParameterJdbcTemplate(dataSource);
        service = new AnamnesisService(jdbc);
    }

    /**
     * Stessa convenzione di {@code spring.config.import} in {@code application.properties}:
     * legge {@code credentials/credential.properties} (gitignored) da uno dei due path relativi
     * candidati, a seconda che i test girino da {@code backend/} o dalla root del repo. Mai un
     * segreto hardcoded nel sorgente.
     */
    private static Properties loadCredentials() {
        Properties props = new Properties();
        for (String path : List.of("../credentials/credential.properties", "./credentials/credential.properties")) {
            File file = new File(path);
            if (file.exists()) {
                try (InputStream in = new FileInputStream(file)) {
                    props.load(in);
                    return props;
                } catch (IOException e) {
                    throw new IllegalStateException("Impossibile leggere " + file.getAbsolutePath(), e);
                }
            }
        }
        throw new IllegalStateException(
                "credentials/credential.properties non trovato: necessario (spring.datasource.password) "
                        + "per i test DB-backed di AnamnesisServiceTest.");
    }

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        TenantContext.setCurrentClinicId(clinicId.toString());
        patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemId = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_LATEX'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        // stato pulito
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
    }

    @AfterEach
    void tearDown() {
        // Il DB demo è condiviso: non lasciare righe di test dietro, oltre alla pulizia
        // già fatta in setUp() prima di ogni run.
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
        TenantContext.clear();
    }

    @Test
    void resolvingAnItem_setsResolvedAt_doesNotDelete() {
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, null)), null, null));

        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(List.of(), null, null));

        Integer totalRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);
        Integer activeRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid AND resolved_at IS NULL"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);

        assertThat(totalRows).isEqualTo(1); // la riga esiste ancora (mai DELETE)
        assertThat(activeRows).isEqualTo(0); // ma non è più attiva
    }

    @Test
    void reselectingAResolvedItem_createsNewRow_notReactivation() {
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, "prima volta")), null, null));
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(List.of(), null, null));
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, "seconda volta")), null, null));

        Integer totalRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);

        assertThat(totalRows).isEqualTo(2); // due righe storiche distinte, non una riattivata
    }
}
