# Piano P1 — esecuzione

Interventi P1 dalla roadmap in `proposte-modifiche.md`: **#12.A** (CRUD prestazioni/prezzi), **#1** (SSE agenda), **#10 Fase 0** (governance Copilot), **#13** (Copilot operativo).
Stato: **Confermato** (in attesa di via). Data: 2026-07-02.

## Ordine e dipendenze
- **Batch 1** (indipendenti, parallelizzabili): A=#12.A · B=#1
- **Batch 2**: C=#10 Fase 0 (prerequisito di #13)
- **Batch 3**: D=#13 (dopo C)

Totale stimato ~4.5-5.5 giorni.

---

## A — #12.A CRUD Prestazioni / prezzi / default-condizione / bundle  (~1.5gg)

Tabelle già per-tenant (schema tenant), **nessun DB change**:
- `service_catalog(id, clinic_id, code, name, category, description, default_price numeric(12,2), default_vat_rate numeric(5,2), active, duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, created_at, updated_at)` — `code` non vuoto (CHECK)
- `condition_service_defaults(id, clinic_id, condition_name, service_id, sort_order)`
- `service_bundle_items(id, clinic_id, parent_service_id, child_service_id, sort_order)`

**Backend** — estendere `ServiceCatalogController` / `ServiceCatalogService`:
- DTO nuovi: `CreateServiceRequest`, `UpdateServiceRequest` (name, category, description, defaultPrice, defaultVatRate, durationMinutes, minToothDigit, maxToothDigit, applicableToDeciduous, active), `ConditionDefaultDto`(id, conditionName, serviceId, serviceName, sortOrder), `CreateConditionDefaultRequest`, `AddBundleItemRequest`(childServiceId, sortOrder).
- Service (tenant `s()` + `clinic_id`): `create`, `update`, `deleteService` (soft: `active=false`; hard solo se non referenziata in `estimate_lines`/`treatment_plan_items`), `listConditionDefaults`, `addConditionDefault`, `deleteConditionDefault(id)`, `addBundleItem`, `deleteBundleItem(id)`.
- Endpoint: `POST /api/services`, `PUT /api/services/{id}`, `DELETE /api/services/{id}`, `GET /api/services/condition-defaults/all`, `POST /api/services/condition-defaults`, `DELETE /api/services/condition-defaults/{id}`, `POST /api/services/{id}/bundle`, `DELETE /api/services/bundle/{itemId}`. Gating **admin/medico**.
- Validazione: prezzo ≥ 0; `name` obbligatorio; `condition_name` ∈ {cavity, crown, missing, root_canal, to_extract, bridge_pillar, bridge_pontic, implant, impacted}.

**Frontend**:
- `service-catalog.service.ts`: +create/update/delete + condition-defaults (list/add/delete) + bundle (add/delete).
- Nuova sezione **"Prestazioni e Listino"** in `impostazioni` (o feature `features/prestazioni/`): tabella per categoria (prezzo/durata/denti/attivo), form crea-modifica, editor mapping condizione→prestazione, editor bundle.

**Accettazione:** creo/modifico prestazione con prezzo; disattivo una referenziata (soft-delete); "Genera piano" dall'odontogramma usa i default aggiornati; il bundle propone i figli.

---

## B — #1 SSE agenda realtime  (~0.5gg)

**Backend** (riusa il pattern SSE di `ChatController`):
- Nuovo `AppointmentEventService`: `ConcurrentMap<UUID clinicId, Set<SseEmitter>>`; `subscribe(clinicId) -> SseEmitter`; `publish(clinicId, "changed")`.
- `AppointmentController`: `GET /api/appointments/stream?token=` (valida il token da query param, **non loggarlo**) → ritorna `SseEmitter`.
- Hook `publish(clinicId, "changed")` a fine `AppointmentService.create / reschedule / cancel / updateStatus` (dopo il commit).

**Frontend**:
- `agenda.component.ts`: `EventSource(\`${apiBaseUrl}/appointments/stream?token=${jwt}\`)` → `onmessage` → ricarica la vista corrente; `close()` in `ngOnDestroy`.

**Accettazione:** modifica di un appuntamento da n8n o da un secondo client → l'agenda aperta si aggiorna senza refresh; publish limitato allo stesso `clinicId`.
**Caveat:** registry in-memory (ok container singolo prod); multi-istanza richiederebbe Redis pub/sub.

---

## C — #10 Fase 0 Governance Copilot  (~0.5-1gg)  — prerequisito di #13

**DB** (patch + `install.sql` + `create_tenant`, per-tenant):
- `ai_audit_log(id, clinic_id, provider_id, action_type text, tool_name text, args_summary text, result text, created_at timestamptz default now())`.

**Backend**:
- `AiAuditService.log(providerId, actionType, tool, argsSummary, result)`.
- Chiamarlo in `DentalCareAiTools.execute()` (unico punto di esecuzione delle scritture) dopo ogni azione, sia successo sia errore. Predisposto per le nuove scritture di #13.
- System prompt (`ChatService`): **disclaimer clinici** obbligatori sulle risposte diagnostiche; nota che le azioni richiedono conferma.
- Gating ruolo: centralizzare un check per i tool sensibili (rifiuto con messaggio se il ruolo non è abilitato) — riusa `isMedical()`/role già presenti.

**Accettazione:** ogni azione confermata lascia una riga in `ai_audit_log`; le risposte cliniche mostrano il disclaimer; i tool vietati per ruolo vengono bloccati con messaggio.

---

## D — #13 Copilot operativo (scrittura moduli + letture)  (~2-2.5gg)  — dopo C

**Backend** — riusa `preview* → confirmAction` (nessun nuovo pattern, nessun endpoint nuovo):
- `PendingActionService.Pending`: aggiungere `ActionType` {CREATE_ESTIMATE, ADD_ESTIMATE_LINE, UPDATE_ESTIMATE_STATUS, CREATE_RECALL, MARK_RECALL_CONTACTED, CLOSE_RECALL, CREATE_PATIENT, UPDATE_PATIENT, CREATE_PLAN, ADD_PLAN_ITEM, ADD_DIARY_NOTE, ADD_DIAGNOSIS, ADD_PRESCRIPTION} + payload per tipo.
- `DentalCareAiTools.execute()` switch: nuovi `case` che chiamano i **service esistenti** — `EstimateService`, `RecallService`, `PatientService`, `TreatmentPlanService`, `ClinicalRecordService`, `DiagnosiService`, `PrescrizioneService` — + `AiAuditService.log` (da C).
- Nuovi `@Tool preview*` (uno per azione) che costruiscono `Pending`, lo registrano in `pendingActions` e ritornano il codice (come `previewCreateAppointment`). `confirmAction` resta invariato (già generico, con fallback `consumeAllForScope`).
- Nuovi `@Tool` lettura: `getTreatmentPlans(patientId)` → `TreatmentPlanService.findByPatient`; `getOdontogram(patientId)` + patologie AI da `patient_document_analyses` (#6); `getAnamnesisAlerts(patientId)` → `AnamnesisService` (allergie/terapie/alert); `getServiceCatalog(query)` → `ServiceCatalogService`; `getInventory`/`getLowStock` → `ProductService`/`StockMovementService`.
- System prompt: nuove capacità + gating ruolo + disclaimer.

**Gating:** scrittura clinica (note/diagnosi/prescrizioni/piani) solo **medico**; segreteria limitata ad agenda/preventivi/richiami/anagrafica base. Ogni conferma → audit (C).

**Frontend:** nessuno (chat invariata).

**Accettazione:** "crea un preventivo a Mario con devitalizzazione al 16" → preview → conferma → salvato + audit; "che piani di cura ha Mario?" risponde; gating per ruolo rispettato.

---

## Note trasversali
- Ordine forzato solo per C→D; A e B sono indipendenti (parallelizzabili tra agenti su file disgiunti).
- #14 (proattività) riuserà l'SSE introdotto in #1; #13 è la base delle azioni proattive.
- Caveat conferma AI: il codice non sopravvive tra i turni → il fallback `consumeAllForScope(providerId)` già gestisce; mantenere il pre-check conflitti per le nuove scritture dove sensato.
- Soft-delete obbligatorio per anagrafiche referenziate (prestazioni in preventivi/piani).
