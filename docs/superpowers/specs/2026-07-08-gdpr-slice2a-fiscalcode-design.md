# GDPR cifratura Slice 2a — `fiscal_code` paziente — Design

Sotto-iterazione di #7 (vedi `2026-07-04-gdpr-encryption-design.md`). Slice 1
(`birth_date`) ha provato end-to-end la macchina crypto: `TenantEncryptionService`
(HKDF+AES-256-GCM), `MasterKeyProvider` (seam Vault), rollout stadiato
dual-write → migrate → cutover, patch schema idempotente a startup + provisioning.

Slice 2a estende quella macchina al **codice fiscale del paziente**, aggiungendo
la **ricerca esatta via blind index**. Ambito confermato con l'utente: **solo CF
paziente**; studio emittente (`clinics`/`invoices.issuer_fiscal_code`) e staff
(`providers.fiscal_code`) restano in chiaro (CF emittente già pubblico in fattura).

## Obiettivo

Cifrare a riposo `patients.fiscal_code` e il suo unico snapshot persistito
`invoices.patient_fiscal_code`, mantenendo la ricercabilità per valore esatto.

## Blast radius (verificato sul codice)

| Sito | Uso di `fiscal_code` |
|------|----------------------|
| `patients.fiscal_code` | colonna sorgente (target) |
| `PatientService` | INSERT/UPDATE (write), ricerca `ILIKE` (findAll), read mapRow, viste |
| `invoices.patient_fiscal_code` | **snapshot persistito** all'emissione (denormalizzato per integrità legale) |
| `InvoiceService.createFromEstimate` | snapshotta `pat.fiscal_code` → colonna invoice |
| `InvoiceService` (read dettaglio) | legge `i.patient_fiscal_code` |
| `EstimateService` | legge `patient_fiscal_code` da vista/join su `patients` (NON colonna persistita) |
| `TenantExportService` | export `customers.csv` (già decifra `birth_date_enc`) |
| viste `v_patient_dashboard`, `v_patient_clinical_card`, `v_patient_estimates_summary` | espongono `fiscal_code` |

`estimates` NON ha colonna `patient_fiscal_code` persistita (deriva da vista/join):
si risolve facendo esporre `fiscal_code_enc` alla vista e decifrando in
`EstimateService`. Snapshot persistito da cifrare: **solo `invoices`**.

## Nuova primitiva — blind index

`TenantEncryptionService.blindIndex(value, schema)`:

- **Chiave separata** dalla enc key: `idx_key = HKDF-SHA256(masterKey, salt=schema,
  info="dental-blind-idx-v1", 32)`. Non riusa la chiave di cifratura per il MAC.
- **Deterministico**: `HMAC-SHA256(idx_key, normalize(value))`, output esadecimale.
- **Normalizzazione** (Slice 2a, CF): `value.trim().toUpperCase(Locale.ROOT)` →
  case-insensitive (`rossi...`==`ROSSI...`). Per 2b (phone/email) la
  normalizzazione sarà rivista (phone: sole cifre; email: lowercase) — fuori scope.
- `null` → `null` (campi opzionali).
- Deterministico ⇒ rivela solo l'uguaglianza tra CF; il CF è già unico per persona.
  Nessun ordinamento/range leak. Accettato.

## Modello colonne

| Campo | `_enc` (AES-GCM) | `_idx` (blind index) | Note |
|-------|------------------|----------------------|------|
| `patients.fiscal_code` | `fiscal_code_enc` | `fiscal_code_idx` (+ index) | ricerca esatta |
| `invoices.patient_fiscal_code` | `patient_fiscal_code_enc` | — | snapshot, non ricercato |

`first_name`/`last_name` restano in chiaro (ricerca nome full-text preservata) —
limite noto e accettato dalla spec padre.

## Rollout stadiato (identico a Slice 1)

1. **dual-write (non-breaking).** Patch schema aggiunge le colonne `_enc`/`_idx`
   (idempotente, tutti i tenant + provisioning). `PatientService` create/update
   scrive `fiscal_code` (plaintext, ancora) **+** `fiscal_code_enc` + `fiscal_code_idx`.
   `InvoiceService` emissione scrive `patient_fiscal_code` (plaintext) **+**
   `patient_fiscal_code_enc` (copia del ciphertext `pat.fiscal_code_enc`, stessa
   chiave tenant → decifrabile). Nessun read/vista toccato: build resta verde.
2. **migrate (idempotente, per-tenant, endpoint esistente esteso).**
   - `patients`: `WHERE fiscal_code_enc IS NULL AND fiscal_code IS NOT NULL` →
     popola `fiscal_code_enc` + `fiscal_code_idx`.
   - `invoices`: `WHERE patient_fiscal_code_enc IS NULL AND patient_fiscal_code IS NOT NULL`
     → cifra lo snapshot storico di ciascuna fattura (accuratezza storica).
3. **cutover.**
   - `PatientService`: read decifra `fiscal_code_enc`; ricerca CF passa da
     `fiscal_code ILIKE` a `fiscal_code_idx = :searchIdx` (`enc.blindIndex(search)`);
     write smette il plaintext (`fiscal_code = NULL`, solo `_enc`/`_idx`).
   - `InvoiceService`: read decifra `patient_fiscal_code_enc`; emissione smette il
     plaintext snapshot.
   - `EstimateService`: read decifra `fiscal_code_enc` (vista lo espone).
   - `TenantExportService`: decifra `fiscal_code` in `customers.csv`.
   - viste: espongono `fiscal_code_enc` (+ `fiscal_code_idx` per la ricerca) invece
     di `fiscal_code` plaintext.
   - Colonne plaintext (`patients.fiscal_code`, `invoices.patient_fiscal_code`)
     **mantenute** (azzerate dai write, non droppate): `DROP COLUMN` rimandato a step
     separato dopo verifica prod, come `birth_date`.

## Ricerca — tradeoff UX

La ricerca unica (`findAll`) oggi fa `full_name OR fiscal_code OR phone OR email
ILIKE '%q%'`. Dopo il cutover il termine CF diventa **match esatto** via blind
index: `... OR fiscal_code_idx = enc.blindIndex(q)`. CF parziale non trova più
(a meno che matchi nome/phone/email). Nome resta parziale. Documentato in UX.

## Compatibilità e sicurezza

- **Non-breaking a stadi**: dual-write non tocca read/viste; migrate idempotente;
  cutover in un secondo momento. Merge finale = stato cutover (come Slice 1).
- **Snapshot invoice** cifrato: senza questo, un breach del DB leggerebbe il CB del
  paziente dalle fatture. Copia del ciphertext (stessa chiave) → nessun decrypt in
  emissione.
- **`@ValidFiscalCode`** (P2 #3) valida prima della cifratura: nessun conflitto.
- **install.sql mirror**: le colonne + viste vanno riflesse in `database/install.sql`
  (create_tenant heredoc + demo) come per `birth_date_enc`.
- **Chiave**: stessa master key per enc e idx (derivazioni HKDF distinte). Nessun
  nuovo segreto.

## Non-goal (fuori scope 2a)

- `phone`/`email`/`address_line1` (→ Slice 2b, normalizzazione blind index diversa).
- CF di studio/emittente/staff.
- DROP delle colonne plaintext (step separato post-prod).
- Cifratura `first_name`/`last_name`.

## Test

- **`TenantEncryptionService.blindIndex`**: deterministico (stesso input → stesso
  idx); case-insensitive (`rossi`==`ROSSI`); schema-bound (schema diverso → idx
  diverso); `null`→`null`; distinto dalla enc key.
- **`PatientService`**: create/update scrive `_enc`/`_idx`; mapRow decifra; ricerca
  CF esatta trova via idx; ricerca nome resta parziale.
- **`InvoiceService`**: snapshot cifrato all'emissione; read decifra.
- **`EncryptionMigrationService`**: migra CF paziente + snapshot invoice; idempotente
  (re-run = 0); negative-path.
