# P2 Implementation Plan (#12.C, #3, #14)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chiudere i gap CRUD/qualità dati (categorie magazzino, validazione codice fiscale + flag straniero) e portare il Copilot AI a contestuale + proattivo + cross-modulo.

**Architecture:** Backend Spring Boot multi-tenant (schema-per-tenant, `NamedParameterJdbcTemplate`, `TenantContext.validatedSchema()`); frontend Angular standalone + signals + Reactive Forms + Tailwind. SSE già presente (`AppointmentEventService`) riusato per la proattività. Prompt AI esternalizzati (`PromptService`), tool AI in `DentalCareAiTools`.

**Tech Stack:** Java 21, Spring Boot, Spring AI (OpenAI), PostgreSQL, Angular 21, TypeScript, Tailwind.

## Global Constraints

- Multi-tenant: ogni query filtra per `clinic_id` e usa `s()` = `TenantContext.validatedSchema()`. Mai fidarsi del tenant dal client.
- Comunicazione: mai esporre entity JPA; DTO record separati per request/response.
- Cancellazioni anagrafiche referenziate = **soft-delete** o blocco, mai hard-delete che rompe lo storico.
- `install.sql` deve rispecchiare il DB: ogni modifica schema → aggiorna heredoc `create_tenant` + schema demo `t_9d754153` + nuovo `patch_*.sql` idempotente che itera gli schemi tenant esistenti.
- Gating ruolo: gestione anagrafiche riservata ad admin; scritture AI cliniche solo ruoli medici (`MEDICAL_ROLES`), confirm-gated.
- Locale IT default; stringhe utente in italiano.
- Build verdi prima di chiudere: `cd backend && mvn -q -DskipTests=false test`, `cd frontend && npm run build`.
- Commit piccoli, messaggi in stile `feat(scope): ...` / `test(scope): ...`, con footer `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

## File Structure

**#12.C — Categorie prodotto**
- Modify `backend/.../controller/ProductController.java` — 3 endpoint CRUD categorie.
- Modify `backend/.../service/ProductService.java` — create/update/delete categoria + guardia referenza.
- Create `backend/.../dto/CreateProductCategoryRequest.java` — DTO request.
- Modify `frontend/.../core/models/product.model.ts` — request interface.
- Modify `frontend/.../core/services/product.service.ts` — 3 metodi.
- Modify `frontend/.../features/magazzino/magazzino.component.ts/.html` — UI gestione categorie.
- Create `backend/src/test/.../service/ProductCategoryServiceTest.java` — unit.

**#3 — Validazione CF + flag straniero**
- Modify `database/install.sql` (heredoc `create_tenant` + demo `t_9d754153.patients`); Create `database/patch_foreign_patient.sql`.
- Modify `backend/.../dto/CreatePatientRequest.java`, `UpdatePatientRequest.java` — `Boolean foreignPatient`.
- Create `backend/.../validation/ValidFiscalCode.java` + `FiscalCodeValidator.java` — validator classe.
- Modify `backend/.../service/PatientService.java` — persist `foreign_patient`; `PatientDetailDto` + mapper.
- Create `frontend/.../core/validators/fiscal-code.validator.ts`.
- Modify `frontend/.../features/pazienti/nuovo-paziente/*`, `paziente-detail/*`; `patient.service.ts` request.
- Create `backend/src/test/.../validation/FiscalCodeValidatorTest.java`.

**#14 — Copilot contestuale/proattivo/cross-modulo**
- 14.A: Modify `ChatRequest.java`, `ChatService.java`, `chat.service.ts`, `segretaria.component.ts` (+ context provider).
- 14.B: Create `CopilotSuggestionService.java` + SSE reuse; Modify `ChatController.java` (endpoint stream suggerimenti) o nuovo `CopilotController`; frontend `EventSource` badge.
- 14.C: Modify `DentalCareAiTools.java` — tool composti cross-modulo.

---

## PART 1 — #12.C Categorie prodotto magazzino

Tabella `product_categories(id, clinic_id, name)` già per-tenant; FK `fk_products_category ... ON DELETE SET NULL`. Oggi solo `GET /api/product-categories`. Aggiungere POST/PUT/DELETE. Nessun cambio schema.

### Task 1: Backend CRUD categorie prodotto

**Files:**
- Create: `backend/src/main/java/com/dentalcare/dto/CreateProductCategoryRequest.java`
- Modify: `backend/src/main/java/com/dentalcare/service/ProductService.java`
- Modify: `backend/src/main/java/com/dentalcare/controller/ProductController.java`
- Test: `backend/src/test/java/com/dentalcare/service/ProductCategoryServiceTest.java`

**Interfaces:**
- Consumes: `ProductCategoryDto(UUID categoryId, String name)`, `TenantContext`, `ResourceNotFoundException`.
- Produces: `ProductService.createCategory(CreateProductCategoryRequest) -> ProductCategoryDto`, `updateCategory(UUID, CreateProductCategoryRequest) -> ProductCategoryDto`, `deleteCategory(UUID) -> void`; endpoint `POST/PUT/DELETE /api/product-categories`.

- [ ] **Step 1: DTO request**

`CreateProductCategoryRequest.java`:
```java
package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateProductCategoryRequest(
        @NotBlank @Size(max = 100) String name
) {}
```

- [ ] **Step 2: Service — create/update/delete con guardia referenza**

In `ProductService.java`, aggiungere sotto `findCategories()`:
```java
@Transactional
public ProductCategoryDto createCategory(CreateProductCategoryRequest req) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    UUID id = UUID.randomUUID();
    jdbc.update("INSERT INTO " + s() + ".product_categories (id, clinic_id, name)"
                    + " VALUES (:id, :clinicId, :name)",
            new MapSqlParameterSource().addValue("id", id)
                    .addValue("clinicId", clinicId).addValue("name", req.name()));
    return new ProductCategoryDto(id, req.name());
}

@Transactional
public ProductCategoryDto updateCategory(UUID id, CreateProductCategoryRequest req) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    int rows = jdbc.update("UPDATE " + s() + ".product_categories SET name = :name"
                    + " WHERE id = :id AND clinic_id = :clinicId",
            new MapSqlParameterSource().addValue("id", id)
                    .addValue("clinicId", clinicId).addValue("name", req.name()));
    if (rows == 0) throw new ResourceNotFoundException("Product category not found: " + id);
    return new ProductCategoryDto(id, req.name());
}

@Transactional
public void deleteCategory(UUID id) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    Integer refs = jdbc.queryForObject(
            "SELECT COUNT(*) FROM " + s() + ".products"
                    + " WHERE category_id = :id AND clinic_id = :clinicId AND is_active = true",
            new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
            Integer.class);
    if (refs != null && refs > 0) {
        throw new IllegalStateException("Categoria referenziata da " + refs + " prodotti attivi");
    }
    int rows = jdbc.update("DELETE FROM " + s() + ".product_categories"
                    + " WHERE id = :id AND clinic_id = :clinicId",
            new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId));
    if (rows == 0) throw new ResourceNotFoundException("Product category not found: " + id);
}
```
Aggiungere import `com.dentalcare.dto.CreateProductCategoryRequest`.
Nota: `IllegalStateException` → verificare che `GlobalExceptionHandler` la mappi a 409; se non presente, gestirla nel controller (vedi Step 3 con try/catch → `HttpStatus.CONFLICT`). Controllare prima come vengono gestite le eccezioni di conflitto esistenti (`grep -rn "CONFLICT\|IllegalState" backend/src/main/java/com/dentalcare/exception/`).

- [ ] **Step 3: Controller — 3 endpoint**

In `ProductController.java`, sotto `findCategories()`:
```java
@PostMapping("/api/product-categories")
@ResponseStatus(HttpStatus.CREATED)
public ProductCategoryDto createCategory(@Valid @RequestBody CreateProductCategoryRequest request) {
    return productService.createCategory(request);
}

@PutMapping("/api/product-categories/{id}")
public ProductCategoryDto updateCategory(@PathVariable UUID id,
                                         @Valid @RequestBody CreateProductCategoryRequest request) {
    return productService.updateCategory(id, request);
}

@DeleteMapping("/api/product-categories/{id}")
@ResponseStatus(HttpStatus.NO_CONTENT)
public void deleteCategory(@PathVariable UUID id) {
    productService.deleteCategory(id);
}
```
Aggiungere import `com.dentalcare.dto.CreateProductCategoryRequest` e `jakarta.validation.Valid`.

- [ ] **Step 4: Unit test (Mockito su jdbc)**

`ProductCategoryServiceTest.java` — seguire lo stile dei test service esistenti (`backend/src/test/java/com/dentalcare/service/`). Verificare:
- `createCategory` esegue INSERT e ritorna DTO col nome.
- `deleteCategory` con `refs > 0` lancia `IllegalStateException`.
- `updateCategory`/`deleteCategory` con 0 righe lancia `ResourceNotFoundException`.

Mock: `NamedParameterJdbcTemplate`. Serve stub di `TenantContext` — verificare come gli altri test impostano il tenant (probabile `TenantContext.setCurrentClinicId(...)` in `@BeforeEach`). Ispezionare un test service esistente prima di scrivere.

Run: `cd backend && mvn -q -Dtest=ProductCategoryServiceTest test`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add backend/src/main/java/com/dentalcare/dto/CreateProductCategoryRequest.java \
        backend/src/main/java/com/dentalcare/service/ProductService.java \
        backend/src/main/java/com/dentalcare/controller/ProductController.java \
        backend/src/test/java/com/dentalcare/service/ProductCategoryServiceTest.java
git commit -m "feat(magazzino): CRUD categorie prodotto (#12.C backend)"
```

### Task 2: Frontend gestione categorie in Magazzino

**Files:**
- Modify: `frontend/src/app/core/models/product.model.ts`
- Modify: `frontend/src/app/core/services/product.service.ts`
- Modify: `frontend/src/app/features/magazzino/magazzino.component.ts`
- Modify: `frontend/src/app/features/magazzino/magazzino.component.html`

**Interfaces:**
- Consumes: `ProductCategory { categoryId, name }`, endpoint Task 1.
- Produces: UI CRUD categorie dentro `magazzino.component`.

- [ ] **Step 1: Model — request interface**

In `product.model.ts` aggiungere:
```typescript
export interface CreateProductCategoryRequest {
  name: string;
}
```

- [ ] **Step 2: Service — 3 metodi**

In `product.service.ts` aggiungere (import `CreateProductCategoryRequest`):
```typescript
createCategory(request: CreateProductCategoryRequest): Observable<ProductCategory> {
  return this.http.post<ProductCategory>(this.categoryBase, request);
}

updateCategory(id: string, request: CreateProductCategoryRequest): Observable<ProductCategory> {
  return this.http.put<ProductCategory>(`${this.categoryBase}/${id}`, request);
}

deleteCategory(id: string): Observable<void> {
  return this.http.delete<void>(`${this.categoryBase}/${id}`);
}
```

- [ ] **Step 3: Component — stato + metodi**

Leggere `magazzino.component.ts` (320 righe) per pattern signal/servizio esistente. Aggiungere:
- signal `categories` (già probabilmente caricato via `findCategories()` — riusare), `editingCategory: signal<ProductCategory | null>(null)`, `categoryName = signal('')`, `categoryError = signal<string | null>(null)`.
- metodi `saveCategory()` (branch create/update su `editingCategory()`), `startEditCategory(c)`, `cancelCategory()`, `deleteCategory(c)` con `confirm(...)` e gestione errore 409 → messaggio "Categoria in uso, riassegna i prodotti prima di eliminarla".
- dopo ogni mutazione ricaricare `findCategories()`.

- [ ] **Step 4: Template — sezione categorie**

In `magazzino.component.html` aggiungere pannello "Categorie" (Tailwind, coerente col resto): lista categorie con pulsanti matita/cestino, form nome + Salva/Aggiorna. Nessun file CSS: solo classi Tailwind inline.

- [ ] **Step 5: Build FE**

Run: `cd frontend && npm run build`
Expected: build verde, nessun errore TS.

- [ ] **Step 6: Commit**
```bash
git add frontend/src/app/core/models/product.model.ts \
        frontend/src/app/core/services/product.service.ts \
        frontend/src/app/features/magazzino/magazzino.component.ts \
        frontend/src/app/features/magazzino/magazzino.component.html
git commit -m "feat(magazzino): UI gestione categorie prodotto (#12.C frontend)"
```

---

## PART 2 — #3 Validazione CF + flag straniero

Regole: italiano → CF obbligatorio, regex, cross-check con `birthDate`. Straniero → checkbox `foreignPatient=true`, CF opzionale, nessuna validazione. Regex CF: `^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$` (dopo `toUpperCase()`).

### Task 3: DB — colonna foreign_patient

**Files:**
- Modify: `database/install.sql`
- Create: `database/patch_foreign_patient.sql`

- [ ] **Step 1: install.sql — heredoc create_tenant**

In `database/install.sql`, dentro `CREATE TABLE patients (...)` del heredoc `create_tenant` (~riga 749, dopo `active boolean DEFAULT true NOT NULL`), aggiungere:
```sql
    foreign_patient boolean DEFAULT false NOT NULL,
```

- [ ] **Step 2: install.sql — schema demo**

In `CREATE TABLE t_9d754153.patients (...)` (~riga 2718) aggiungere la stessa colonna nella posizione analoga.

- [ ] **Step 3: patch idempotente per tenant esistenti**

`database/patch_foreign_patient.sql`:
```sql
-- Aggiunge patients.foreign_patient a tutti gli schemi tenant esistenti. Idempotente.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schema_name FROM dentalcare.tenants LOOP
    EXECUTE format(
      'ALTER TABLE %I.patients ADD COLUMN IF NOT EXISTS foreign_patient boolean NOT NULL DEFAULT false',
      r.schema_name);
  END LOOP;
END $$;
```
Verificare nome tabella registry tenant (`grep -n "FROM dentalcare.tenants\|schema_name" database/install.sql | head`) e allineare la query.

- [ ] **Step 4: Commit**
```bash
git add database/install.sql database/patch_foreign_patient.sql
git commit -m "feat(db): colonna patients.foreign_patient + patch tenant (#3)"
```

### Task 4: Backend — DTO, validator, persist

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/dto/CreatePatientRequest.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/UpdatePatientRequest.java`
- Create: `backend/src/main/java/com/dentalcare/validation/ValidFiscalCode.java`
- Create: `backend/src/main/java/com/dentalcare/validation/FiscalCodeValidator.java`
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/PatientDetailDto.java`
- Test: `backend/src/test/java/com/dentalcare/validation/FiscalCodeValidatorTest.java`

**Interfaces:**
- Consumes: `CreatePatientRequest`, `UpdatePatientRequest` (record con `fiscalCode`, `birthDate`, nuovo `foreignPatient`).
- Produces: annotation `@ValidFiscalCode` a livello classe; colonna `foreign_patient` persistita; `PatientDetailDto.foreignPatient`.

- [ ] **Step 1: Test validator (TDD prima)**

`FiscalCodeValidatorTest.java`:
```java
package com.dentalcare.validation;

import com.dentalcare.dto.CreatePatientRequest;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import static org.junit.jupiter.api.Assertions.*;

class FiscalCodeValidatorTest {

    private final FiscalCodeValidator validator = new FiscalCodeValidator();

    private CreatePatientRequest req(String cf, LocalDate birth, Boolean foreign) {
        return new CreatePatientRequest("Mario", "Rossi", cf, birth,
                null, null, null, null, null, null, null, null, foreign);
    }

    @Test
    void foreignPatientSkipsAllValidation() {
        assertTrue(validator.isValid(req("XYZ", LocalDate.of(1980,1,1), true), null));
        assertTrue(validator.isValid(req(null, null, true), null));
    }

    @Test
    void italianRequiresFiscalCode() {
        assertFalse(validator.isValid(req(null, LocalDate.of(1980,1,1), false), null));
        assertFalse(validator.isValid(req("  ", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void invalidFormatRejected() {
        assertFalse(validator.isValid(req("NOTAVALIDCF1234", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void validFormatWithMatchingDateAccepted() {
        // RSSMRA80A01H501U → uomo, 1980, gennaio(A), giorno 01
        assertTrue(validator.isValid(req("RSSMRA80A01H501U", LocalDate.of(1980,1,1), false), null));
    }

    @Test
    void dateMismatchRejected() {
        // CF dice 1980-01-01, birthDate 1990 → mismatch
        assertFalse(validator.isValid(req("RSSMRA80A01H501U", LocalDate.of(1990,1,1), false), null));
    }

    @Test
    void nullForeignTreatedAsItalian() {
        assertFalse(validator.isValid(req(null, LocalDate.of(1980,1,1), null), null));
    }
}
```

- [ ] **Step 2: Run test — deve fallire (classi assenti)**

Run: `cd backend && mvn -q -Dtest=FiscalCodeValidatorTest test`
Expected: FAIL compilazione (`ValidFiscalCode`/`FiscalCodeValidator` non esistono, `CreatePatientRequest` senza 13° campo).

- [ ] **Step 3: DTO — aggiungere foreignPatient + annotation**

`CreatePatientRequest.java` — aggiungere `Boolean foreignPatient` come ultimo componente e annotare la classe con `@ValidFiscalCode`:
```java
package com.dentalcare.dto;

import com.dentalcare.validation.ValidFiscalCode;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;

@ValidFiscalCode
public record CreatePatientRequest(
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        @Size(max = 16) String fiscalCode,
        LocalDate birthDate,
        @Size(max = 20) String phone,
        @Email @Size(max = 160) String email,
        @Size(max = 200) String addressLine1,
        @Size(max = 100) String city,
        @Size(max = 10) String province,
        @Size(max = 10) String postalCode,
        String notes,
        UUID primaryProviderId,
        Boolean foreignPatient
) {}
```
Idem `UpdatePatientRequest.java`: aggiungere `Boolean foreignPatient` come ultimo campo e `@ValidFiscalCode` sulla classe (mantenere i `@Size` esistenti).

⚠️ Aggiungere il campo cambia l'ordine del costruttore: aggiornare ogni `new CreatePatientRequest(...)` / `new UpdatePatientRequest(...)` nel codice e nei test (`grep -rn "new CreatePatientRequest\|new UpdatePatientRequest" backend/src`).

- [ ] **Step 4: Annotation**

`ValidFiscalCode.java`:
```java
package com.dentalcare.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import java.lang.annotation.*;

@Documented
@Constraint(validatedBy = FiscalCodeValidator.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ValidFiscalCode {
    String message() default "Codice fiscale non valido o non coerente con la data di nascita";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

- [ ] **Step 5: Validator**

`FiscalCodeValidator.java` — accetta entrambi i request via interfaccia minima. Poiché sono record distinti, il validator riceve `Object` e usa un piccolo adattatore. Implementazione:
```java
package com.dentalcare.validation;

import com.dentalcare.dto.CreatePatientRequest;
import com.dentalcare.dto.UpdatePatientRequest;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.time.LocalDate;
import java.util.regex.Pattern;

public class FiscalCodeValidator implements ConstraintValidator<ValidFiscalCode, Object> {

    private static final Pattern CF = Pattern.compile(
            "^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$");
    // Lettera mese CF → mese calendario
    private static final String MONTH_LETTERS = "ABCDEHLMPRST"; // Gen..Dic

    public boolean isValid(CreatePatientRequest r, ConstraintValidatorContext ctx) {
        return check(r.foreignPatient(), r.fiscalCode(), r.birthDate());
    }
    public boolean isValid(UpdatePatientRequest r, ConstraintValidatorContext ctx) {
        return check(r.foreignPatient(), r.fiscalCode(), r.birthDate());
    }

    @Override
    public boolean isValid(Object value, ConstraintValidatorContext ctx) {
        if (value instanceof CreatePatientRequest c) return isValid(c, ctx);
        if (value instanceof UpdatePatientRequest u) return isValid(u, ctx);
        return true;
    }

    private boolean check(Boolean foreign, String fiscalCode, LocalDate birthDate) {
        if (Boolean.TRUE.equals(foreign)) return true;          // straniero: skip
        if (fiscalCode == null || fiscalCode.isBlank()) return false; // italiano: obbligatorio
        String cf = fiscalCode.trim().toUpperCase();
        if (!CF.matcher(cf).matches()) return false;
        if (birthDate == null) return true;                     // formato ok, niente cross-check
        return matchesBirthDate(cf, birthDate);
    }

    private boolean matchesBirthDate(String cf, LocalDate birth) {
        int cfYear2 = Integer.parseInt(cf.substring(6, 8));
        char monthLetter = cf.charAt(8);
        int cfDay = Integer.parseInt(cf.substring(9, 11));
        int month = MONTH_LETTERS.indexOf(monthLetter) + 1;     // 1..12
        if (cfDay > 40) cfDay -= 40;                            // femmine +40
        if (month != birth.getMonthValue()) return false;
        if (cfDay != birth.getDayOfMonth()) return false;
        return cfYear2 == (birth.getYear() % 100);
    }
}
```

- [ ] **Step 6: Run test — deve passare**

Run: `cd backend && mvn -q -Dtest=FiscalCodeValidatorTest test`
Expected: PASS (6 test verdi).

- [ ] **Step 7: PatientService — persist foreign_patient**

In `create()`: aggiungere `foreign_patient` a colonne INSERT e VALUES `:foreignPatient`, e param:
```java
.addValue("foreignPatient", request.foreignPatient() != null && request.foreignPatient())
```
In `update()`: aggiungere `foreign_patient = :foreignPatient` al SET e lo stesso param.

- [ ] **Step 8: PatientDetailDto + mapper**

Aggiungere `Boolean foreignPatient` a `PatientDetailDto`. Nel `mapDetailRow` di `PatientService`, leggere `rs.getBoolean("foreign_patient")` e includere `pat.foreign_patient` nella SELECT `findById` (dalla join `%s.patients pat`). Aggiornare l'ordine dei parametri del costruttore DTO.

- [ ] **Step 9: Build + test backend**

Run: `cd backend && mvn -q test`
Expected: PASS.

- [ ] **Step 10: Commit**
```bash
git add backend/src/main/java/com/dentalcare/dto/CreatePatientRequest.java \
        backend/src/main/java/com/dentalcare/dto/UpdatePatientRequest.java \
        backend/src/main/java/com/dentalcare/validation/ \
        backend/src/main/java/com/dentalcare/service/PatientService.java \
        backend/src/main/java/com/dentalcare/dto/PatientDetailDto.java \
        backend/src/test/java/com/dentalcare/validation/FiscalCodeValidatorTest.java
git commit -m "feat(pazienti): validazione CF + flag straniero (#3 backend)"
```

### Task 5: Frontend — checkbox straniero + validator dinamico

**Files:**
- Create: `frontend/src/app/core/validators/fiscal-code.validator.ts`
- Modify: `frontend/src/app/core/services/patient.service.ts` (request interfaces)
- Modify: `frontend/src/app/core/models/patient.model.ts` (`PatientDetail.foreignPatient`)
- Modify: `frontend/src/app/features/pazienti/nuovo-paziente/nuovo-paziente.component.ts/.html`
- Modify: `frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.ts/.html`

**Interfaces:**
- Consumes: DTO backend con `foreignPatient`.
- Produces: checkbox `pazienteStraniero`, validator `fiscalCodeValidator`.

- [ ] **Step 1: Validator function**

`fiscal-code.validator.ts`:
```typescript
import { AbstractControl, ValidationErrors, ValidatorFn } from '@angular/forms';

const CF_RE = /^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$/;
const MONTHS = 'ABCDEHLMPRST';

/**
 * Valida il CF italiano sul FormGroup paziente. Skip se pazienteStraniero=true o CF vuoto.
 * Controlli: formato regex + cross-check mese/giorno/anno con dataNascita.
 */
export const fiscalCodeValidator: ValidatorFn = (group: AbstractControl): ValidationErrors | null => {
  const foreign = group.get('pazienteStraniero')?.value === true;
  if (foreign) return null;

  const cfCtrl = group.get('cf');
  const raw = (cfCtrl?.value ?? '').toString().trim().toUpperCase();
  if (!raw) return null; // 'required' gestito a parte

  if (!CF_RE.test(raw)) return { fiscalCodeFormat: true };

  const birth = group.get('dataNascita')?.value;
  if (!birth) return null;
  const d = new Date(birth);

  const cfYear2 = parseInt(raw.substring(6, 8), 10);
  const month = MONTHS.indexOf(raw.charAt(8)) + 1;
  let day = parseInt(raw.substring(9, 11), 10);
  if (day > 40) day -= 40;

  if (month !== d.getMonth() + 1 || day !== d.getDate() || cfYear2 !== d.getFullYear() % 100) {
    return { fiscalCodeDateMismatch: true };
  }
  return null;
};
```

- [ ] **Step 2: Request interfaces + model**

In `patient.service.ts` aggiungere `foreignPatient?: boolean;` a `CreatePatientRequest` e `UpdatePatientRequest`. In `patient.model.ts` aggiungere `foreignPatient?: boolean | null;` a `PatientDetail`.

- [ ] **Step 3: nuovo-paziente.component.ts — checkbox + validator gruppo**

Aggiungere control `pazienteStraniero: [false]` al `fb.group`; passare `{ validators: fiscalCodeValidator }` come 2° arg del group. Rendere `cf` `required` condizionale: metodo che, su `pazienteStraniero` valueChanges, imposta/rimuove `Validators.required` su `cf` e chiama `updateValueAndValidity()`. In `save()` includere `foreignPatient: v.pazienteStraniero`.

```typescript
this.form = this.fb.group({
  // ...campi esistenti invariati...
  cf: ['', [Validators.required, Validators.minLength(16), Validators.maxLength(16)]],
  // ...
  pazienteStraniero: [false],
}, { validators: fiscalCodeValidator });

// in ngOnInit
this.form.get('pazienteStraniero')!.valueChanges.subscribe((foreign: boolean) => {
  const cf = this.form.get('cf')!;
  cf.setValidators(foreign ? [Validators.maxLength(16)]
                           : [Validators.required, Validators.minLength(16), Validators.maxLength(16)]);
  cf.updateValueAndValidity();
});
```
In `save()`: `foreignPatient: v.pazienteStraniero,` nel payload `create(...)`.

- [ ] **Step 4: nuovo-paziente.component.html — checkbox + messaggi**

Aggiungere nel form (step Dati Anagrafici) checkbox `pazienteStraniero` con label "Paziente straniero (senza CF italiano)". Quando attivo, label campo CF → "Documento identità (opzionale)". Mostrare errori:
- `form.hasError('fiscalCodeFormat')` → "Codice fiscale non valido — controlla il formato"
- `form.hasError('fiscalCodeDateMismatch')` → "La data nel codice fiscale non corrisponde alla data di nascita"

- [ ] **Step 5: paziente-detail — stesse modifiche in modifica paziente**

Leggere `paziente-detail.component.ts` (486 righe) per capire il form di modifica. Replicare: control `pazienteStraniero` (inizializzato da `detail.foreignPatient`), validator gruppo, `required` dinamico, `foreignPatient` nel payload `update(...)`, checkbox + messaggi nel template.

- [ ] **Step 6: Build FE**

Run: `cd frontend && npm run build`
Expected: build verde.

- [ ] **Step 7: Commit**
```bash
git add frontend/src/app/core/validators/fiscal-code.validator.ts \
        frontend/src/app/core/services/patient.service.ts \
        frontend/src/app/core/models/patient.model.ts \
        frontend/src/app/features/pazienti/nuovo-paziente/ \
        frontend/src/app/features/pazienti/paziente-detail/
git commit -m "feat(pazienti): checkbox straniero + validazione CF client (#3 frontend)"
```

---

## PART 3 — #14 Copilot contestuale, proattivo, cross-modulo

### Task 6: 14.A — Contesto UI nel prompt

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/dto/ChatRequest.java`
- Modify: `backend/src/main/java/com/dentalcare/service/ChatService.java`
- Modify: `frontend/src/app/core/services/chat.service.ts`
- Modify: `frontend/src/app/features/segretaria/segretaria.component.ts`

**Interfaces:**
- Consumes: `ChatRequest`, `ChatService.buildSystemPrompt`, `promptService.render`.
- Produces: `ChatRequest` con `ChatContext context`; contesto iniettato nel system prompt.

- [ ] **Step 1: ChatRequest — campo context**

Creare `ChatContext` inline o record dedicato. `ChatRequest.java`:
```java
package com.dentalcare.dto;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;

public record ChatRequest(@NotBlank String message, List<ChatTurnDto> history,
                          UUID sessionId, String locale, ChatContext context) {
    public record ChatContext(UUID patientId, String patientName, String view) {}
}
```

- [ ] **Step 2: ChatService — appendere contesto al system prompt**

In `chat(...)` passare il contesto; in `buildSystemPrompt` aggiungere una coda quando presente:
```java
public ChatResponse chat(ChatRequest request) {
    String response = chatClient.prompt()
            .options(OpenAiChatOptions.builder().model(model).build())
            .system(buildSystemPrompt(request.locale(), request.context()))
            // ...invariato...
}

private String buildSystemPrompt(String requestLocale, ChatRequest.ChatContext ctx) {
    // ...render invariato in 'rendered'...
    String base = rendered != null ? rendered : SYSTEM_PROMPT_FALLBACK;
    if (ctx == null) return base;
    StringBuilder sb = new StringBuilder(base);
    if (ctx.patientId() != null) {
        sb.append("\n\n[CONTESTO UI] L'utente sta guardando il paziente ")
          .append(ctx.patientName() != null ? ctx.patientName() : "")
          .append(" (patientId=").append(ctx.patientId())
          .append("). Quando dice \"questo paziente\" usa questo UUID senza ricerca.");
    }
    if (ctx.view() != null && !ctx.view().isBlank()) {
        sb.append("\n[CONTESTO UI] Vista corrente: ").append(ctx.view()).append(".");
    }
    return sb.toString();
}
```
Nota: aggiornare la firma di `buildSystemPrompt` (ora 2 arg). Il metodo stream in `ChatController` passa già `request` intero a `chatService.chat(request)` → nessuna modifica controller.

- [ ] **Step 3: Frontend — chat.service invia context**

In `chat.service.ts` estendere `ChatRequest` interface e i due body (`send`, `sendStream`) con `context?: { patientId?: string; patientName?: string; view?: string }`. Firme:
```typescript
send(message: string, history: ChatTurn[], sessionId?: string | null,
     context?: ChatUiContext): Observable<ChatResponse> {
  return this.http.post<ChatResponse>(this.baseUrl,
    { message, history, sessionId: sessionId ?? null, context: context ?? null });
}
```
Aggiungere `export interface ChatUiContext { patientId?: string; patientName?: string; view?: string; }` e replicare nel `body` di `sendStream`.

- [ ] **Step 4: segretaria.component — passare contesto**

Leggere `segretaria.component.ts` (198 righe). Determinare la vista/paziente correnti: opzione semplice — un `CopilotContextService` (signal) che i componenti paziente aggiornano, letto qui. Per lo scope 14.A minimo: passare `view` dalla route corrente (`Router.url`) e `patientId` se l'utente è su una pagina paziente. Iniettare nel `send`/`sendStream`. Se serve stato condiviso, creare `frontend/src/app/core/services/copilot-context.service.ts` con `patientId`/`patientName`/`view` signals; `paziente-detail` lo setta in `ngOnInit`/`ngOnDestroy`.

- [ ] **Step 5: Build BE + FE**

Run: `cd backend && mvn -q test` → PASS
Run: `cd frontend && npm run build` → verde

- [ ] **Step 6: Commit**
```bash
git add backend/src/main/java/com/dentalcare/dto/ChatRequest.java \
        backend/src/main/java/com/dentalcare/service/ChatService.java \
        frontend/src/app/core/services/chat.service.ts \
        frontend/src/app/features/segretaria/ \
        frontend/src/app/core/services/copilot-context.service.ts
git commit -m "feat(copilot): contesto UI nel prompt (#14.A)"
```

### Task 7: 14.C — Tool cross-modulo

Fatto prima di 14.B perché indipendente dalla SSE e a più alto valore. Aggiungere tool composti in `DentalCareAiTools` che orchestrano service già iniettati (`estimateService`, `treatmentPlanService`, `odontogramService`, `recallService`).

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/DentalCareAiTools.java`

**Interfaces:**
- Consumes: service esistenti già iniettati; pattern `@Tool`/`@ToolParam`, `isMedical()`, confirm-gate `pendingActions`.
- Produces: tool `generateEstimateFromOdontogram`, `prepareMonthlyRecalls` (preview + confirmAction).

- [ ] **Step 1: Ispezionare API dei service target**

`grep -n "public " backend/src/main/java/com/dentalcare/service/EstimateService.java backend/src/main/java/com/dentalcare/service/OdontogramService.java backend/src/main/java/com/dentalcare/service/RecallService.java` per firme reali. Verificare come i tool di scrittura esistenti (#13) usano `pendingActions` per il confirm-gate (leggere un `@Tool` di scrittura in `DentalCareAiTools`, es. `createAppointment` + `confirmAction`).

- [ ] **Step 2: Tool "genera preventivo da carie odontogramma"**

Aggiungere `@Tool` che: legge le condizioni dall'odontogramma del paziente (`odontogramService`), mappa condizione→prestazione (via `serviceCatalogService`/`condition_service_defaults`), costruisce una PREVIEW testuale + codice conferma tramite `pendingActions` (stesso pattern di `createAppointment`). Solo `isMedical()` o admin secondo gating #13. Nessuna scrittura diretta: la conferma passa da `confirmAction`.

- [ ] **Step 3: Tool "prepara richiami del mese"**

`@Tool` che elenca i richiami dovuti nel mese corrente (via `recallService`) e propone la generazione batch confirm-gated.

- [ ] **Step 4: Build BE**

Run: `cd backend && mvn -q test`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add backend/src/main/java/com/dentalcare/service/DentalCareAiTools.java
git commit -m "feat(copilot): tool cross-modulo preventivo-da-odontogramma e richiami mese (#14.C)"
```

### Task 8: 14.B — Proattività push (SSE)

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/CopilotSuggestionService.java`
- Create: `backend/src/main/java/com/dentalcare/controller/CopilotController.java`
- Modify: `frontend/src/app/features/segretaria/segretaria.component.ts` (+ badge suggerimenti)

**Interfaces:**
- Consumes: pattern `AppointmentEventService` (SseEmitter registry per clinicId), `TenantContext`.
- Produces: endpoint `GET /api/copilot/suggestions/stream` (SSE) + `CopilotSuggestionService.publish(clinicId, suggestion)`.

- [ ] **Step 1: Suggestion registry+publish (clone del pattern SSE agenda)**

`CopilotSuggestionService.java` — copia strutturale di `AppointmentEventService` (registry `ConcurrentHashMap<UUID, Set<SseEmitter>>`, `subscribe`, `publish`, `removeEmitter`), evento nominato `suggestion`, payload JSON `{type,message,...}`. Il messaggio **propone**, non esegue.

- [ ] **Step 2: Controller stream**

`CopilotController.java`:
```java
@GetMapping(value = "/api/copilot/suggestions/stream",
            produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public SseEmitter stream() {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    return suggestionService.subscribe(clinicId);
}
```
Auth via `?token=` come lo stream agenda (già supportato da `JwtAuthenticationFilter`).

- [ ] **Step 3: Trigger sorgente suggerimenti**

Job schedulato (`@Scheduled`) o hook su eventi esistenti che chiama `suggestionService.publish(clinicId, ...)` per: richiami scaduti, preventivi fermi da N giorni. Scope minimo: uno `@Scheduled` giornaliero che interroga i richiami `da_contattare` scaduti e pubblica un suggerimento per clinic. Verificare che `@EnableScheduling` sia attivo (`grep -rn "EnableScheduling" backend/src/main`); se assente, aggiungerlo sulla classe application.

- [ ] **Step 4: Frontend — EventSource badge**

In `segretaria.component.ts` aprire `EventSource` su `/api/copilot/suggestions/stream?token=<jwt>` (pattern identico ad agenda `agenda.component.ts`); accumulare suggerimenti in un signal, mostrarli come badge/cards; click → precompila il messaggio chat. Chiudere l'`EventSource` in `ngOnDestroy`.

- [ ] **Step 5: Build BE + FE**

Run: `cd backend && mvn -q test` → PASS
Run: `cd frontend && npm run build` → verde

- [ ] **Step 6: Commit**
```bash
git add backend/src/main/java/com/dentalcare/service/CopilotSuggestionService.java \
        backend/src/main/java/com/dentalcare/controller/CopilotController.java \
        frontend/src/app/features/segretaria/
git commit -m "feat(copilot): suggerimenti proattivi push via SSE (#14.B)"
```

---

## Deploy (a fine P2)

Prod (`192.168.0.72` o cloud): `git pull` → applicare `database/patch_foreign_patient.sql` (nuovo) → `bash install.sh --update` o rebuild container (`docker compose up -d --build backend frontend`). Le tabelle categorie prodotto e SSE non richiedono patch DB. Aggiornare `directives/proposte-modifiche.md`: stato #12.C/#3/#14 → Fatto.

---

## Self-Review

**Spec coverage:**
- #12.C: Task 1 (BE CRUD + guardia referenza), Task 2 (UI) ✅
- #3: Task 3 (DB colonna+patch), Task 4 (validator BE + persist + DTO), Task 5 (checkbox+validator FE) ✅ — regex, cross-check data, flag straniero, install.sql mirror tutti coperti
- #14.A: Task 6 (contesto UI→prompt) ✅
- #14.B: Task 8 (SSE push proattivo) ✅
- #14.C: Task 7 (tool cross-modulo) ✅

**Note aperte da verificare in esecuzione (non placeholder — richiedono lettura file durante il task):**
- Ordine parametri costruttore DTO paziente dopo l'aggiunta di `foreignPatient` → aggiornare tutti i call-site (Step 3 Task 4 lo segnala).
- Stile esatto dei test service esistenti (setup TenantContext) → Task 1/4 rimandano all'ispezione.
- Firme reali di `EstimateService`/`OdontogramService`/`RecallService` → Task 7 Step 1 le ispeziona prima di scrivere.
- `@EnableScheduling` presenza → Task 8 Step 3.
- Mapping eccezione conflitto 409 → Task 1 Step 2.

**Type consistency:** `foreignPatient` (Boolean BE / boolean? FE), `ChatContext(patientId, patientName, view)` coerente tra Task 6 BE e FE. `ProductCategory.categoryId` usato coerente. `CreateProductCategoryRequest { name }` BE record ↔ FE interface.
