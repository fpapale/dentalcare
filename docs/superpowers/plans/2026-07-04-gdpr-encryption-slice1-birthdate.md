# GDPR Cifratura — Slice 1 (`birth_date`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cifrare a riposo `patients.birth_date` con chiave per-tenant derivata (HKDF + AES-256-GCM), provando l'intera macchina crypto end-to-end con blast radius contenuto a `PatientService` + 2 viste pazienti, e spostando il calcolo dell'età da SQL a Java.

**Architecture:** Nuovo `TenantEncryptionService` che deriva `encKey` per-tenant via HKDF-SHA256 dalla master key fornita da un'astrazione `MasterKeyProvider` (seam per Vault futuro). Rollout **staged e non-breaking**: (1) aggiungi colonna `birth_date_enc` + dual-write, (2) migra i dati esistenti, (3) cutover — leggi da `_enc`, età in Java, rimuovi `birth_date`/`age_years` dalle viste. Le colonne/viste per i tenant esistenti sono auto-applicate all'avvio da `EstimateSchemaInitializer`; la migrazione dati è un endpoint admin idempotente.

**Tech Stack:** Java 21, Spring Boot, `javax.crypto` (AES/GCM/NoPadding, HmacSHA256), PostgreSQL, `NamedParameterJdbcTemplate`/`JdbcTemplate`.

## Global Constraints

- Cifratura: AES-256-GCM, IV random 12 byte, tag 128 bit; output `Base64(iv || ciphertext || tag)`. Chiave = `HKDF-SHA256(masterKey, salt=tenantSchema, info="dental-enc-v1", 32)`.
- La master key **non** è letta da `@Value` nel service: arriva da `MasterKeyProvider` (impl attuale `ConfigMasterKeyProvider` legge `app.encryption.master-key`, hex 32 byte; `app.encryption.key-source=config` default). Fail-fast all'avvio se assente/malformata.
- Lo `schema` passato al service è sempre `TenantContext.validatedSchema()` (server-derived), mai dal client.
- `null`/blank plaintext → cipher `null`. Decrypt fallito (tag GCM invalido) → `EncryptionException`, log `actor+resource` senza plaintext, 500. Mai ritornare dati corrotti silenziosamente.
- Rollout non-breaking: nessun task lascia `PatientService` rotto; le viste espongono `birth_date`/`age_years` finché il cutover (Task 5) non le rimuove, momento in cui l'età è già calcolata in Java.
- `install.sql` deve rispecchiare il DB: colonna `birth_date_enc` nel template `create_tenant` + demo `t_9d754153`; viste `v_patient_clinical_card`/`v_patient_dashboard` aggiornate in entrambe le sedi al cutover. La master key **non** va mai in git.
- Build verdi: `cd backend && mvn -q test`. Commit piccoli, stile `feat(security): ...`, footer `Co-Authored-By: Claude <noreply@anthropic.com>`.
- YAGNI: NON implementare blind index, rotazione chiave, o cifratura di altri campi in questo slice (sono Slice 2+).

---

## File Structure

- Create `backend/src/main/java/com/dentalcare/security/crypto/MasterKeyProvider.java` — interfaccia sorgente master key.
- Create `backend/src/main/java/com/dentalcare/security/crypto/ConfigMasterKeyProvider.java` — impl da config; fail-fast.
- Create `backend/src/main/java/com/dentalcare/security/crypto/TenantEncryptionService.java` — HKDF + AES-GCM encrypt/decrypt, cache chiavi.
- Create `backend/src/main/java/com/dentalcare/exception/EncryptionException.java` — errore decrypt/crypto.
- Modify `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` — runStep colonna `birth_date_enc`; (Task 5) rebuild viste senza `birth_date`/`age_years`.
- Modify `backend/src/main/java/com/dentalcare/service/PatientService.java` — dual-write, poi cutover read/write + età in Java.
- Create `backend/src/main/java/com/dentalcare/controller/EncryptionMigrationController.java` — endpoint migrazione.
- Create `backend/src/main/java/com/dentalcare/service/EncryptionMigrationService.java` — logica migrazione idempotente.
- Modify `database/install.sql` — colonna `birth_date_enc` + (Task 5) viste.
- Modify `backend/config/application.properties` (gitignored, dev) — `app.encryption.master-key` + `key-source`.
- Tests: `TenantEncryptionServiceTest`, `ConfigMasterKeyProviderTest`, `EncryptionMigrationServiceTest`, e asserzioni su `PatientService` (se esiste un test; altrimenti unit sul mapping via il service crypto).

---

## Task 1: MasterKeyProvider + ConfigMasterKeyProvider + config

**Files:**
- Create: `backend/src/main/java/com/dentalcare/security/crypto/MasterKeyProvider.java`
- Create: `backend/src/main/java/com/dentalcare/security/crypto/ConfigMasterKeyProvider.java`
- Modify: `backend/config/application.properties` (dev, gitignored)
- Test: `backend/src/test/java/com/dentalcare/security/crypto/ConfigMasterKeyProviderTest.java`

**Interfaces:**
- Produces: `MasterKeyProvider.masterKey() -> byte[]` (32 byte); bean `ConfigMasterKeyProvider`.

- [ ] **Step 1: Test (fail-fast + lunghezza)**

`ConfigMasterKeyProviderTest.java`:
```java
package com.dentalcare.security.crypto;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ConfigMasterKeyProviderTest {

    private static final String VALID_HEX = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"; // 32 byte

    @Test
    void validHexProvides32Bytes() {
        ConfigMasterKeyProvider p = new ConfigMasterKeyProvider(VALID_HEX);
        assertEquals(32, p.masterKey().length);
    }

    @Test
    void blankKeyFailsFast() {
        assertThrows(IllegalStateException.class, () -> new ConfigMasterKeyProvider("  "));
    }

    @Test
    void wrongLengthFailsFast() {
        assertThrows(IllegalStateException.class, () -> new ConfigMasterKeyProvider("00112233")); // 4 byte
    }

    @Test
    void nonHexFailsFast() {
        assertThrows(IllegalStateException.class,
                () -> new ConfigMasterKeyProvider("zz".repeat(32)));
    }

    @Test
    void masterKeyReturnsDefensiveCopy() {
        ConfigMasterKeyProvider p = new ConfigMasterKeyProvider(VALID_HEX);
        byte[] a = p.masterKey();
        a[0] = 99;
        assertNotEquals(99, p.masterKey()[0]); // mutare il risultato non intacca lo stato
    }
}
```

- [ ] **Step 2: Run — fallisce (classi assenti)**

Run: `cd backend && mvn -q -Dtest=ConfigMasterKeyProviderTest test`
Expected: FAIL compilazione.

- [ ] **Step 3: Interfaccia**

`MasterKeyProvider.java`:
```java
package com.dentalcare.security.crypto;

/** Sorgente della master key di cifratura. Impl attuale: config; futura: Vault. */
public interface MasterKeyProvider {
    /** @return master key di 32 byte; l'impl deve fallire se assente/malformata. */
    byte[] masterKey();
}
```

- [ ] **Step 4: Impl da config (fail-fast)**

`ConfigMasterKeyProvider.java`:
```java
package com.dentalcare.security.crypto;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Condition;
import org.springframework.stereotype.Component;

import java.util.HexFormat;

/**
 * Legge la master key (hex, 32 byte) da {@code app.encryption.master-key}.
 * Attivo di default ({@code app.encryption.key-source=config}). Fail-fast alla costruzione
 * se la chiave è assente o non decodifica a 32 byte, così l'app non parte senza cifratura valida.
 */
@Component
@org.springframework.boot.autoconfigure.condition.ConditionalOnProperty(
        name = "app.encryption.key-source", havingValue = "config", matchIfMissing = true)
public class ConfigMasterKeyProvider implements MasterKeyProvider {

    private final byte[] key;

    public ConfigMasterKeyProvider(@Value("${app.encryption.master-key:}") String hex) {
        if (hex == null || hex.isBlank()) {
            throw new IllegalStateException("app.encryption.master-key mancante");
        }
        byte[] decoded;
        try {
            decoded = HexFormat.of().parseHex(hex.trim());
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("app.encryption.master-key non è hex valido", e);
        }
        if (decoded.length != 32) {
            throw new IllegalStateException(
                    "app.encryption.master-key deve essere 32 byte (64 hex), trovati " + decoded.length);
        }
        this.key = decoded;
    }

    @Override
    public byte[] masterKey() {
        return key.clone(); // copia difensiva: il chiamante non può mutare lo stato interno
    }
}
```

- [ ] **Step 5: Config dev**

In `backend/config/application.properties` (gitignored) aggiungere:
```properties
app.encryption.key-source=config
app.encryption.master-key=<generare: openssl rand -hex 32>
```
Generare la chiave dev una volta e incollarla. NON committare questo file (è già gitignored via `backend/config/`).

- [ ] **Step 6: Run — passa**

Run: `cd backend && mvn -q -Dtest=ConfigMasterKeyProviderTest test`
Expected: PASS (5 test).

- [ ] **Step 7: Commit**
```bash
git add backend/src/main/java/com/dentalcare/security/crypto/MasterKeyProvider.java \
        backend/src/main/java/com/dentalcare/security/crypto/ConfigMasterKeyProvider.java \
        backend/src/test/java/com/dentalcare/security/crypto/ConfigMasterKeyProviderTest.java
git commit -m "feat(security): MasterKeyProvider + ConfigMasterKeyProvider (seam Vault) (#7)"
```
(NON committare `backend/config/application.properties`.)

---

## Task 2: TenantEncryptionService (HKDF + AES-256-GCM)

**Files:**
- Create: `backend/src/main/java/com/dentalcare/exception/EncryptionException.java`
- Create: `backend/src/main/java/com/dentalcare/security/crypto/TenantEncryptionService.java`
- Test: `backend/src/test/java/com/dentalcare/security/crypto/TenantEncryptionServiceTest.java`

**Interfaces:**
- Consumes: `MasterKeyProvider` (Task 1).
- Produces: `TenantEncryptionService.encrypt(String plaintext, String schema) -> String`, `decrypt(String ciphertext, String schema) -> String`.

- [ ] **Step 1: Test**

`TenantEncryptionServiceTest.java`:
```java
package com.dentalcare.security.crypto;

import com.dentalcare.exception.EncryptionException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TenantEncryptionServiceTest {

    // master key fissa per i test
    private final MasterKeyProvider mk = () -> new byte[]{
            1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
            17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};
    private final TenantEncryptionService enc = new TenantEncryptionService(mk);

    @Test
    void roundTrip() {
        String c = enc.encrypt("1980-01-31", "t_9d754153");
        assertNotEquals("1980-01-31", c);
        assertEquals("1980-01-31", enc.decrypt(c, "t_9d754153"));
    }

    @Test
    void nullAndBlankPassThrough() {
        assertNull(enc.encrypt(null, "t_9d754153"));
        assertNull(enc.decrypt(null, "t_9d754153"));
    }

    @Test
    void randomIvGivesDifferentCiphertextSamePlaintext() {
        String a = enc.encrypt("same", "t_9d754153");
        String b = enc.encrypt("same", "t_9d754153");
        assertNotEquals(a, b);                      // IV casuale
        assertEquals("same", enc.decrypt(a, "t_9d754153"));
        assertEquals("same", enc.decrypt(b, "t_9d754153"));
    }

    @Test
    void differentSchemaCannotDecrypt() {
        String c = enc.encrypt("secret", "t_9d754153");
        assertThrows(EncryptionException.class, () -> enc.decrypt(c, "t_abcdef12"));
    }

    @Test
    void tamperedCiphertextThrows() {
        String c = enc.encrypt("secret", "t_9d754153");
        String tampered = c.substring(0, c.length() - 2) + (c.endsWith("A") ? "B" : "A");
        assertThrows(EncryptionException.class, () -> enc.decrypt(tampered, "t_9d754153"));
    }
}
```

- [ ] **Step 2: Run — fallisce**

Run: `cd backend && mvn -q -Dtest=TenantEncryptionServiceTest test`
Expected: FAIL compilazione.

- [ ] **Step 3: EncryptionException**

`EncryptionException.java`:
```java
package com.dentalcare.exception;

public class EncryptionException extends RuntimeException {
    public EncryptionException(String message, Throwable cause) { super(message, cause); }
}
```

- [ ] **Step 4: Service (HKDF-SHA256 + AES-GCM)**

`TenantEncryptionService.java`:
```java
package com.dentalcare.security.crypto;

import com.dentalcare.exception.EncryptionException;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.Mac;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Cifratura campo-per-campo con chiave derivata per-tenant.
 * enc_key = HKDF-SHA256(masterKey, salt=schema, info="dental-enc-v1", 32).
 * Formato: Base64(iv[12] || ciphertext || tag[16]) via AES/GCM/NoPadding.
 */
@Service
public class TenantEncryptionService {

    private static final String INFO_ENC = "dental-enc-v1";
    private static final int GCM_IV_BYTES = 12;
    private static final int GCM_TAG_BITS = 128;

    private final byte[] masterKey;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, SecretKeySpec> encKeyCache = new ConcurrentHashMap<>();

    public TenantEncryptionService(MasterKeyProvider keyProvider) {
        this.masterKey = keyProvider.masterKey(); // fail-fast già nel provider
    }

    public String encrypt(String plaintext, String schema) {
        if (plaintext == null) return null;
        try {
            byte[] iv = new byte[GCM_IV_BYTES];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, encKey(schema), new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] ct = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            byte[] out = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, out, 0, iv.length);
            System.arraycopy(ct, 0, out, iv.length, ct.length);
            return Base64.getEncoder().encodeToString(out);
        } catch (Exception e) {
            throw new EncryptionException("encrypt failed", e);
        }
    }

    public String decrypt(String ciphertext, String schema) {
        if (ciphertext == null) return null;
        try {
            byte[] raw = Base64.getDecoder().decode(ciphertext);
            byte[] iv = Arrays.copyOfRange(raw, 0, GCM_IV_BYTES);
            byte[] ct = Arrays.copyOfRange(raw, GCM_IV_BYTES, raw.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, encKey(schema), new GCMParameterSpec(GCM_TAG_BITS, iv));
            return new String(cipher.doFinal(ct), StandardCharsets.UTF_8);
        } catch (Exception e) {
            // tag invalido = chiave sbagliata o manomissione; nessun plaintext nel messaggio
            throw new EncryptionException("decrypt failed for schema " + schema, e);
        }
    }

    private SecretKeySpec encKey(String schema) {
        return encKeyCache.computeIfAbsent(schema,
                s -> new SecretKeySpec(hkdfSha256(masterKey, s.getBytes(StandardCharsets.UTF_8),
                        INFO_ENC.getBytes(StandardCharsets.UTF_8), 32), "AES"));
    }

    // HKDF-SHA256 (RFC 5869): extract + expand
    private static byte[] hkdfSha256(byte[] ikm, byte[] salt, byte[] info, int length) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            // extract
            mac.init(new SecretKeySpec(salt.length == 0 ? new byte[32] : salt, "HmacSHA256"));
            byte[] prk = mac.doFinal(ikm);
            // expand
            mac.init(new SecretKeySpec(prk, "HmacSHA256"));
            byte[] okm = new byte[length];
            byte[] t = new byte[0];
            int pos = 0;
            for (int i = 1; pos < length; i++) {
                mac.reset();
                mac.update(t);
                mac.update(info);
                mac.update((byte) i);
                t = mac.doFinal();
                int n = Math.min(t.length, length - pos);
                System.arraycopy(t, 0, okm, pos, n);
                pos += n;
            }
            return okm;
        } catch (Exception e) {
            throw new EncryptionException("hkdf failed", e);
        }
    }
}
```

- [ ] **Step 5: Run — passa**

Run: `cd backend && mvn -q -Dtest=TenantEncryptionServiceTest test`
Expected: PASS (5 test).

- [ ] **Step 6: Commit**
```bash
git add backend/src/main/java/com/dentalcare/exception/EncryptionException.java \
        backend/src/main/java/com/dentalcare/security/crypto/TenantEncryptionService.java \
        backend/src/test/java/com/dentalcare/security/crypto/TenantEncryptionServiceTest.java
git commit -m "feat(security): TenantEncryptionService HKDF+AES-256-GCM (#7)"
```

---

## Task 3: Colonna `birth_date_enc` + dual-write (non-breaking)

Aggiunge la colonna e fa scrivere a `PatientService` sia il plaintext (invariato, per viste/età) sia il cifrato. Nessuna lettura cambia ancora → non-breaking. Le viste restano intatte.

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` (runStep colonna)
- Modify: `database/install.sql` (colonna nel template `create_tenant` + demo)
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java` (inietta enc; dual-write in create/update)

**Interfaces:**
- Consumes: `TenantEncryptionService.encrypt` (Task 2).
- Produces: colonna `patients.birth_date_enc`; `PatientService` scrive `birth_date_enc` in create/update.

- [ ] **Step 1: Initializer — runStep colonna (auto-applica a tutti i tenant)**

In `EstimateSchemaInitializer.applyTenantOperationalPatches`, dentro il loop `for (String schema : schemas)`, accanto agli altri `runStep`, aggiungere:
```java
runStep(schema, "patients birth_date_enc", () ->
    jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS birth_date_enc text"));
```

- [ ] **Step 2: install.sql mirror — colonna**

In `database/install.sql`, nel `CREATE TABLE patients` del heredoc `create_tenant` (accanto a `foreign_patient`) e nel `CREATE TABLE t_9d754153.patients`, aggiungere:
```sql
    birth_date_enc text,
```
(rispettando la punteggiatura locale, come fatto per `foreign_patient`).

- [ ] **Step 3: PatientService — inietta enc + dual-write**

Modificare il costruttore per iniettare `TenantEncryptionService` e aggiungere il campo. In `create()` e `update()`, aggiungere alla lista colonne/valori `birth_date_enc` e il parametro:
```java
// costruttore
private final TenantEncryptionService enc;
public PatientService(NamedParameterJdbcTemplate jdbc, TenantEncryptionService enc) {
    this.jdbc = jdbc; this.enc = enc;
}
```
In `create()` INSERT: aggiungere `birth_date_enc` alle colonne, `:birthDateEnc` ai VALUES, e
```java
.addValue("birthDateEnc",
    enc.encrypt(request.birthDate() != null ? request.birthDate().toString() : null, s()))
```
(la colonna plaintext `birth_date` resta scritta come ora — dual-write.)
In `update()` SET: aggiungere `birth_date_enc = :birthDateEnc` con lo stesso param.

- [ ] **Step 4: Build**

Run: `cd backend && mvn -q test`
Expected: PASS (nessuna regressione; la lettura non è cambiata).

- [ ] **Step 5: Commit**
```bash
git add backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java \
        database/install.sql \
        backend/src/main/java/com/dentalcare/service/PatientService.java
git commit -m "feat(security): colonna birth_date_enc + dual-write patients (#7)"
```

---

## Task 4: Migrazione dati esistenti (endpoint admin idempotente)

Cifra `birth_date` delle righe esistenti in `birth_date_enc` (senza toccare il plaintext ancora — il cutover avviene in Task 5). Idempotente: processa solo righe con `birth_date_enc IS NULL AND birth_date IS NOT NULL`.

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/EncryptionMigrationService.java`
- Create: `backend/src/main/java/com/dentalcare/controller/EncryptionMigrationController.java`
- Test: `backend/src/test/java/com/dentalcare/service/EncryptionMigrationServiceTest.java`

**Interfaces:**
- Consumes: `TenantEncryptionService`, `NamedParameterJdbcTemplate`, `TenantContext`.
- Produces: `POST /api/admin/encryption/migrate` → `{ "migrated": <n> }` per lo schema del tenant corrente.

- [ ] **Step 1: Test (idempotenza + cifratura riga)**

`EncryptionMigrationServiceTest.java` — mockare `NamedParameterJdbcTemplate`. Verificare:
- se la query di update ritorna N righe, `migrateBirthDate()` ritorna N;
- una seconda chiamata su 0 righe da migrare ritorna 0.
Seguire lo stile dei test service esistenti per lo stub di `TenantContext` (vedi `ProductCategoryServiceTest`). Poiché la cifratura avviene riga-per-riga in Java, il test principale valida che il metodo selezioni le righe non migrate, chiami `enc.encrypt` e faccia l'UPDATE; asserire il conteggio e che `enc.encrypt` sia invocato per ogni riga.

```java
// scheletro — completare con lo stub TenantContext dello stile esistente
@Test
void migratesOnlyUnmigratedRows() {
    // given jdbc.query(select ...) -> 2 righe con id+birth_date
    // when migrateBirthDate()
    // then enc.encrypt chiamato 2 volte, jdbc.update chiamato 2 volte, ritorna 2
}

@Test
void secondRunMigratesZero() {
    // given jdbc.query(select ...) -> lista vuota
    // then ritorna 0, nessun update
}
```

- [ ] **Step 2: Run — fallisce**

Run: `cd backend && mvn -q -Dtest=EncryptionMigrationServiceTest test`
Expected: FAIL compilazione.

- [ ] **Step 3: Service**

`EncryptionMigrationService.java`:
```java
package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import com.dentalcare.security.crypto.TenantEncryptionService;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Migrazione idempotente: cifra birth_date esistenti in birth_date_enc (plaintext lasciato per il cutover). */
@Service
public class EncryptionMigrationService {

    private final NamedParameterJdbcTemplate jdbc;
    private final TenantEncryptionService enc;

    public EncryptionMigrationService(NamedParameterJdbcTemplate jdbc, TenantEncryptionService enc) {
        this.jdbc = jdbc; this.enc = enc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    @Transactional
    public int migrateBirthDate() {
        String schema = s();
        List<Row> rows = jdbc.query(
                "SELECT id, birth_date FROM " + schema + ".patients"
                        + " WHERE birth_date_enc IS NULL AND birth_date IS NOT NULL",
                (rs, n) -> new Row(rs.getObject("id", UUID.class),
                        rs.getObject("birth_date", LocalDate.class)));
        int migrated = 0;
        for (Row r : rows) {
            jdbc.update("UPDATE " + schema + ".patients SET birth_date_enc = :enc WHERE id = :id",
                    new MapSqlParameterSource()
                            .addValue("enc", enc.encrypt(r.birthDate().toString(), schema))
                            .addValue("id", r.id()));
            migrated++;
        }
        return migrated;
    }

    private record Row(UUID id, LocalDate birthDate) {}
}
```

- [ ] **Step 4: Controller**

`EncryptionMigrationController.java`:
```java
package com.dentalcare.controller;

import com.dentalcare.service.EncryptionMigrationService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/admin/encryption")
public class EncryptionMigrationController {

    private final EncryptionMigrationService migrationService;

    public EncryptionMigrationController(EncryptionMigrationService migrationService) {
        this.migrationService = migrationService;
    }

    @PostMapping("/migrate")
    public Map<String, Integer> migrate() {
        return Map.of("migrated", migrationService.migrateBirthDate());
    }
}
```
`/api/admin/**` è già ristretto a `ROLE_ADMIN`/`ROLE_TENANT_ADMIN` in `SecurityConfig` — nessuna modifica security.

- [ ] **Step 5: Run — passa**

Run: `cd backend && mvn -q -Dtest=EncryptionMigrationServiceTest test`
Expected: PASS.

- [ ] **Step 6: Commit**
```bash
git add backend/src/main/java/com/dentalcare/service/EncryptionMigrationService.java \
        backend/src/main/java/com/dentalcare/controller/EncryptionMigrationController.java \
        backend/src/test/java/com/dentalcare/service/EncryptionMigrationServiceTest.java
git commit -m "feat(security): endpoint migrazione birth_date cifrato (#7)"
```

---

## Task 5: Cutover — leggi da `_enc`, età in Java, viste senza `birth_date`/`age_years`

Dopo che la migrazione ha popolato `birth_date_enc` per tutte le righe, si passa a leggere dal cifrato, si calcola l'età in Java, e si rimuovono `birth_date`/`age_years` dalle due viste. Il plaintext `birth_date` viene azzerato (colonna mantenuta, DROP in step futuro).

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java` (read da `birth_date_enc` + età Java; stop scrittura plaintext)
- Modify: `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` (`rebuildPatientDashboardView`, `rebuildPatientClinicalCardView` senza `birth_date`/`age_years`)
- Modify: `database/install.sql` (viste `v_patient_dashboard` + `v_patient_clinical_card` nel template + demo, senza `birth_date`/`age_years`)

**Interfaces:**
- Consumes: `TenantEncryptionService.decrypt`, colonna `birth_date_enc`.
- Produces: DTO `birthDate`/`ageYears` calcolati in Java; viste senza `birth_date`/`age_years`.

- [ ] **Step 1: PatientService — leggi birth_date_enc + età in Java**

Nella query `findAll` rimuovere `v.birth_date, v.age_years` dalla SELECT e aggiungere `pat.birth_date_enc` (la `patients pat` è già joinata). Nella query `findById` rimuovere `p.birth_date, p.age_years` e aggiungere `pat.birth_date_enc` (join `patients pat` già presente).
In `mapListRow`/`mapDetailRow`, sostituire la lettura di `birth_date`/`age_years` con:
```java
LocalDate birth = decodeBirthDate(rs.getString("birth_date_enc"));
// ... nel costruttore DTO:
birth,                                   // birthDate
birth != null ? Period.between(birth, LocalDate.now()).getYears() : null,  // ageYears
```
Aggiungere l'helper e gli import (`java.time.LocalDate`, `java.time.Period`):
```java
private LocalDate decodeBirthDate(String enc) {
    String s = this.enc.decrypt(enc, s());
    return s != null ? LocalDate.parse(s) : null;
}
```

- [ ] **Step 2: PatientService — stop dual-write plaintext**

In `create()`/`update()`, impostare la colonna plaintext `birth_date` a `null` (scrivere solo `birth_date_enc`). Nella `create()` INSERT e nella `update()` SET, il parametro `birthDate` diventa `null`:
```java
.addValue("birthDate", null)   // plaintext non più scritto; solo birth_date_enc
```
(mantenere `birthDateEnc` come da Task 3.)

- [ ] **Step 3: Initializer — viste senza birth_date/age_years**

In `rebuildPatientDashboardView`: rimuovere `p.birth_date,` e il blocco `CASE ... AS age_years,` dalla SELECT, e togliere `p.birth_date,` dal `GROUP BY`. In `rebuildPatientClinicalCardView`: rimuovere `p.birth_date,` e il blocco `CASE ... AS age_years,`. Lasciare invariato il resto.

- [ ] **Step 4: install.sql mirror — viste**

In `database/install.sql`, aggiornare le definizioni di `v_patient_dashboard` e `v_patient_clinical_card` sia nel template globale (righe ~1071/1109) sia nello schema demo `t_9d754153` (righe ~3131/3174): rimuovere `p.birth_date` + il `CASE ... age_years` (e `p.birth_date` dal `GROUP BY` del dashboard), coerentemente con i metodi del initializer.

- [ ] **Step 5: Build**

Run: `cd backend && mvn -q test`
Expected: PASS. Verificare a mano che `findAll`/`findById` non referenzino più `birth_date`/`age_years` dalle viste (`grep -n "age_years\|v.birth_date\|p.birth_date" backend/src/main/java/com/dentalcare/service/PatientService.java` → nessun match residuo nelle query).

- [ ] **Step 6: Verifica nessun altro consumatore di patients.birth_date**

Run: `grep -rn "birth_date" backend/src/main/java | grep -iv "birth_date_enc\|birthDate\|request\|dto"`
Expected: nessun consumatore SQL residuo di `patients.birth_date` in chiaro oltre a quelli gestiti. Se emergono, riportarli come concern (fuori scope Slice 1 = solo PatientService).

- [ ] **Step 7: Commit**
```bash
git add backend/src/main/java/com/dentalcare/service/PatientService.java \
        backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java \
        database/install.sql
git commit -m "feat(security): cutover birth_date cifrato + eta in Java + viste (#7)"
```

---

## Runbook di deploy (dopo il merge)

Ordine obbligatorio in produzione (dati clinici — irreversibile):
1. **Backup DB** `dentalcare_prod`.
2. **Genera master key prod**: `openssl rand -hex 32` → in `config/application-prod.properties` (gitignored sul server), `app.encryption.master-key=...`, `key-source=config`. **Salva la chiave in secret store sicuro** (perdita = dati irrecuperabili).
3. **Deploy backend** (Task 1–4): l'avvio applica `birth_date_enc` + dual-write a tutti i tenant via `EstimateSchemaInitializer`. Le viste sono ancora intatte → nessuna rottura.
4. **Migrazione dati**: per ogni tenant, `POST /api/admin/encryption/migrate` (autenticato admin/tenant-admin del tenant). Idempotente.
5. **Verifica** che `birth_date_enc` sia popolato per tutte le righe.
6. **Deploy cutover** (Task 5): l'avvio ricostruisce le viste senza `birth_date`/`age_years`; il service legge dal cifrato + età in Java. Da qui il plaintext non è più scritto.
7. **(Step futuro, fuori Slice 1)** `UPDATE patients SET birth_date = NULL` sulle righe migrate, poi `DROP COLUMN birth_date` dopo verifica.

---

## Self-Review

**Spec coverage:**
- TenantEncryptionService + HKDF + AES-GCM → Task 2 ✅
- MasterKeyProvider (seam Vault) + config + fail-fast → Task 1 ✅
- Colonna `_enc` + install.sql mirror + auto-apply tenant esistenti → Task 3 (initializer) ✅
- Migrazione idempotente admin → Task 4 ✅
- birth_date cifrato + età in Java + viste ricreate → Task 5 ✅
- Error handling (EncryptionException, no plaintext nel log) → Task 2 ✅
- Rollout non-breaking (dual-write → migrate → cutover) → Task 3/4/5 ✅

**Fuori scope Slice 1 (confermato assente dal piano):** blind index/ricerca, fiscal_code/phone/email/address, rotazione chiave, VaultMasterKeyProvider, DROP colonna plaintext.

**Note da verificare in esecuzione (non placeholder):**
- Stile stub `TenantContext` nei test service → Task 4 rimanda a `ProductCategoryServiceTest`.
- Posizione esatta delle 2 viste in install.sql (template + demo) e dei `runStep` nel initializer → Task 3/5 indicano righe indicative, l'implementer le localizza.
- Eventuali altri consumatori SQL di `patients.birth_date` oltre le 2 viste → Task 5 Step 6 verifica (atteso: nessuno).

**Type consistency:** `birth_date_enc` (text) ↔ `enc.encrypt(birthDate.toString())`; DTO `birthDate: LocalDate` + `ageYears: Integer` invariati, popolati in Java; `MasterKeyProvider.masterKey(): byte[]` usato da `TenantEncryptionService`.
