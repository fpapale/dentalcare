package com.dentalcare.service;

import com.dentalcare.dto.AnamnesisDiffDto;
import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Properties;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration test contro il DB reale (schema demo {@code t_9d754153}), stessa impostazione di
 * {@link AnamnesisServiceTest}: niente {@code @SpringBootTest} (rotto in questo repository — vedi
 * doc di {@code AnamnesisServiceTest}), {@link AnamnesisService} costruito a mano su un
 * {@link NamedParameterJdbcTemplate} reale via {@link DriverManagerDataSource}, credenziali lette
 * da {@code credentials/credential.properties} (gitignored).
 * <p>
 * Differenza importante rispetto ad {@code AnamnesisServiceTest}: qui il tempismo dei
 * {@code recorded_at}/{@code resolved_at} conta (l'algoritmo del diff si basa su "il punto nel
 * tempo distinto piu' recente = ora, il secondo piu' recente = la visita precedente"). In
 * produzione, {@code savePatientAnamnesis} e' {@code @Transactional}: tutte le sue scritture
 * condividono lo stesso {@code now()} Postgres (che restituisce l'inizio della transazione), quindi
 * una visita che tocca piu' righe (aggiunte + risoluzioni insieme) produce comunque UN SOLO punto
 * di cambiamento. Costruendo {@code AnamnesisService} come POJO grezzo (senza il proxy AOP di
 * Spring) quella garanzia sparisce: {@code NamedParameterJdbcTemplate} su
 * {@code DriverManagerDataSource} apre una connessione fisica nuova per ogni singola
 * {@code jdbc.update()}, quindi due scritture della stessa chiamata a
 * {@code savePatientAnamnesis} possono ricevere {@code now()} diversi (verificato empiricamente:
 * fino a centinaia di millisecondi di scarto tra un insert e una risoluzione nella stessa
 * chiamata), frammentando quella che dovrebbe essere UNA visita in due "punti di cambiamento" e
 * facendo scegliere all'algoritmo un {@code previousVisitAt} sbagliato (interno alla visita
 * corrente anziche' alla visita precedente).
 * <p>
 * Per riprodurre fedelmente il comportamento di produzione senza toccare il codice di produzione,
 * ogni chiamata a {@code savePatientAnamnesis} in questo test e' avvolta in una vera transazione
 * ({@link TransactionTemplate} su {@link DataSourceTransactionManager}, stesso {@code DataSource}
 * usato da {@code jdbc}): questo fa si' che {@code NamedParameterJdbcTemplate} riusi la stessa
 * connessione/transazione gia' legata al thread corrente (meccanismo di
 * {@code DataSourceUtils}, indipendente dal proxy {@code @Transactional} — funziona identico se la
 * transazione viene aperta manualmente), esattamente come accadrebbe passando per il vero
 * controller Spring.
 */
class AnamnesisDiffTest {

    private static final String TEST_SCHEMA = "t_9d754153";
    private static final String DEFAULT_URL = "jdbc:postgresql://192.168.0.173:5432/dentalcarepro";
    private static final String DEFAULT_USERNAME = "postgres";

    private static NamedParameterJdbcTemplate jdbc;
    private static AnamnesisService service;
    private static TransactionTemplate txTemplate;

    private UUID patientId;
    private UUID itemLatex;
    private UUID itemPenicillina;
    private UUID itemAnestetici;

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
        txTemplate = new TransactionTemplate(new DataSourceTransactionManager(dataSource));
    }

    /**
     * Stessa convenzione di {@code spring.config.import} in {@code application.properties}:
     * legge {@code credentials/credential.properties} (gitignored) da uno dei due path relativi
     * candidati, a seconda che i test girino da {@code backend/} o dalla root del repo.
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
                        + "per i test DB-backed di AnamnesisDiffTest.");
    }

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        TenantContext.setCurrentClinicId(clinicId.toString());
        patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemLatex = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_LATEX'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemPenicillina = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_PENICILLINA'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemAnestetici = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_ANESTETICI'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        // stato pulito: il DB demo e' condiviso con altri test/task
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
    }

    @AfterEach
    void tearDown() {
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
        TenantContext.clear();
    }

    /** Salva un'anamnesi in una vera transazione — vedi Javadoc di classe sul perche'. */
    private void save(SaveAnamnesisRequest request) {
        txTemplate.executeWithoutResult(status -> service.savePatientAnamnesis(patientId, request));
    }

    @Test
    void diff_withNoAnamnesisEverRecorded_returnsAllEmpty() {
        // setUp() ha gia' ripulito le selezioni: nessuna riga esiste per questo paziente.
        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).isEmpty();
        assertThat(diff.resolvedItems()).isEmpty();
        assertThat(diff.unchangedItems()).isEmpty();
    }

    @Test
    void diff_withOnlyOneVisitEver_reportsEverythingActiveAsNew() {
        // Un'unica visita, mai nessuna precedente da confrontare: tutto cio' che e' attivo
        // ora deve comparire come "nuovo" rispetto al nulla, non come "invariato".
        save(new SaveAnamnesisRequest(
                List.of(
                        new SaveAnamnesisRequest.ItemSelection(itemLatex, null),
                        new SaveAnamnesisRequest.ItemSelection(itemPenicillina, null)),
                null, null));

        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactlyInAnyOrder("ALL_LATEX", "ALL_PENICILLINA");
        assertThat(diff.resolvedItems()).isEmpty();
        assertThat(diff.unchangedItems()).isEmpty();
    }

    @Test
    void diff_detectsNewResolvedAndUnchangedItems_acrossTwoVisits() throws InterruptedException {
        // Visita 1: attive Latex e Anestetici.
        save(new SaveAnamnesisRequest(
                List.of(
                        new SaveAnamnesisRequest.ItemSelection(itemLatex, null),
                        new SaveAnamnesisRequest.ItemSelection(itemAnestetici, null)),
                null, null));
        Thread.sleep(50); // garantisce un now() Postgres successivo e distinto per la visita 2

        // Visita 2, stessa richiesta di salvataggio (quindi stessa transazione, stesso now()):
        // Anestetici resta selezionato (invariato), Latex non e' piu' selezionato (risolto),
        // Penicillina compare per la prima volta (nuovo).
        save(new SaveAnamnesisRequest(
                List.of(
                        new SaveAnamnesisRequest.ItemSelection(itemAnestetici, null),
                        new SaveAnamnesisRequest.ItemSelection(itemPenicillina, null)),
                null, null));

        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactly("ALL_PENICILLINA");
        assertThat(diff.resolvedItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactly("ALL_LATEX");
        assertThat(diff.unchangedItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactly("ALL_ANESTETICI");

        // Verifica anche label/severity, non solo il code, a conferma che il join con
        // anamnesis_items nella query di activeItemsAt() e' corretto.
        AnamnesisDiffDto.AnamnesisDiffItem newPenicillina = diff.newItems().get(0);
        assertThat(newPenicillina.label()).isEqualTo("Penicillina / Amoxicillina");
        assertThat(newPenicillina.severity()).isEqualTo("grave");
    }

    @Test
    void diff_noteOnlyEditOnAlreadyActiveItem_doesNotCreateAChangePoint_stillReportedAsNew() throws InterruptedException {
        // Un punto di cambiamento esiste solo se recorded_at o resolved_at cambiano: una
        // "visita 2" che riseleziona una voce gia' attiva modificando solo le note (ramo
        // UPDATE notes-only di savePatientAnamnesis) non tocca ne' l'una ne' l'altra colonna,
        // quindi non produce un secondo punto di cambiamento distinto. changePoints resta a 1
        // elemento (quello della visita 1): il caso ricade quindi nel ramo "nessuna visita
        // precedente", e la voce continua a comparire in newItems, non in unchangedItems.
        // Non e' un bug: e' la conseguenza diretta di definire i punti di cambiamento solo su
        // recorded_at/resolved_at (fedele alla cronologia clinica: "chi cambia le note" non e'
        // un evento di anamnesi diverso da "chi la conferma cosi' com'e'").
        save(new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemLatex, null)), null, null));
        Thread.sleep(50);

        save(new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemLatex, "controllo di routine")), null, null));

        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactly("ALL_LATEX");
        assertThat(diff.resolvedItems()).isEmpty();
        assertThat(diff.unchangedItems()).isEmpty();
    }
}
