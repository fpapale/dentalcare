package com.dentalcare.service;

import com.dentalcare.dto.CatalogCategoryDto;
import com.dentalcare.dto.CatalogItemDto;
import com.dentalcare.dto.CreateCatalogCategoryRequest;
import com.dentalcare.dto.CreateCatalogItemRequest;
import com.dentalcare.exception.CatalogItemInUseException;
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
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Integration test contro il DB reale (schema demo {@code t_9d754153}), non un mock: verifica che
 * il catalogo anamnesi persista correttamente la severity a 3 livelli e che il delete fisico di
 * una voce/categoria venga bloccato quando è ancora referenziata da una selezione paziente attiva
 * ({@code resolved_at IS NULL}).
 * <p>
 * Non usa {@code @SpringBootTest}, stessa scelta di wiring di {@code AnamnesisServiceTest}: il
 * contesto applicativo completo non parte nei test di questo repository (vedi
 * {@code DentalcareApiApplicationTests}, disabilitato per un bean {@code ToolLayerService} non
 * configurato per l'ambiente di test) e nessun altro test in {@code service/} lo usa. Costruisce
 * invece un {@link NamedParameterJdbcTemplate} reale via {@link DriverManagerDataSource}, con le
 * stesse credenziali (url/username non segreti, password da
 * {@code credentials/credential.properties} gitignored) già usate da
 * {@code application-test.properties}.
 */
class AnamnesisCatalogServiceTest {

    private static final String TEST_SCHEMA = "t_9d754153"; // schema demo, presente in ogni ambiente di test
    private static final String DEFAULT_URL = "jdbc:postgresql://192.168.0.173:5432/dentalcarepro";
    private static final String DEFAULT_USERNAME = "postgres";

    private static NamedParameterJdbcTemplate jdbc;
    private static AnamnesisCatalogService service;

    @BeforeAll
    static void setUpDataSource() {
        Properties creds = loadCredentials();
        DriverManagerDataSource dataSource = new DriverManagerDataSource();
        dataSource.setDriverClassName("org.postgresql.Driver");
        dataSource.setUrl(creds.getProperty("spring.datasource.url", DEFAULT_URL));
        dataSource.setUsername(creds.getProperty("spring.datasource.username", DEFAULT_USERNAME));
        dataSource.setPassword(creds.getProperty("spring.datasource.password"));

        jdbc = new NamedParameterJdbcTemplate(dataSource);
        service = new AnamnesisCatalogService(jdbc);
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
                        + "per i test DB-backed di AnamnesisCatalogServiceTest.");
    }

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        cleanUpTestData(); // eventuali residui di un run precedente interrotto
    }

    @AfterEach
    void tearDown() {
        cleanUpTestData();
        TenantContext.clear();
    }

    /**
     * Il DB demo è condiviso con altri test/tenant reali: elimina solo le categorie di test
     * (prefisso {@code TEST_CAT_}, univoco per run grazie a {@link UUID#randomUUID()}) — il
     * FOREIGN KEY {@code ON DELETE CASCADE} su anamnesis_items e su
     * patient_anamnesis_item_selections si porta dietro anche voci e selezioni paziente create
     * durante il test, senza lasciare righe orfane.
     */
    private void cleanUpTestData() {
        jdbc.update("DELETE FROM %s.anamnesis_categories WHERE code LIKE 'TEST_CAT_%%'".formatted(TEST_SCHEMA),
                new MapSqlParameterSource());
    }

    /**
     * Categoria di test con codice univoco per run. {@code icon} non può essere null: la colonna
     * è NOT NULL nel DB reale e un bind esplicito a NULL scavalca il DEFAULT lato server (che si
     * applica solo se la colonna è omessa dall'INSERT, non quando è valorizzata a NULL) —
     * comportamento pre-esistente di {@code createCategory}, non introdotto da questo task.
     */
    private CatalogCategoryDto createTestCategory() {
        return service.createCategory(new CreateCatalogCategoryRequest(
                "TEST_CAT_" + UUID.randomUUID(), "Categoria di test", null, "test_icon", 999));
    }

    @Test
    void createItem_persistsSeverity() {
        CatalogCategoryDto cat = createTestCategory();

        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM", "Voce di test", null, "grave", 10));

        assertThat(item.severity()).isEqualTo("grave");
        assertThat(item.categoryId()).isEqualTo(cat.id());
    }

    @Test
    void deleteItem_blockedWhenUsedByActivePatientSelection() {
        CatalogCategoryDto cat = createTestCategory();
        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM_INUSE", "Voce in uso", null, "grave", 10));

        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        UUID patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        jdbc.update("""
            INSERT INTO %s.patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
            VALUES (:clinicId, :patientId, :itemId)
            """.formatted(TEST_SCHEMA),
            new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId)
                .addValue("itemId", item.id()));

        assertThatThrownBy(() -> service.deleteItem(item.id()))
                .isInstanceOf(CatalogItemInUseException.class)
                .hasMessageContaining("1 pazienti");

        // la voce non deve essere stata cancellata dal tentativo bloccato
        assertThat(service.findItemsByCategory(cat.id())).anyMatch(i -> i.id().equals(item.id()));
    }

    @Test
    void deleteItem_allowedWhenUnused() {
        CatalogCategoryDto cat = createTestCategory();
        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM_UNUSED", "Voce non usata", null, "normale", 10));

        service.deleteItem(item.id());

        assertThat(service.findItemsByCategory(cat.id())).noneMatch(i -> i.id().equals(item.id()));
    }

    @Test
    void deleteCategory_blockedWhenAnItemIsUsedByActivePatientSelection() {
        CatalogCategoryDto cat = createTestCategory();
        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM_CAT_INUSE", "Voce in uso", null, "severa", 10));

        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        UUID patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        jdbc.update("""
            INSERT INTO %s.patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
            VALUES (:clinicId, :patientId, :itemId)
            """.formatted(TEST_SCHEMA),
            new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId)
                .addValue("itemId", item.id()));

        assertThatThrownBy(() -> service.deleteCategory(cat.id()))
                .isInstanceOf(CatalogItemInUseException.class)
                .hasMessageContaining("1 pazienti");

        // la categoria non deve essere stata cancellata dal tentativo bloccato
        assertThat(service.findAllCategories()).anyMatch(c -> c.id().equals(cat.id()));
    }
}
