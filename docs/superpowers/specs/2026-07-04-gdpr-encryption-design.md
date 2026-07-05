# GDPR — Cifratura campo-per-campo con chiavi per-tenant (#7) — Design

**Data:** 2026-07-04
**Proposta:** #7 (`directives/proposte-modifiche.md`)
**Stato:** Design approvato — pronto per writing-plans
**Impatto:** Alto. Feature security-critical con migrazione dati irreversibile su DB clinico multi-tenant.

## Obiettivo

Cifrare a riposo i campi sensibili dei pazienti (art. 32 GDPR) con cifratura campo-per-campo e **chiavi derivate per-tenant**, così che un breach del solo database non esponga i dati in chiaro. Prima iterazione limitata alla tabella `patients` per validare l'intero pattern (deriva chiave → encrypt/decrypt → blind index → ricerca → migrazione → error handling) end-to-end prima di estenderlo alle altre tabelle.

## Decomposizione rivista (blast radius scoperto in fase di plan)

Investigando il codice reale è emerso che i campi sensibili di `patients` si propagano molto oltre PatientService:

| Campo | Consumatori (oltre PatientService) |
|-------|-------------------------------------|
| `fiscal_code` | EstimateService, InvoiceService (+ snapshot in `invoices`), viste preventivi |
| `phone` | AppointmentService (agenda), RecallService, EstimateService |
| `email` | InvoiceService |
| `address_line1` | InvoiceService |
| `birth_date` | **solo PatientService** (viste `v_patient_clinical_card` + `v_patient_dashboard`) |

Le viste coinvolte sono definite in **3 sedi**: `install.sql` (template `create_tenant` + demo `t_9d754153`) e a runtime in `EstimateSchemaInitializer`. Cifrare un campo obbliga ogni consumatore a decifrare in Java nello stesso commit (altrimenti legge `null`).

**Conseguenza:** cifrare `fiscal_code`/`phone`/`email` è inevitabilmente cross-modulo (5 service + ~5 viste ×3 sedi). `birth_date` è l'unico campo contenuto. Si divide quindi l'iterazione in due slice:

- **Slice 1 (questo piano) — `birth_date`.** Prova l'intera macchina crypto end-to-end a basso rischio: `TenantEncryptionService` + HKDF + `MasterKeyProvider` (seam Vault) + migrazione idempotente + config + fail-fast + error handling, **più** il cambiamento strutturale più difficile: ricreazione delle 2 viste pazienti senza `age_years` e calcolo età in Java. Contenuto a PatientService + 2 viste + `EstimateSchemaInitializer`. `birth_date` non è ricercabile → nessun blind index in questo slice.
- **Slice 2 (piano successivo) — `fiscal_code` + `phone` + `email` + `address_line1`.** Aggiunge il blind index + ricerca esatta e il decrypt cross-modulo nei 5 service, su core crypto già provato.

Iterazioni ulteriori: anamnesi, cartelle cliniche, prescrizioni, note appuntamenti.

## Decisioni (dal brainstorming)

1. **Tabella target = `patients`** (vertical slice). Divisa in Slice 1 (`birth_date`) + Slice 2 (campi ricercabili/cross-modulo) — vedi sopra. Le altre tabelle sono iterazioni future.
2. **`birth_date` cifrato**, con il calcolo dell'età **spostato da SQL a Java** (la vista `v_patient_clinical_card` non può più calcolare `age_years` da un valore cifrato).
3. **`fiscal_code`/`phone`/`email` cifrati con blind index → ricerca solo per valore esatto.** Si perde il match parziale `ILIKE` su questi tre campi; la ricerca per nome (non cifrato) resta parziale.
4. **HKDF self-implementato** (RFC 5869 su `javax.crypto.Mac`), **nessuna dipendenza BouncyCastle**.

## Architettura

### Principio: nessuna tabella di chiavi
Le chiavi per-tenant si **derivano deterministicamente** dalla master key + nome schema tenant, non si salvano mai nel DB:

```
tenant_enc_key = HKDF(master_key, salt=tenant_schema, info="dental-enc-v1", len=32)
tenant_idx_key = HKDF(master_key, salt=tenant_schema, info="dental-idx-v1", len=32)
```

- `master_key`: 32 byte casuali, **solo** in env/config `app.encryption.master-key` (mai in DB, mai in git).
- Schema diverso → chiave diversa → isolamento tenant garantito matematicamente.
- Nessuna tabella `tenant_keys` da proteggere.

### Sorgente master key: `MasterKeyProvider` (seam per Vault futuro)
La master key **non** viene letta direttamente da `@Value` dentro il service. È fornita da un'astrazione, così da poter passare a **HashiCorp Vault in seguito senza toccare il service o i domini**:

```java
public interface MasterKeyProvider {
    byte[] masterKey(); // 32 byte; deve fallire se assente/malformata
}
```

- **Iterazione 1 — `ConfigMasterKeyProvider`** (unica impl ora): legge l'hex da `app.encryption.master-key`, decodifica a 32 byte, valida la lunghezza. Bean attivo di default.
- **Futuro — `VaultMasterKeyProvider`** (non implementato ora): legge la chiave da Vault (es. Spring Cloud Vault, KV v2 su un path dedicato). Selezione via `app.encryption.key-source=config|vault` (default `config`) o profilo Spring.
- `TenantEncryptionService` dipende **solo** dall'interfaccia `MasterKeyProvider` e invoca `masterKey()` una volta all'init (fail-fast). Passare a Vault domani = aggiungere `VaultMasterKeyProvider` + dipendenza/config Spring Cloud Vault + `key-source=vault`; **nessuna modifica** a `TenantEncryptionService` né ai service di dominio.

### `TenantEncryptionService`
Nuovo service singleton. Responsabilità uniche: derivare/cachare le chiavi per schema, cifrare, decifrare, calcolare blind index. Dipende da `MasterKeyProvider`.

- **HKDF** (`hkdfSha256(masterKey, salt, info, 32)`): extract (`HMAC(salt, masterKey)`) + expand (RFC 5869). ~30 righe su `javax.crypto.Mac` con `HmacSHA256`. Nessuna dipendenza esterna.
- **encrypt(plaintext, schema)**: `AES/GCM/NoPadding`, IV random 12 byte, tag 128 bit. Output = `Base64(iv || ciphertext || tag)`. `null` → `null`.
- **decrypt(ciphertext, schema)**: inversa; su `AEADBadTagException`/chiave errata → lancia (vedi Error handling). `null` → `null`.
- **blindIndex(plaintext, schema)**: `HMAC-SHA256(lower(trim(plaintext)), idxKey)` → hex. `null`/blank → `null`.
- **Cache**: `ConcurrentHashMap<schema, SecretKey>` per enc e idx (le chiavi derivate sono costose; invalidabili per rotazione futura).
- **Fail-fast**: a `@PostConstruct`/costruttore, se `master-key` manca o non decodifica a 32 byte → eccezione che impedisce l'avvio.

**Non-goal del service**: non conosce tabelle/colonne; è un'utility pura chiamata dai service di dominio.

### Deriva dello schema tenant
Lo `schema` passato al service è sempre `TenantContext.validatedSchema()` (server-derived), coerente col resto del backend. Mai dal client.

## Campi cifrati — tabella `patients` (iterazione 1)

| Campo | Colonna `_enc` | Colonna `_idx` (ricerca esatta) | Note |
|-------|:---:|:---:|------|
| fiscal_code | `fiscal_code_enc` | `fiscal_code_idx` | ricerca esatta |
| phone | `phone_enc` | `phone_idx` | ricerca esatta |
| email | `email_enc` | `email_idx` | ricerca esatta |
| birth_date | `birth_date_enc` | — | età calcolata in Java |
| address_line1 | `address_line1_enc` | — | non ricercabile |
| first_name, last_name | — | — | **in chiaro** (ricerca nome full-text) |

`birth_date` viene cifrato come stringa ISO (`yyyy-MM-dd`) e ridecodificato a `LocalDate` in lettura.

**Limite noto e accettato:** nome e cognome restano leggibili in un breach del DB — cifratura parziale, non totale (scelta della spec per preservare la ricerca anagrafica).

## Modifiche indotte da `birth_date` cifrato

- **Vista `v_patient_clinical_card`**: rimuovere la colonna calcolata `age_years` (non più calcolabile da SQL su dato cifrato). La vista continua a esporre gli altri campi; `birth_date` non è più letto dalla vista in chiaro.
- **`PatientService`**: le query che oggi leggono `age_years`/`birth_date` dalla vista passano a leggere `birth_date_enc` dalla tabella `patients` e a decifrare + calcolare l'età in Java (`Period.between(birth, today).getYears()`), popolando `PatientListDto.ageYears` e `PatientDetailDto.ageYears/birthDate`.
- **Query per fascia d'età**: se ne esistono lato SQL, vanno spostate in Java (da verificare in fase di plan; se assenti, nessuna azione).
- **Cross-check CF di #3**: il validator `@ValidFiscalCode` legge `birthDate` dal **request DTO** (plaintext, pre-cifratura) → **nessuna modifica**.

## Data flow

**Write (`PatientService.create`/`update`):**
1. `@ValidFiscalCode` (di #3) valida il DTO in chiaro (invariato).
2. Per ogni campo sensibile: `enc.encrypt(value, schema)` → colonna `_enc`; per i ricercabili anche `enc.blindIndex(value, schema)` → colonna `_idx`.
3. Le colonne plaintext originali NON vengono più scritte (restano per la fase di migrazione, poi azzerate/eliminate).

**Read (`PatientService.mapRow`):**
1. `enc.decrypt(rs.getString("<campo>_enc"), schema)` per ogni campo cifrato.
2. `birth_date` decifrato → `LocalDate` → età calcolata in Java.

**Search (`PatientService.findAll`):**
- Nome: `WHERE (first_name ILIKE :q OR last_name ILIKE :q)` (chiaro, parziale — invariato).
- CF/phone/email: `:idx = enc.blindIndex(rawQuery, schema)` → `OR fiscal_code_idx = :idx OR phone_idx = :idx OR email_idx = :idx` (match esatto).
- Le due condizioni combinate in `OR`.

## Schema DB e install.sql

- **Patch nuovo** `database/patch_encrypt_patients.sql`: idempotente, itera gli schemi tenant (`pg_namespace ~ '^t_[0-9a-f]{8}$'`, convenzione dei patch esistenti). Per ogni schema:
  - `ALTER TABLE %I.patients ADD COLUMN IF NOT EXISTS fiscal_code_enc text, ... , address_line1_enc text;` (+ le `_idx`).
  - `CREATE INDEX IF NOT EXISTS` sui tre `_idx` (per ricerca esatta veloce).
  - **Ricreazione** della vista `v_patient_clinical_card` senza `age_years`: in Postgres non si può togliere una colonna con `CREATE OR REPLACE VIEW` né `ALTER ... DROP COLUMN`, quindi `DROP VIEW ... ; CREATE VIEW ...`. Verificare in fase di plan eventuali dipendenze dalla vista prima del drop.
- **`install.sql` mirror**: colonne `_enc`/`_idx` + indici aggiunti sia nel template `create_tenant` sia nello schema demo `t_9d754153`; definizione della vista `v_patient_clinical_card` aggiornata (senza `age_years`) in entrambe le sedi.
- **Colonne plaintext** (`fiscal_code`, `birth_date`, `phone`, `email`, `address_line1`): mantenute in iterazione 1, azzerate dalla migrazione. `DROP COLUMN` rimandato a uno step separato dopo verifica in produzione.

## Migrazione dati esistenti

- **Endpoint admin idempotente** `POST /api/admin/encryption/migrate` (ROLE_TENANT_ADMIN / ROLE_ADMIN), che per lo schema del tenant corrente:
  1. Seleziona le righe non ancora migrate (`fiscal_code_enc IS NULL AND fiscal_code IS NOT NULL`, o marcatore equivalente).
  2. Per ciascuna: cifra i campi, calcola gli idx, scrive `_enc`/`_idx`, azzera i plaintext.
  3. Ritorna il conteggio migrato.
- **Idempotente e ri-eseguibile**: processa solo righe non ancora cifrate; una seconda esecuzione è no-op.
- **Ordine operativo (runbook)**: backup DB → applicare il patch schema → deploy backend (che cifra i nuovi write) → eseguire la migrazione per ciascun tenant in finestra di manutenzione → verificare → (step futuro) `DROP` colonne plaintext.
- **Rollback**: finché le colonne plaintext non sono azzerate/eliminate, i dati originali restano; se la migrazione fallisce a metà, le righe già migrate hanno `_enc` valorizzato e plaintext azzerato, le altre restano in chiaro → ri-esecuzione completa il lavoro. Nessuna perdita se si è fatto il backup.

## Key management

- **Iterazione 1 (`ConfigMasterKeyProvider`)**: `app.encryption.master-key` (hex 32 byte) in `backend/config/application.properties` (dev) e `config/application-prod.properties` (prod) — **gitignored**, secondo il pattern di precedenza config già in uso. `app.encryption.key-source=config` (default).
- **Chiavi diverse dev e prod.** Generazione una-tantum: `openssl rand -hex 32`.
- **Perdita chiave = dati irrecuperabili.** Finché non si usa Vault, la master key va conservata in un secret store sicuro (password manager), non solo nel file sul server. Documentato nel runbook.
- **Vault (futuro, già predisposto)**: il secret store target è **HashiCorp Vault**. Con l'astrazione `MasterKeyProvider` il passaggio è additivo: `VaultMasterKeyProvider` + Spring Cloud Vault + `key-source=vault`, senza toccare cifratura o domini. Vedi Architettura → `MasterKeyProvider`.
- **Rotazione**: fuori scope iterazione 1; l'interfaccia del service (cache invalidabile, `info` versionata `-v1`) e l'astrazione `MasterKeyProvider` sono predisposte per un runner di re-encryption e per la rotazione gestita da Vault in futuro.

## Error handling

- **Decrypt fallito** (tag GCM invalido = manomissione o chiave errata): lancia eccezione dedicata (`EncryptionException`), logga `actor_id` + risorsa **senza il plaintext**, risposta 500. Mai ritornare silenziosamente dati corrotti o nulli come se fossero validi.
- **Master key assente/malformata**: fail-fast all'avvio.
- **null-safe**: plaintext `null` → cipher `null`; nessun crash su campi opzionali (phone/email/address possono essere null).

## Testing

- **Unit `TenantEncryptionService`**: round-trip encrypt→decrypt; schema diverso → ciphertext diverso e non decifrabile con l'altra chiave; blind index deterministico e case-insensitive (`Rossi`==`rossi`); un vettore noto HKDF-SHA256 (RFC 5869) per validare la derivazione; null/blank handling; IV casuale → due encrypt della stessa stringa danno ciphertext diversi ma stesso plaintext.
- **`PatientService`**: create/update scrive `_enc`/`_idx`; mapRow decifra; ricerca per CF/phone/email esatti trova via blind index; ricerca per nome resta parziale; età calcolata in Java corretta.
- **Migrazione**: idempotenza (seconda esecuzione = 0 righe migrate); una riga in chiaro → cifrata + plaintext azzerato.
- **Sicurezza**: decrypt con chiave di schema diverso → eccezione (isolamento tenant).

## Fuori scope (iterazione 1)

- Cifratura di anamnesi, cartelle cliniche, prescrizioni, note appuntamenti (iterazioni future, stesso pattern).
- MinIO Server-Side Encryption per i file (ortopanoramiche/PDF) — track separato, zero modifiche codice.
- Runner di rotazione master key.
- Integrazione HashiCorp **Vault** (`VaultMasterKeyProvider` + Spring Cloud Vault): la seam `MasterKeyProvider` è pronta, l'implementazione è iterazione futura.
- `DROP COLUMN` delle colonne plaintext (step successivo, dopo verifica in produzione).
- Cifratura di `first_name`/`last_name` (richiederebbe motore di ricerca tokenizzato separato).

## Rischi e mitigazioni

| Rischio | Mitigazione |
|---------|-------------|
| Perdita master key → dati irrecuperabili | Backup chiave in secret store; runbook esplicito; chiavi separate dev/prod |
| Migrazione parziale/corruzione | Backup DB pre-migrazione; migrazione idempotente ri-eseguibile; plaintext mantenuto finché non verificato |
| Regressione ricerca (perdita ILIKE su CF/phone/email) | Decisione accettata; ricerca nome invariata; match esatto documentato in UX |
| Vista età rotta | `age_years` rimosso dalla vista, calcolo spostato in Java con test dedicato |
| Performance deriva chiave | Cache per-schema in memoria |
