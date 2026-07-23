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
    void diff_noteOnlyEdit_doesNotBumpRecordedAt_witnessItemStaysUnchanged() throws InterruptedException {
        // patient_anamnesis_item_selections e' una riga per (paziente, voce): una UPDATE
        // notes-only su Latex lascia comunque UNA SOLA riga con UN SOLO recorded_at per Latex,
        // sia che quel recorded_at resti quello originale sia che (per ipotesi di regressione)
        // venga sovrascritto con now(). Con un solo elemento in gioco changePoints.size() vale 1
        // in entrambi i casi: un test che usasse solo Latex non potrebbe distinguere le due
        // ipotesi (esattamente il difetto segnalato in review sulla versione precedente di
        // questo test). Per distinguerle serve — come nel test
        // diff_detectsNewResolvedAndUnchangedItems_acrossTwoVisits — un secondo punto di
        // cambiamento genuino altrove (qui: Penicillina aggiunta per la prima volta in visita 2)
        // che faccia scattare il vero confronto "prima/ora", piu' una voce testimone
        // (Anestetici) mai modificata nelle note, riselezionata identica in entrambe le visite.
        // Se la UPDATE notes-only di Latex avesse (per regressione futura) toccato anche
        // recorded_at, lo stesso bug colpirebbe l'UPDATE notes-only di Anestetici nella stessa
        // chiamata (stesso ramo di codice, stessa transazione, stesso now()): il recorded_at
        // originale di Anestetici sparirebbe (sovrascritto), changePoints crollerebbe a un solo
        // valore distinto, e Anestetici finirebbe erroneamente in newItems anziche' in
        // unchangedItems. E' questo che l'assert su unchangedItems sotto intercetta.
        save(new SaveAnamnesisRequest(
                List.of(
                        new SaveAnamnesisRequest.ItemSelection(itemLatex, null),
                        new SaveAnamnesisRequest.ItemSelection(itemAnestetici, null)),
                null, null));
        Thread.sleep(50);

        // Visita 2: Latex riselezionato con note diverse (il caso sotto test — ramo UPDATE
        // notes-only), Anestetici riselezionato identico (testimone, "lasciato in pace"),
        // Penicillina selezionato per la prima volta (crea il secondo punto di cambiamento
        // genuino senza il quale il confronto non scatterebbe affatto).
        save(new SaveAnamnesisRequest(
                List.of(
                        new SaveAnamnesisRequest.ItemSelection(itemLatex, "controllo di routine"),
                        new SaveAnamnesisRequest.ItemSelection(itemAnestetici, null),
                        new SaveAnamnesisRequest.ItemSelection(itemPenicillina, null)),
                null, null));

        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactly("ALL_PENICILLINA");
        assertThat(diff.resolvedItems()).isEmpty();
        // L'asserzione che conta davvero (vedi commento sopra): Anestetici, mai toccato di
        // proposito, deve restare "invariato" — non "nuovo" — a conferma che la modifica delle
        // sole note di Latex non ha corrotto il recorded_at di nessuna riga.
        assertThat(diff.unchangedItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code)
                .containsExactlyInAnyOrder("ALL_LATEX", "ALL_ANESTETICI");
    }
}
