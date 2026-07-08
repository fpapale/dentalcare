# GDPR Slice 2a — cifratura `fiscal_code` paziente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cifrare a riposo `patients.fiscal_code` (+ snapshot `invoices.patient_fiscal_code`) con AES-256-GCM per-tenant, mantenendo la ricerca esatta via blind index.

**Architecture:** Estende la macchina crypto di Slice 1 (`TenantEncryptionService`, `EstimateSchemaInitializer.patchSchema`, `EncryptionMigrationService`, rollout dual-write→migrate→cutover). Aggiunge la primitiva `blindIndex` (HMAC deterministico su chiave HKDF separata). `birth_date_enc` (già in codebase) è il precedente lavorato per ogni trasformazione read/vista.

**Tech Stack:** Spring Boot, NamedParameterJdbcTemplate, PostgreSQL schema-per-tenant, javax.crypto (Mac/Cipher), JUnit5+Mockito.

## Global Constraints

- **Nessun nuovo segreto**: enc e idx derivano dalla stessa master key con HKDF `info` distinti (`"dental-enc-v1"` vs `"dental-blind-idx-v1"`).
- **Ambito: solo CF paziente.** Escludere `clinics.fiscal_code`, `providers.fiscal_code`, `invoices.issuer_fiscal_code`.
- **`null` → `null`** in encrypt/decrypt/blindIndex (campi opzionali).
- **Idempotenza**: patch schema (`ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`) + migrazione (`WHERE _enc IS NULL AND plaintext IS NOT NULL`).
- **Stadi non-breaking**: dual-write non tocca read/viste; cutover in task successivo. Merge finale = stato cutover.
- **Plaintext mantenuto** (azzerato dai write al cutover, NON droppato). `DROP COLUMN` fuori scope.
- **install.sql mirror**: ogni colonna/vista nuova va riflessa in `database/install.sql` (heredoc `create_tenant` + tenant demo `t_9d754153`).
- **Normalizzazione blind index (CF)**: `value.trim().toUpperCase(Locale.ROOT)`.
- Schema tenant sempre via `TenantContext.validatedSchema()` (regex `^t_[0-9a-f]{8}$`), mai da input client.

---

### Task 1: Primitiva `blindIndex` in TenantEncryptionService

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/security/crypto/TenantEncryptionService.java`
- Test: `backend/src/test/java/com/dentalcare/security/crypto/TenantEncryptionServiceTest.java`

**Interfaces:**
- Produces: `String blindIndex(String value, String schema)` — HMAC-SHA256 esadecimale deterministico; `null`→`null`; case-insensitive via `trim().toUpperCase`.

- [ ] **Step 1: Test falliti** — aggiungere a `TenantEncryptionServiceTest`:

```java
@Test
void blindIndexIsDeterministicAndCaseInsensitive() {
    String a = service.blindIndex("RSSMRA80A01H501U", "t_00000001");
    String b = service.blindIndex(" rssmra80a01h501u ", "t_00000001");
    assertThat(a).isNotBlank().isEqualTo(b);        // trim + uppercase
}

@Test
void blindIndexIsSchemaBound() {
    assertThat(service.blindIndex("RSSMRA80A01H501U", "t_00000001"))
        .isNotEqualTo(service.blindIndex("RSSMRA80A01H501U", "t_00000002"));
}

@Test
void blindIndexDiffersFromEncKeyOutput() {
    // idx usa una chiave HKDF diversa: non deve coincidere con nessun ciphertext
    String idx = service.blindIndex("RSSMRA80A01H501U", "t_00000001");
    assertThat(idx).matches("^[0-9a-f]{64}$");       // 32 byte hex
}

@Test
void blindIndexNullReturnsNull() {
    assertThat(service.blindIndex(null, "t_00000001")).isNull();
}
```

- [ ] **Step 2: Run test → FAIL** (`blindIndex` non definito)

Run: `./mvnw -q -Dtest=TenantEncryptionServiceTest test`
Expected: FAIL compilazione / metodo assente

- [ ] **Step 3: Implementare** — in `TenantEncryptionService`:

```java
// campo classe (accanto a INFO_ENC)
private static final String INFO_IDX = "dental-blind-idx-v1";
private final Map<String, SecretKeySpec> idxKeyCache = new ConcurrentHashMap<>();

/** Blind index deterministico (ricerca esatta): HMAC-SHA256 su chiave HKDF separata. */
public String blindIndex(String value, String schema) {
    if (value == null) return null;
    String normalized = value.trim().toUpperCase(java.util.Locale.ROOT);
    try {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(idxKey(schema));
        byte[] h = mac.doFinal(normalized.getBytes(StandardCharsets.UTF_8));
        return java.util.HexFormat.of().formatHex(h);
    } catch (Exception e) {
        throw new EncryptionException("blind index failed for schema " + schema, e);
    }
}

private SecretKeySpec idxKey(String schema) {
    return idxKeyCache.computeIfAbsent(schema,
            s -> new SecretKeySpec(hkdfSha256(masterKey, s.getBytes(StandardCharsets.UTF_8),
                    INFO_IDX.getBytes(StandardCharsets.UTF_8), 32), "HmacSHA256"));
}
```

- [ ] **Step 4: Run test → PASS**

Run: `./mvnw -q -Dtest=TenantEncryptionServiceTest test`
Expected: PASS (tutti, inclusi i preesistenti)

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/security/crypto/TenantEncryptionService.java backend/src/test/java/com/dentalcare/security/crypto/TenantEncryptionServiceTest.java
git commit -m "feat(security): blindIndex per ricerca esatta cifrata (#7 slice2a)"
```

---

### Task 2: Colonne schema (`_enc`/`_idx`) via patchSchema + install.sql

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` (dopo il runStep `patients foreign_patient`, ~riga 163)
- Modify: `database/install.sql` (heredoc `create_tenant` + tenant demo `t_9d754153`)

**Interfaces:**
- Produces colonne: `patients.fiscal_code_enc text`, `patients.fiscal_code_idx text` (+ index), `invoices.patient_fiscal_code_enc text`.

- [ ] **Step 1: Aggiungere i runStep** — in `patchSchema`, subito dopo il blocco `patients foreign_patient`:

```java
runStep(schema, "patients fiscal_code_enc/idx", () -> {
    jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS fiscal_code_enc text");
    jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS fiscal_code_idx text");
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_patients_fiscal_code_idx ON " + schema + ".patients (fiscal_code_idx)");
});
runStep(schema, "invoices patient_fiscal_code_enc", () ->
        jdbc.execute("ALTER TABLE " + schema + ".invoices ADD COLUMN IF NOT EXISTS patient_fiscal_code_enc text"));
```

- [ ] **Step 2: Mirror install.sql** — nel heredoc di `dentalcare.create_tenant` aggiungere le colonne alla definizione di `patients` (`fiscal_code_enc text`, `fiscal_code_idx text`) e `invoices` (`patient_fiscal_code_enc text`), l'index su `fiscal_code_idx`, e replicare le stesse `ALTER`/index nel blocco del tenant demo `t_9d754153` (cercare `birth_date_enc` come riferimento di posizione: le nuove colonne vanno accanto).

- [ ] **Step 3: Build (gate, non-breaking)** — nessun test nuovo: le colonne sono additive e ancora non lette.

Run: `./mvnw -q -DskipTests package` poi `./mvnw -q test`
Expected: BUILD SUCCESS, suite verde invariata.

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java database/install.sql
git commit -m "feat(security): colonne fiscal_code_enc/idx + invoices snapshot enc (#7 slice2a)"
```

---

### Task 3: Dual-write (PatientService + InvoiceService)

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java` (create ~72, update ~107)
- Modify: `backend/src/main/java/com/dentalcare/service/InvoiceService.java` (createFromEstimate snapshot ~159 + INSERT invoices)

**Interfaces:**
- Consumes: `enc.encrypt`, `enc.blindIndex` (Task 1).
- Produces: create/update scrivono `fiscal_code_enc`+`fiscal_code_idx`; emissione scrive `patient_fiscal_code_enc`. Plaintext ANCORA scritto (dual-write). Nessun read cambiato.

- [ ] **Step 1: PatientService.create** — nel SQL INSERT aggiungere le colonne `fiscal_code_enc, fiscal_code_idx` e i param:

```java
// nel VALUES: ..., :fiscalCode, :fiscalCodeEnc, :fiscalCodeIdx, ...
.addValue("fiscalCode", request.fiscalCode())          // plaintext, ancora
.addValue("fiscalCodeEnc", enc.encrypt(request.fiscalCode(), s()))
.addValue("fiscalCodeIdx", enc.blindIndex(request.fiscalCode(), s()))
```

Aggiungere `fiscal_code_enc, fiscal_code_idx` alla lista colonne INSERT e `:fiscalCodeEnc, :fiscalCodeIdx` al VALUES.

- [ ] **Step 2: PatientService.update** — nel SET aggiungere:

```java
fiscal_code     = :fiscalCode,
fiscal_code_enc = :fiscalCodeEnc,
fiscal_code_idx = :fiscalCodeIdx,
```
con i param `.addValue("fiscalCodeEnc", enc.encrypt(request.fiscalCode(), s()))` e `.addValue("fiscalCodeIdx", enc.blindIndex(request.fiscalCode(), s()))`.

- [ ] **Step 3: InvoiceService emissione** — in `createFromEstimate`, il SELECT estimate (riga ~159) aggiunge `pat.fiscal_code_enc AS patient_fiscal_code_enc`; l'INSERT in `invoices` aggiunge la colonna `patient_fiscal_code_enc` valorizzata dalla `est.get("patient_fiscal_code_enc")` (copia diretta del ciphertext, stessa chiave). Continuare a scrivere anche `patient_fiscal_code` plaintext (dual-write).

- [ ] **Step 4: Build + suite** — verifica non-breaking.

Run: `./mvnw -q test`
Expected: BUILD SUCCESS, suite verde.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/PatientService.java backend/src/main/java/com/dentalcare/service/InvoiceService.java
git commit -m "feat(security): dual-write fiscal_code_enc/idx + invoices snapshot (#7 slice2a)"
```

---

### Task 4: Migrazione (patients + invoices) idempotente

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/EncryptionMigrationService.java`
- Modify: `backend/src/main/java/com/dentalcare/controller/EncryptionMigrationController.java` (response: aggiungere conteggio fiscal)
- Test: `backend/src/test/java/com/dentalcare/service/EncryptionMigrationServiceTest.java`

**Interfaces:**
- Consumes: `enc.encrypt`, `enc.blindIndex`.
- Produces: `int migrateFiscalCode()` — cifra `patients.fiscal_code` (enc+idx) e snapshot `invoices.patient_fiscal_code_enc`; idempotente; ritorna righe pazienti migrate.

- [ ] **Step 1: Test falliti** — in `EncryptionMigrationServiceTest`, sul pattern del test `migrateBirthDate` esistente:

```java
@Test
void migrateFiscalCodeEncryptsAndIndexes() {
    // 2 pazienti con fiscal_code plaintext e _enc NULL
    when(jdbc.query(contains("FROM t_test.patients"), any(RowMapper.class)))
        .thenReturn(List.of(new Object[]{UUID.randomUUID(), "RSSMRA80A01H501U"},
                            new Object[]{UUID.randomUUID(), "VRDLGI85M02H501Z"}));
    // (adattare al RowMapper reale del service; asserire update chiamato 2x con enc+idx non null)
    int n = service.migrateFiscalCode();
    assertThat(n).isEqualTo(2);
}
```
(Modellare esattamente sul test esistente di `migrateBirthDate`: stesso stile di stub `jdbc.query`/`jdbc.update`, asserire che l'UPDATE riceve `fiscal_code_enc` e `fiscal_code_idx` non nulli.)

- [ ] **Step 2: Run → FAIL**

Run: `./mvnw -q -Dtest=EncryptionMigrationServiceTest test`
Expected: FAIL (metodo assente)

- [ ] **Step 3: Implementare** — in `EncryptionMigrationService`:

```java
@Transactional
public int migrateFiscalCode() {
    String schema = s();
    // pazienti
    List<Object[]> pats = jdbc.query(
            "SELECT id, fiscal_code FROM " + schema + ".patients"
                    + " WHERE fiscal_code_enc IS NULL AND fiscal_code IS NOT NULL",
            (rs, n) -> new Object[]{rs.getObject("id", UUID.class), rs.getString("fiscal_code")});
    for (Object[] p : pats) {
        String cf = (String) p[1];
        jdbc.update("UPDATE " + schema + ".patients SET fiscal_code_enc = :enc, fiscal_code_idx = :idx WHERE id = :id",
                new MapSqlParameterSource()
                        .addValue("enc", enc.encrypt(cf, schema))
                        .addValue("idx", enc.blindIndex(cf, schema))
                        .addValue("id", p[0]));
    }
    // snapshot invoices (cifra il valore storico di ciascuna fattura)
    List<Object[]> invs = jdbc.query(
            "SELECT id, patient_fiscal_code FROM " + schema + ".invoices"
                    + " WHERE patient_fiscal_code_enc IS NULL AND patient_fiscal_code IS NOT NULL",
            (rs, n) -> new Object[]{rs.getObject("id", UUID.class), rs.getString("patient_fiscal_code")});
    for (Object[] iv : invs) {
        jdbc.update("UPDATE " + schema + ".invoices SET patient_fiscal_code_enc = :enc WHERE id = :id",
                new MapSqlParameterSource()
                        .addValue("enc", enc.encrypt((String) iv[1], schema))
                        .addValue("id", iv[0]));
    }
    return pats.size();
}
```

- [ ] **Step 4: Controller** — estendere la response:

```java
@PostMapping("/migrate")
public Map<String, Integer> migrate() {
    return Map.of(
        "birthDate", migrationService.migrateBirthDate(),
        "fiscalCode", migrationService.migrateFiscalCode());
}
```
(Nota: `migrate` diventa idempotente cumulativo — rieseguibile in sicurezza. Aggiornare il runbook prod di conseguenza in un secondo momento.)

- [ ] **Step 5: Run → PASS**

Run: `./mvnw -q -Dtest=EncryptionMigrationServiceTest test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/EncryptionMigrationService.java backend/src/main/java/com/dentalcare/controller/EncryptionMigrationController.java backend/src/test/java/com/dentalcare/service/EncryptionMigrationServiceTest.java
git commit -m "feat(security): migrazione fiscal_code (enc+idx) + snapshot invoices (#7 slice2a)"
```

---

### Task 5: Cutover pazienti (read + ricerca idx + viste + export)

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java` (findAll search ~57-61, mapListRow ~246, mapDetailRow ~269, create/update plaintext→null)
- Modify: `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` (rebuildPatientDashboardView ~439, rebuildPatientClinicalCardView ~461, rebuildEstimatesSummaryView ~484)
- Modify: `backend/src/main/java/com/dentalcare/service/TenantExportService.java` (writeCustomersCsv ~250)
- Modify: `database/install.sql` (le 3 viste, global + demo)
- Test: `backend/src/test/java/com/dentalcare/service/PatientServiceTest.java` (nuovo, se assente)

**Interfaces:**
- Consumes: `enc.decrypt`, `enc.blindIndex`; colonne `_enc`/`_idx` (Task 2).
- Precedente lavorato: `birth_date_enc` fa ESATTAMENTE questa trasformazione negli stessi punti (viste, mapListRow/mapDetailRow) — seguirlo.

- [ ] **Step 1: Viste** — nei 3 metodi rebuild sostituire `p.fiscal_code`:
  - `rebuildPatientDashboardView`: `p.fiscal_code` → `p.fiscal_code_enc, p.fiscal_code_idx`; aggiornare la `GROUP BY` (rimuovere `p.fiscal_code`, aggiungere `p.fiscal_code_enc, p.fiscal_code_idx`).
  - `rebuildPatientClinicalCardView`: `p.fiscal_code` → `p.fiscal_code_enc`.
  - `rebuildEstimatesSummaryView`: `p.fiscal_code AS patient_fiscal_code` → `p.fiscal_code_enc AS patient_fiscal_code_enc`.
  Mirror in `install.sql` (global + demo).

- [ ] **Step 2: PatientService ricerca** — in `findAll` sostituire il termine CF ILIKE con match esatto blind index:

```java
// prima: OR v.fiscal_code ILIKE '%%' || CAST(:search AS text) || '%%'
// dopo:  OR v.fiscal_code_idx = :searchIdx
```
e nei params: `.addValue("searchIdx", (search == null || search.isBlank()) ? null : enc.blindIndex(search.trim(), s()))`.
Nota: `:searchIdx` è `null` quando `search` è null → il termine `v.fiscal_code_idx = NULL` non matcha nulla (corretto: quando non si cerca, il filtro CF è inattivo perché protetto da `CAST(:search AS text) IS NULL OR ...`).

- [ ] **Step 3: PatientService read** — in `mapListRow` e `mapDetailRow` sostituire `rs.getString("fiscal_code")` con `enc.decrypt(rs.getString("fiscal_code_enc"), s())` (identico a come `decodeBirthDate` gestisce `birth_date_enc`). Aggiornare i SELECT sorgente (`v.fiscal_code`→`v.fiscal_code_enc` nella lista di findAll ~47; nel SELECT dettaglio `p.fiscal_code`→`p.fiscal_code_enc`).

- [ ] **Step 4: PatientService write plaintext→null** — in create e update: `.addValue("fiscalCode", null)` (come `birthDate`), continuando a scrivere `_enc`/`_idx`.

- [ ] **Step 5: Export** — in `writeCustomersCsv` (e i due SELECT che la alimentano, righe ~61/133) sostituire `fiscal_code` con `fiscal_code_enc` nel SELECT e decifrare la colonna nella riga CSV, con lo stesso `catch (SQLException | EncryptionException)` già usato per `birth_date`.

- [ ] **Step 6: Test PatientService (search idx)** — nuovo `PatientServiceTest`: stub `enc.blindIndex(...)`/`enc.decrypt(...)`, verifica che `findAll(search)` metta `searchIdx` nei param e che mapRow chiami `decrypt` sulla colonna `_enc`. (Mockito, no DB.)

- [ ] **Step 7: Run → PASS**

Run: `./mvnw -q test`
Expected: BUILD SUCCESS, suite verde.

- [ ] **Step 8: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/PatientService.java backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java backend/src/main/java/com/dentalcare/service/TenantExportService.java database/install.sql backend/src/test/java/com/dentalcare/service/PatientServiceTest.java
git commit -m "feat(security): cutover fiscal_code pazienti (read/ricerca idx/viste/export) (#7 slice2a)"
```

---

### Task 6: Cutover invoices + estimates (read decrypt + emissione plaintext→null)

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/InvoiceService.java` (read dettaglio ~106-142, emissione plaintext→null)
- Modify: `backend/src/main/java/com/dentalcare/service/EstimateService.java` (read ~394 `patient_fiscal_code`)

**Interfaces:**
- Consumes: `enc.decrypt`; colonne `_enc` (Task 2/3).

- [ ] **Step 1: InvoiceService read** — nel SELECT dettaglio fattura sostituire `i.patient_fiscal_code` con `i.patient_fiscal_code_enc` e decifrare nel mapping (`enc.decrypt(rs.getString("patient_fiscal_code_enc"), s())`) dove oggi si legge `patientFiscalCode`.

- [ ] **Step 2: InvoiceService emissione plaintext→null** — nell'INSERT `invoices` porre `patient_fiscal_code` a `null` (continuando a scrivere `patient_fiscal_code_enc`, già fatto in Task 3).

- [ ] **Step 3: EstimateService read** — dove legge `patient_fiscal_code` (riga ~394) leggere invece `patient_fiscal_code_enc` (la vista `v_patient_estimates_summary` ora lo espone, Task 5) e decifrare: `enc.decrypt(rs.getString("patient_fiscal_code_enc"), s())`. Iniettare `TenantEncryptionService` in `EstimateService` se non presente.

- [ ] **Step 4: Build + suite**

Run: `./mvnw -q test`
Expected: BUILD SUCCESS, suite verde.

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/InvoiceService.java backend/src/main/java/com/dentalcare/service/EstimateService.java
git commit -m "feat(security): cutover fiscal_code fatture+preventivi (read decrypt) (#7 slice2a)"
```

---

## Runbook validazione (DB dev, dopo tutti i task)

1. Riavvio backend → `patchSchema` aggiunge `fiscal_code_enc/idx` + `patient_fiscal_code_enc` a tutti i tenant; viste ricostruite.
2. Login demo → `POST /api/admin/encryption/migrate` → `{"birthDate":0,"fiscalCode":22}`; re-run → `fiscalCode:0` (idempotente).
3. DB: `fiscal_code_idx` popolato; pending (`fiscal_code IS NOT NULL AND fiscal_code_enc IS NULL`) = 0.
4. GET paziente → `fiscalCode` decifrato corretto; ricerca per CF esatto lo trova; ricerca CF parziale NON (atteso).
5. Emissione fattura da preventivo → `invoices.patient_fiscal_code_enc` popolato, plaintext null; dettaglio fattura mostra CF corretto.
6. Export `customers.csv` → colonna `fiscal_code` decifrata.
7. Provisioning nuovo tenant → colonne presenti (patchSchema al provisioning).

## Deploy prod (follow-up, dopo merge)

Aggiornare `directives/deploy-gdpr-slice1-prod.md` (o nuovo doc 2a): la migrazione ora cifra anche `fiscal_code` — stessa procedura (`migrate` idempotente cumulativo), stessa master key. `DROP` colonne plaintext ancora rimandato.
