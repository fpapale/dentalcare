# Patient Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere la cancellazione fisica di pazienti "puri anagrafici" — nessun appuntamento, nessun documento clinico, nessuna fattura, nessun piano di cura associato.

**Architecture:** Backend espone `DELETE /api/patients/{id}` con guard esplicito su tutte le tabelle FK; restituisce `409` se il paziente non è eliminabile. Frontend mostra il pulsante cestino solo per pazienti con zero appuntamenti e zero piani di cura; la conferma avviene tramite `confirm()` nativo prima della chiamata HTTP.

**Tech Stack:** Spring Boot / NamedParameterJdbcTemplate, Java records, Angular 17+ signals, Tailwind CSS, RxJS.

## Global Constraints

- Nessuna entity JPA esposta nelle API; tutto via JDBC diretto (`NamedParameterJdbcTemplate`) come da pattern esistente in `PatientService`
- Schema tenant dinamico via `TenantContext.validatedSchema()` — ogni query usa `s()` per il prefisso schema
- Frontend: nessun file `.css` separato — solo classi Tailwind inline
- Nessun messaggio toast da creare: usare `alert()`/`confirm()` browser per semplicità
- Rispettare le convenzioni di naming esistenti: `patientId` (frontend), `id` (backend path variable)
- Il controllo definitivo di eliminabilità vive **solo nel backend** — il frontend filtra l'UI ma non è autoritativo

---

## Tabelle FK da controllare prima del DELETE

Le seguenti tabelle referenziano `patients(id, clinic_id)`. Se anche una sola ha righe per il paziente, il delete è bloccato:

| Tabella | FK constraint |
|---|---|
| `appointments` | ON DELETE CASCADE |
| `estimates` | ON DELETE CASCADE |
| `invoices` | ON DELETE RESTRICT ← bloccante a DB |
| `treatment_plans` | ON DELETE CASCADE |
| `clinical_history_entries` | ON DELETE CASCADE |
| `recalls` | ON DELETE CASCADE |
| `patient_documents` | ON DELETE CASCADE |
| `patient_prescriptions` | ON DELETE CASCADE |
| `patient_anamnesis` | ON DELETE CASCADE |
| `patient_diagnoses` | ON DELETE CASCADE |
| `odontogram_teeth` | ON DELETE CASCADE |

---

## File Map

| File | Operazione | Responsabilità |
|---|---|---|
| `backend/src/main/java/com/dentalcare/exception/PatientNotDeletableException.java` | **CREATE** | Eccezione 409 quando paziente ha dati associati |
| `backend/src/main/java/com/dentalcare/service/PatientService.java` | **MODIFY** | Metodo `delete(UUID id)` con guard su tutte le FK |
| `backend/src/main/java/com/dentalcare/controller/PatientController.java` | **MODIFY** | `DELETE /api/patients/{id}` → 204 o 409 |
| `backend/src/main/java/com/dentalcare/exception/GlobalExceptionHandler.java` | **MODIFY** | Handler per `PatientNotDeletableException` → 409 |
| `frontend/src/app/core/services/patient.service.ts` | **MODIFY** | Aggiunta metodo `delete(id: string): Observable<void>` |
| `frontend/src/app/features/pazienti/pazienti.component.ts` | **MODIFY** | Logica `deletePatient(p)` con confirm + errore |
| `frontend/src/app/features/pazienti/pazienti.component.html` | **MODIFY** | Pulsante cestino condizionale per riga paziente |

---

## Task 1: Backend — Eccezione + Service delete + Controller + Handler

**Files:**
- Create: `backend/src/main/java/com/dentalcare/exception/PatientNotDeletableException.java`
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java`
- Modify: `backend/src/main/java/com/dentalcare/controller/PatientController.java`
- Modify: `backend/src/main/java/com/dentalcare/exception/GlobalExceptionHandler.java`

**Interfaces:**
- Produces: `DELETE /api/patients/{id}` → `204 No Content` se ok, `409 Conflict` se paziente ha dati associati, `404` se non trovato

- [ ] **Step 1: Creare `PatientNotDeletableException`**

```java
// backend/src/main/java/com/dentalcare/exception/PatientNotDeletableException.java
package com.dentalcare.exception;

public class PatientNotDeletableException extends RuntimeException {
    public PatientNotDeletableException(String message) {
        super(message);
    }
}
```

- [ ] **Step 2: Aggiungere handler in `GlobalExceptionHandler`**

Aprire `backend/src/main/java/com/dentalcare/exception/GlobalExceptionHandler.java` e aggiungere prima della fine della classe:

```java
@ExceptionHandler(PatientNotDeletableException.class)
@ResponseStatus(HttpStatus.CONFLICT)
public ErrorResponse handlePatientNotDeletable(PatientNotDeletableException ex) {
    return new ErrorResponse("PATIENT_NOT_DELETABLE", ex.getMessage());
}
```

Verificare che `ErrorResponse` sia già importato/usato nel file — se sì, nessun import aggiuntivo serve.

- [ ] **Step 3: Aggiungere metodo `delete` in `PatientService`**

Aprire `backend/src/main/java/com/dentalcare/service/PatientService.java`.

Aggiungere il metodo **prima** dell'eventuale metodo `mapListRow`:

```java
public void delete(UUID patientId) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    String schema = s();

    // Verifica che il paziente esista
    String existsSql = "SELECT COUNT(*) FROM " + schema + ".patients WHERE id = :id AND clinic_id = :clinicId";
    MapSqlParameterSource existsParams = new MapSqlParameterSource()
            .addValue("id", patientId)
            .addValue("clinicId", clinicId);
    Integer count = jdbc.queryForObject(existsSql, existsParams, Integer.class);
    if (count == null || count == 0) {
        throw new ResourceNotFoundException("Patient not found: " + patientId);
    }

    // Tabelle da controllare: se una ha righe, blocca
    String[] tables = {
        "appointments", "estimates", "invoices", "treatment_plans",
        "clinical_history_entries", "recalls", "patient_documents",
        "patient_prescriptions", "patient_anamnesis", "patient_diagnoses",
        "odontogram_teeth"
    };
    for (String table : tables) {
        String checkSql = "SELECT COUNT(*) FROM " + schema + "." + table
                + " WHERE patient_id = :id AND clinic_id = :clinicId";
        Integer n = jdbc.queryForObject(checkSql, existsParams, Integer.class);
        if (n != null && n > 0) {
            throw new PatientNotDeletableException(
                "Il paziente ha dati associati (" + table + ") e non può essere eliminato");
        }
    }

    // Elimina
    String deleteSql = "DELETE FROM " + schema + ".patients WHERE id = :id AND clinic_id = :clinicId";
    jdbc.update(deleteSql, existsParams);
}
```

Aggiungere l'import mancante in cima al file (se non già presente):

```java
import com.dentalcare.exception.PatientNotDeletableException;
```

(`ResourceNotFoundException` dovrebbe già essere importato — verificare.)

- [ ] **Step 4: Aggiungere endpoint DELETE in `PatientController`**

Aprire `backend/src/main/java/com/dentalcare/controller/PatientController.java`.

Aggiungere dopo il metodo `create`:

```java
@DeleteMapping("/{id}")
@ResponseStatus(HttpStatus.NO_CONTENT)
public void delete(@PathVariable UUID id) {
    patientService.delete(id);
}
```

- [ ] **Step 5: Compilare e verificare che non ci siano errori**

```bash
cd backend
./mvnw compile -q
```

Atteso: nessun errore di compilazione.

- [ ] **Step 6: Test manuale endpoint**

Avviare il backend in locale (`./mvnw spring-boot:run`), poi:

```bash
# Paziente senza dati → deve rispondere 204
curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/patients/<id-paziente-pulito>

# Paziente con appuntamenti → deve rispondere 409
curl -s -X DELETE \
  -H "Authorization: Bearer <token>" \
  http://localhost:8080/api/patients/<id-paziente-con-appuntamenti>
# Atteso: {"code":"PATIENT_NOT_DELETABLE","message":"..."}
```

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/dentalcare/exception/PatientNotDeletableException.java \
        backend/src/main/java/com/dentalcare/service/PatientService.java \
        backend/src/main/java/com/dentalcare/controller/PatientController.java \
        backend/src/main/java/com/dentalcare/exception/GlobalExceptionHandler.java
git commit -m "feat(patients): aggiungi DELETE endpoint con guard su dati associati"
```

---

## Task 2: Frontend — Service method + UI pulsante cestino

**Files:**
- Modify: `frontend/src/app/core/services/patient.service.ts`
- Modify: `frontend/src/app/features/pazienti/pazienti.component.ts`
- Modify: `frontend/src/app/features/pazienti/pazienti.component.html`

**Interfaces:**
- Consumes: `DELETE /api/patients/{id}` (da Task 1)
- Produces: pulsante cestino visibile per `totalAppointments === 0 && treatmentPlansCount === 0`, ricarica lista dopo delete

**Prerequisito:** leggere i file prima di modificarli per capire la struttura attuale di template e componente.

- [ ] **Step 1: Aggiungere `delete` in `patient.service.ts`**

Aprire `frontend/src/app/core/services/patient.service.ts`.

Aggiungere in fondo alla classe `PatientService`, dopo `updatePhoto`:

```typescript
delete(id: string): Observable<void> {
  return this.http.delete<void>(`${this.base}/${id}`);
}
```

- [ ] **Step 2: Aggiungere `deletePatient` in `pazienti.component.ts`**

Aprire `frontend/src/app/features/pazienti/pazienti.component.ts`.

Verificare che `PatientService` sia già iniettato (lo è). Aggiungere il metodo nella classe:

```typescript
deletePatient(p: PatientListItem): void {
  if (!confirm(`Eliminare definitivamente ${p.patientFullName}? L'operazione è irreversibile.`)) {
    return;
  }
  this.patientService.delete(p.patientId).subscribe({
    next: () => this.loadPatients(),   // ricarica lista — adattare al nome del metodo esistente
    error: (err) => {
      const msg = err.error?.message ?? 'Impossibile eliminare il paziente.';
      alert(msg);
    }
  });
}
```

**IMPORTANTE:** verificare il nome del metodo che carica i pazienti (probabile `loadPatients()` o equivalente) — adattarlo se diverso.

- [ ] **Step 3: Aggiungere pulsante cestino nel template**

Aprire `frontend/src/app/features/pazienti/pazienti.component.html`.

Localizzare la riga della tabella/lista pazienti. Dopo il pulsante di dettaglio/modifica esistente, aggiungere il pulsante cestino **solo se il paziente è eliminabile**:

```html
@if (p.totalAppointments === 0 && p.treatmentPlansCount === 0) {
  <button
    (click)="deletePatient(p); $event.stopPropagation()"
    title="Elimina paziente"
    class="p-1.5 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none"
         viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round"
            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
    </svg>
  </button>
}
```

Adattare la struttura del `@for` / `*ngFor` esistente — il binding `p` potrebbe avere un nome diverso.

- [ ] **Step 4: Verificare in browser**

Avviare il frontend (`cd frontend && npm start`) e verificare:
1. Pazienti con `totalAppointments > 0` → nessun cestino visibile
2. Pazienti senza appuntamenti → cestino visibile
3. Click cestino → `confirm()` appare
4. Conferma → paziente sparisce dalla lista
5. Annulla → nessuna azione

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/core/services/patient.service.ts \
        frontend/src/app/features/pazienti/pazienti.component.ts \
        frontend/src/app/features/pazienti/pazienti.component.html
git commit -m "feat(patients): aggiungi pulsante eliminazione pazienti puri anagrafici"
```

---

## Self-Review

**Spec coverage:**
- ✅ Cancellazione solo se nessun dato associato → guard backend Task 1 Step 3
- ✅ 409 con messaggio se non eliminabile → eccezione + handler Task 1 Step 1-2
- ✅ Pulsante visibile solo per candidati → condizione `@if` Task 2 Step 3
- ✅ Conferma prima dell'azione → `confirm()` Task 2 Step 2
- ✅ Lista si aggiorna dopo delete → `loadPatients()` in `next` callback

**Placeholder scan:** nessuno.

**Type consistency:** `PatientListItem.patientId` (string) usato in `delete(p.patientId)` — coerente con `patient.service.ts` che accetta `id: string`.
