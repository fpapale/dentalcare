# FIX Scheda Paziente / Preventivi — Piano

Stato: **Fatto** (build FE + BE verdi). Data: 2026-07-01.

Ordine esecuzione a batch (quick-win/bug prima, feature dopo).

## Passi manuali richiesti prima del deploy
- Applicare `database/patch_document_type_prescrizione.sql` a DB dev e prod
  (`ALTER TYPE dentalcare.document_type ADD VALUE 'prescrizione'`) — necessario per l'upload
  documenti prescrizione (#5). `install.sql` già aggiornato per installazioni nuove.
- Rebuild frontend + backend e deploy.
- #2 è solo analisi (vedi `analisi-cambio-medico-riferimento.md`): nessun codice applicato,
  eventuale conferma UI da decidere.

---

## Batch 1 — Bug rapidi (basso rischio)

### FIX 7 — Odontogramma: "Genera piano" resta con clessidra
- **Causa:** `openPianifica()` esegue `forkJoin(requests)` con `requests` vuoto quando nessuna
  condizione è ACTIONABLE → `forkJoin({})` non emette `next` → `servicesLoading` bloccato.
- **Fix:** guard in [odontogramma-tab.component.ts](../frontend/src/app/features/pazienti/odontogramma-tab/odontogramma-tab.component.ts):
  se `sourceItems` vuoto → `servicesLoading.set(false)` + empty state ("Nessuna condizione
  pianificabile"); altrimenti `forkJoin(requests).pipe(defaultIfEmpty({}))`.
- File: `odontogramma-tab.component.ts` (+ empty state in `.html`).

### FIX 6 — Diario Clinico non eliminabile
- **Causa:** manca `DELETE` in [ClinicalRecordController](../backend/src/main/java/com/dentalcare/controller/ClinicalRecordController.java).
- **Fix backend:** `DELETE /api/patients/{patientId}/clinical-record/diary/{entryId}`
  + `ClinicalRecordService.deleteDiaryEntry` (filtro tenant/patient).
- **Fix FE:** `clinical-record.service.deleteDiaryEntry` + bottone elimina con conferma in
  [cartella-tab](../frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.ts) (solo non-secretary).

---

## Batch 2 — Anamnesi + analisi

### FIX 1 — Anamnesi "Dati Generali" non salvati
- **Causa:** write su `patient_anamnesis` (versionata), read da `patients.blood_type /
  anamnesis_notes / anamnesis_date`. Mai sincronizzati.
- **Fix backend:** in [AnamnesisService.savePatientAnamnesis](../backend/src/main/java/com/dentalcare/service/AnamnesisService.java)
  aggiungi `UPDATE patients SET blood_type, anamnesis_notes, anamnesis_date=now()` + boolean
  derivati (smoker, hypertension, diabetes, heart_disease, allergie penicillina/latex/anestetico,
  anticoagulanti, bisfosfonati) così anche gli alert Panoramica riflettono.
- **Fix FE:** dopo save, ricarica paziente nel parent (evento `saved` da anamnesi-tab →
  `paziente-detail.loadPatient`).

### FIX 2 — Cambio medico di riferimento: valutazione impatto
- Analisi (no fix immediato). Verificare filtro visibilità paziente provider-scoped, e legami
  già esistenti (appuntamenti/preventivi/piani/richiami) al vecchio medico.
- Deliverable: `directives/analisi-cambio-medico-riferimento.md` + eventuale conferma UI/audit.

---

## Batch 3 — Documenti / MinIO (riuso pipeline `PatientDocumentService`)

### FIX 4 — Cartella › Esami e Documenti: elenco + "Vedi tutte"
- Solo FE. Sezione documenti read-only (download/preview) in cartella-tab via
  `PatientDocumentService.findAll`; "Vedi tutte" → `openTab.emit('documenti')`.

### FIX 3 — Diagnosi: edit + upload documento
- `PUT /diagnosi/{id}` già esiste. Aggiungi `update` in `diagnosi.service` + form edit FE.
- Upload documento diagnosi: riuso `PatientDocumentService`+MinIO (documentType dedicato,
  link opzionale a diagnosi).

### FIX 5 — Prescrizioni: upload + elenco
- Lista/create/delete già presenti (route `/pazienti/:id/prescrizioni`).
- Aggiungi upload documento (riuso MinIO) + "Vedi tutte".

---

## Batch 4 — Preventivi

### FIX 8 — Tab pazienti/Preventivi (oggi placeholder "in sviluppo")
- Costruisci elenco preventivi paziente in [paziente-detail.html:443](../frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.html)
  via `EstimateService.findByPatient` (endpoint esistente) + bottone "Nuovo" →
  `/preventivi/nuovo?patientId=<id>`.

### FIX 9 — Nuovo preventivo senza paziente — decisione: **ENTRAMBI**
- **A:** creazione da scheda paziente (coperta da FIX 8, con `patientId` in query).
- **B:** selettore paziente nel form nuovo preventivo
  ([preventivo-detail.component.ts](../frontend/src/app/features/preventivi/preventivo-detail/preventivo-detail.component.ts)):
  se manca `patientId` mostra dropdown pazienti invece dell'errore; abilita "Crea" solo con
  paziente scelto.
