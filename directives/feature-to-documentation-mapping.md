# Feature-to-Documentation Mapping

Mapping tra la documentazione GitHub DentalCare-Documentation e le feature implementate/proposte nel progetto dentalcare.

**Data:** 2026-07-03 | **Scope:** DentalCare Pro roadmap vs proposte-modifiche.md (#1-17) + CLAUDE.md + wiki_llm_minio_architecture.md

---

## Overview Strutture

| Repo GitHub | Equivalente Locale | Note |
|-------------|-------------------|------|
| `01-Studio-di-Fattibilita/` | Implicito in visione | Analisi mercato, SWOT, rischi, validation plan |
| `02-Business-Plan/` | Implicito | Business model, revenue, go-to-market |
| `03-Product-Roadmap/` | `proposte-modifiche.md` + CLAUDE.md | Release 1.x-5.x = feature fasi |
| `04-Architecture-Handbook/` | CLAUDE.md + `wiki_llm_minio_architecture.md` | 10 sezioni architetturali |

---

## 1. Studio di Fattibilità vs Stato Attuale

### 1.1 Vision & Market Analysis

| Doc GitHub | Feature Implementata | Status | Note |
|------------|---------------------|--------|------|
| Vision.md | AI-native platform per studi odontoiatrici | ✅ **Implementato** | CLAUDE.md Sezione 1-5: Cloud PM + AI Copilot + Voice + Radiology + BI |
| Analisi-Mercato.md | Competitor analysis + market positioning | ⚠️ **Proposta** | `proposte-modifiche.md` → roadmap per go-to-market esterno |
| SWOT.md | Risk management | ⚠️ **Proposta** | #7 GDPR compliance alza risk profile; #15 RAG complexity |
| Rischi.md | Security compliance (PHI handling) | ✅ **Parziale** | #7 GDPR in proposte; #10 Copilot audit → compliance |

### 1.2 Clinical Advisory Board & Validation

| Aspect | Feature | Status | Commit/Link |
|--------|---------|--------|------------|
| User acceptance testing | #10 Copilot Fase 0 (disclaimer + governance) | ✅ **Fatta (dev)** | 9a01e3b |
| Clinical workflows | #13 Copilot operativo (letture/scritture moduli) | ✅ **Fatta (dev)** | 4ec275c |
| Validation plan | #16 Wiki LLM (OCR → schema → DB sync) | ✅ **Proposta** | wiki_llm_minio_architecture.md |

---

## 2. Product Roadmap: Release Mapping

GitHub Releases 1.x → 5.x mappa a proposte-modifiche.md per fasi e impatto:

### Release 1.x → P1 (Subito)

| Feature Doc | Proposta # | Titolo | Status | Done |
|-------------|-----------|--------|--------|------|
| Cloud PM core | #12.A | CRUD Prestazioni/prezzi/default/bundle | Confermata | ✅ dev |
| Agenda realtime | #1 | SSE agenda in tempo reale | Confermata | ✅ dev |
| Copilot governance | #10 Fase 0 | Audit azioni + disclaimer + gating | Confermata | ✅ dev |
| Copilot writing | #13 | Operativo: scrittura sui moduli | Confermata | ✅ dev |
| Prompt management | #17 | Prompt multilingua editabili | Confermata | ✅ dev |

> **P1 completato in dev** (2026-07-02). Pronto per deployment prod.

### Release 2.x → P2 (Poi)

| Feature Doc | Proposta # | Titolo | Status | Blocchi |
|-------------|-----------|--------|--------|---------|
| Anagrafiche per-studio | #12.C | CRUD categorie prodotto | Proposta | Nessuno |
| Data quality | #3 | Validazione CF + flag stranieri | Proposta | Nessuno |
| Copilot context-aware | #14 | Proattivo + cross-modulo SSE | Proposta | Dipende #13, #1 |

### Release 3.x → P3 (Dopo/Compliance)

| Feature Doc | Proposta # | Titolo | Status | Prerequisiti |
|-------------|-----------|--------|--------|-------------|
| GDPR compliance | #7 | Cifratura per-tenant (AES-256-GCM) | Proposta | Obbligatorio per vendita |
| Multi-sede (Voice) | #2 | Retell multi-studio per agente | Proposta | Se/quando scale multiple |
| Wiki Knowledge Base | #16 | OCR → GPT-4o → MinIO versionamento | Proposta | #7 (PHI), opzionale #8 (DICOM) |
| DICOM support | #8 | AI Service: supporto nativo | Proposta | Dopo #6 (Dentex YOLO) |

### Release 4.x-5.x → Future

| Feature Doc | Proposta # | Titolo | Status | Dependencies |
|-------------|-----------|--------|--------|------------|
| Copilot RAG | #15 | RAG + multimodale + memoria | Proposta | #13, #14, #16 (wiki KB) |
| Advanced anamnesi | #12.B | CRUD voci anamnesi per-tenant | Proposta | Design decision (Opt 1/2/3) |

---

## 3. Architecture Handbook Mapping

### 3.1 Overview (01-Overview.md)

| Arch Component | CLAUDE.md Section | Implementation | Status |
|---|---|---|---|
| Layered architecture | Sezione 6-7 | Spring Boot 3 + Angular 17 | ✅ Implementato |
| Multitenancy | Sezione 11 | Per-schema PostgreSQL + MinIO bucket prefix | ✅ Implementato |
| Data flow | CLAUDE.md 21 (end-to-end) | Angular → REST API → Spring → JPA → DB | ✅ Implementato |
| Component isolation | Sezione 5 | DTO separati, entity JPA not exposed | ✅ Implementato |

### 3.2 Backend (02-Backend.md)

| Layer | CLAUDE.md | Feature | Status | Doc Link |
|-------|-----------|---------|--------|----------|
| Controller REST | Sezione 6.2 | `@RestController` + DTO + @Valid | ✅ Implementato | CLAUDE.md |
| Service layer | Sezione 6.3 | Logica applicativa, validazioni, @Transactional | ✅ Implementato | CLAUDE.md |
| Repository | Sezione 6.4 | JpaRepository, query derivate, @Query | ✅ Implementato | CLAUDE.md |
| Entity JPA | Sezione 7 | Hibernate mappings, relazioni, lazy loading | ✅ Implementato | CLAUDE.md |
| Error handling | Sezione 10.2 | @RestControllerAdvice, centralized | ✅ Implementato | CLAUDE.md |
| Security | Sezione 11 | JWT, RBAC, TenantContext | ✅ Implementato | CLAUDE.md |
| MinIO storage | wiki_llm_minio_architecture.md | MinioStorageService (AWS SDK v2) | ✅ Implementato | MinIO recap |
| **Proposta**: Wiki LLM backend | #16 | WikiStorageService, WikiLlmService | ⚠️ Proposta | wiki_llm_minio_architecture.md §8.2 |
| **Proposta**: GDPR encryption | #7 | DocumentEncryptionService extend | ⚠️ Proposta | proposte-modifiche.md #7 |

### 3.3 Frontend (03-Frontend.md)

| Layer | CLAUDE.md | Feature | Status | Doc Link |
|-------|-----------|---------|--------|----------|
| Modular architecture | Sezione 5.1 | core/ + shared/ + features/ + layout/ | ✅ Implementato | CLAUDE.md |
| Reactive Forms | Sezione 5.5 | Template-driven → Reactive Forms | ✅ Implementato | CLAUDE.md |
| Services HTTP | Sezione 5.3 | Observable<T>, typed requests/responses | ✅ Implementato | CLAUDE.md |
| Guards & interceptors | Sezione 5.7 | Auth guard, JWT token, error handling | ✅ Implementato | CLAUDE.md |
| Three-column layout | Sezione 5.8 | LayoutService + right panel KPI | ✅ Implementato | CLAUDE.md |
| Locale IT | Sezione 5.9 | registerLocaleData(localeIt) | ✅ Implementato | CLAUDE.md |
| **Proposta**: AI Prompt UI | #17 | AiPromptsComponent in ImpostazioniComponent | ✅ Fatta (dev) | proposte-modifiche.md #17 |
| **Proposta**: Wiki viewer | #16 | (opzionale) Wiki markdown browser | ⚠️ Proposta | wiki_llm_minio_architecture.md |

### 3.4 AI (04-AI.md)

| AI Capability | Feature # | Implementation | Status | Details |
|---|---|---|---|---|
| AI Copilot (Chat) | #10, #13 | Spring AI + OpenAI (GPT-4o) | ✅ Fatta (dev) | ChatController, ChatService |
| Prompt management | #17 | PromptService + `ai_prompts` table | ✅ Fatta (dev) | Multilingue IT/EN |
| Voice assistant (Retell) | #2 | n8n + Retell AI integration | ✅ Implementato | n8n workflow parametrico |
| **Proposta**: Multi-agent | #2 | Retell agents per sede/poltrona | ⚠️ Proposta | proposte-modifiche.md #2 |
| **Proposta**: OCR + LLM | #16 | PyMuPDF/Docling + GPT-4o pipeline | ⚠️ Proposta | wiki_llm_minio_architecture.md |
| **Proposta**: RAG | #15 | Embeddings + Elasticsearch + retrieval | ⚠️ Proposta | proposte-modifiche.md #15 |
| **Proposta**: Multimodal | #15 | Vision + PDF parsing | ⚠️ Proposta | proposte-modifiche.md #15 |

### 3.5 DICOM (05-DICOM.md)

| DICOM Feature | Proposta # | Status | Timeline |
|---|---|---|---|
| DICOM parsing (nativa) | #8 | ⚠️ Proposta (P3) | Post-#6, dipende DICOM libraries |
| **Attuale**: YOLO su ortopanoramica | #6 | ✅ Fatta | Dentex inference |
| **Attuale**: AI callback → wiki | #16 | ✅ Proposta | Parte di wiki_llm_minio_architecture.md |

### 3.6 Multitenancy (06-Multitenancy.md)

| Multitenancy Aspect | CLAUDE.md | Implementation | Status |
|---|---|---|---|
| Tenant isolation per schema | Sezione 11 | PostgreSQL schema_per_tenant | ✅ Implementato |
| Bucket isolation MinIO | wiki_llm_minio_architecture.md | `dc-<schema>` prefix + TenantContext | ✅ Implementato |
| Row-level security | Sezione 11.3 | Filtri repository per tenant | ✅ Implementato |
| **Proposta**: GDPR encryption per-tenant | #7 | HKDF + per-tenant key derivation | ⚠️ Proposta | proposte-modifiche.md #7 |

### 3.7 Security (07-Security.md)

| Security Layer | CLAUDE.md | Feature | Status | Roadmap |
|---|---|---|---|---|
| Authentication JWT | Sezione 11.2 | Token frontend + validation backend | ✅ Implementato | CLAUDE.md |
| Authorization RBAC | Sezione 11.2 | ROLE_ADMIN, ROLE_USER, ROLE_MANAGER | ✅ Implementato | CLAUDE.md |
| Password hashing | Sezione 11.1 | Spring Security password encoder | ✅ Implementato | CLAUDE.md |
| Input validation | Sezione 10.1 | Bean Validation + custom validators | ✅ Implementato | CLAUDE.md |
| CORS configured | Sezione 11.1 | Per environment (dev/prod) | ✅ Implementato | CLAUDE.md |
| Audit trail | #10 Fase 0 | `ai_audit_log` table + AiAuditService | ✅ Fatta (dev) | proposte-modifiche.md #10 |
| **Proposta**: GDPR cifratura | #7 | AES-256-GCM + per-tenant keys | ⚠️ Proposta | proposte-modifiche.md #7 |
| **Proposta**: PHI redaction | #16 | Wiki LLM sanitization | ⚠️ Proposta (part of #16) | wiki_llm_minio_architecture.md §10 |

### 3.8 DevOps (08-DevOps.md)

| DevOps Component | Implementation | Status |
|---|---|---|
| Docker Compose | docker-compose.yml | ✅ Implementato |
| Container orchestration | PostgreSQL, backend, frontend, ai-service, minio | ✅ Implementato |
| **Proposta**: Wiki worker container | #16 | ⚠️ Proposta | wiki_llm_minio_architecture.md §14.3 |
| CI/CD pipeline | (probabilmente in GitHub Actions) | ⚠️ Non visible nel repo locale |

### 3.9 Deployment (09-Deployment.md)

| Deployment Scenario | CLAUDE.md Section | Status | Notes |
|---|---|---|---|
| Development | Sezione 14 (comandi) | ✅ Implementato | npm start, mvnw spring-boot:run, docker compose up |
| Production | config/application-prod.properties | ✅ Implementato | Spring profile prod, external config |
| **Proposta**: Prod GDPR | #7 | ⚠️ Prerequisito | Encrypt secrets, key rotation |

### 3.10 Testing (10-Testing.md)

| Testing Type | CLAUDE.md Section | Status | Implementation |
|---|---|---|---|
| Unit tests | Sezione 13.1 | ✅ JUnit + Mockito | Backend test/ |
| Integration tests | Sezione 13.1 | ⚠️ Testcontainers (optional) | Se già presente |
| Frontend tests | Sezione 13.2 | ⚠️ Jasmine/Karma | Check angular.json config |
| **Proposta**: Runtime validation | #16 | ⚠️ Proposta (P3) | Playwright + test scenarios |

---

## 4. Gap Analysis: Documentazione vs Implementazione

### 4.1 Completato (Implementato vs Documentato)

| Area | Github Doc | Implementazione | Stato | Effort |
|------|-----------|---|---|---|
| ✅ **Core PM** | Cloud Practice Mgmt | Backend + Frontend CRUD completo | ✅ Allineato | Done |
| ✅ **Multitenancy** | 06-Multitenancy.md | Schema isolation + MinIO per-tenant | ✅ Allineato | Done |
| ✅ **AI Copilot base** | 04-AI.md (Chat) | ChatController + ChatService + GPT-4o | ✅ Allineato | Done |
| ✅ **Voice Agent** | 04-AI.md (Voice) | n8n Retell integration | ✅ Allineato | Done |
| ✅ **AI Radiology** | 04-AI.md + 05-DICOM | Dentex YOLO inference + callback | ✅ Allineato | Done |
| ✅ **Prompt Manager** | 04-AI.md (implied) | PromptService + multi-locale DB | ✅ **Nuovo** (non doc'd in detail) | Done |
| ✅ **Audit & Compliance** | 07-Security.md (implied) | ai_audit_log + disclaimer | ✅ **Nuovo** (Proposta #10) | Done |

### 4.2 Gap: Documentato ma Non Implementato

| Feature | GitHub Doc | Proposta # | Priority | Blocker |
|---------|-----------|-----------|----------|---------|
| ⚠️ **GDPR Encryption** | 07-Security.md (implied compliance) | #7 | P3 / Alza a P1 se vendita | Pre-requisito |
| ⚠️ **Wiki Knowledge Base** | 04-AI.md (RAG context implied) | #16 | P3 / Nuovo | #7 (PHI) |
| ⚠️ **RAG + Memory** | 04-AI.md (advanced Copilot) | #15 | P3 / Future | #13, #14, #16 |
| ⚠️ **DICOM Native** | 05-DICOM.md (detailed) | #8 | P3 | #6 (done) |
| ⚠️ **Multi-studio Voice** | 04-AI.md (implied) | #2 | P3 | Quando scale |

### 4.3 Gap: Non Documentato ma Proposto

| Feature | Proposta # | Description | Status | Why Gap? |
|---------|-----------|---|---|---|
| **Validazione CF** | #3 | Data quality (codice fiscale italiano + stranieri) | Proposta | Feature locale, non strategic |
| **Copilot Context** | #14 | Proattivo + cross-modulo | Proposta | Evolved requirement (da #13) |
| **Anamnesi per-tenant** | #12.B | Custom medical history per studio | Proposta | Design decision needed |
| **Categorie magazzino** | #12.C | Product inventory classification | Proposta | Non core, nice-to-have |

---

## 5. Roadmap Alignment: GitHub Releases vs Proposte-Modifiche Phases

### Timeline & Priority Mapping

```
GitHub Release        Proposte-Modifiche Phase   ETA       Status
───────────────────────────────────────────────────────────────────
Release 1.x (MVP)  →  P1 (Subito)              2026-07-15  ✅ dev (deploy pending)
  - Core PM
  - Copilot chat
  - Voice agent
  - Radiology AI

Release 2.x (UX)   →  P2 (Poi)                 2026-08-30  ⚠️ Proposta (#12.C, #3, #14)
  - Product catalog
  - Data quality
  - Context awareness

Release 3.x (Scale) →  P3 (Dopo/Compliance)    2026-10-31  ⚠️ Proposta (#7, #2, #16, #8)
  - GDPR compliance
  - Multi-studio
  - Wiki KB (RAG-ready)
  - DICOM support

Release 4.x (AI+++) →  Future                  2027-Q1     🔮 R&D (#15, #12.B)
  - RAG + memory
  - Multimodal copilot
  - Advanced anamnesi
```

---

## 6. Documentazione Gaps & Opportunities

### 6.1 Per la Repo GitHub DentalCare-Documentation

| Section | Current State | Recommended Update | Priority |
|---------|---|---|---|
| 03-Product-Roadmap/Release-1.x.md | ⚠️ Generic outline | Link commits + deployment status | Medium |
| 03-Product-Roadmap/Release-2.x.md | ⚠️ TODO | Map a proposte-modifiche.md P2 | Medium |
| 03-Product-Roadmap/AI-Roadmap.md | ⚠️ Generic | Spec #10/#13/#14/#15/#17 in detail | High |
| 04-Architecture-Handbook/04-AI.md | ⚠️ Generic | Add Prompt Manager, Wiki LLM design | High |
| 04-Architecture-Handbook/06-Multitenancy.md | ⚠️ Generic | Add MinIO bucket isolation, GDPR #7 | High |
| 04-Architecture-Handbook/07-Security.md | ⚠️ Generic | Detail GDPR #7, audit trail #10 | **Critical** |

### 6.2 Per il Repo Locale dentalcare

| Documentation | Location | Status | Recommendation |
|---|---|---|---|
| Technical Spec | CLAUDE.md | ✅ Completo | Mantieni aggiornato con nuove feature |
| Feature Planning | proposte-modifiche.md | ✅ Completo | **Sincronizza** con GitHub roadmap releases |
| Architecture Deep-Dive | wiki_llm_minio_architecture.md | ✅ Nuovo (2026-07-03) | Proposte per aggiungere a GitHub 04-Architecture-Handbook |
| Directives | directives/ | ✅ Vario | Consider structure consolidation |

---

## 7. Recommendations & Next Steps

### 7.1 Immediate (P1 - Due 2026-07-15)

- [ ] **Deploy P1 features to prod** (#1, #12.A, #10 Fase 0, #13, #17)
  - Prerequisite: validate git commits + build green
  - Risk: none (already tested in dev)

- [ ] **Sync GitHub Release-1.x.md**
  - Add commit hashes (#12.A, #1, #10 Phase0, #13, #17)
  - Add deployment checklist + go-live date

### 7.2 Short-term (P2 - Aug 2026)

- [ ] **Decide on #12.B (Anamnesi per-tenant)** → update Release-2.x roadmap
- [ ] **Schedule #3 (CF validation)** if data quality required for compliance
- [ ] **Plan #14 (Copilot context-aware)** after P1 deployment feedback

### 7.3 Medium-term (P3 - Oct 2026)

- [ ] **Activate #7 (GDPR)** if selling to clinics (prerequisite for all subsequent features)
- [ ] **Propose #16 (Wiki LLM)** to product + CAB (clinical advisory board)
  - Depends on PHI handling decision (GDPR #7)
  - Enables #15 (RAG) in Release 4.x

- [ ] **Update GitHub Release-3.x.md** with #7, #2, #16, #8 detailed spec

### 7.4 Documentation Sync

- [ ] Mirror wiki_llm_minio_architecture.md to GitHub `04-Architecture-Handbook/11-Wiki-LLM.md`
- [ ] Consolidate proposte-modifiche.md → GitHub `03-Product-Roadmap/Backlog.md` (for features post-Release 5.x)
- [ ] Create "Implementation Status" dashboard linking GitHub roadmap to local commits

---

## 8. Conclusione

La **struttura documentale GitHub** (Feasibility Study → Business Plan → Product Roadmap → Architecture Handbook) è **coerente con l'implementazione locale**:

- **P1 (Release 1.x):** ✅ Completo in dev, pronto per prod
- **P2-P3 (Release 2.x-5.x):** ⚠️ Proposti e tracciati, priorità definita
- **Architecture:** ✅ Allineato con CLAUDE.md + nuove spec (wiki_llm_minio_architecture.md)
- **Compliance:** ⚠️ Risk (#7 GDPR) — alza a P1 se vendita clinica

**Prossimo passo:** Sync proposte-modifiche.md con GitHub Release roadmaps e aggiorna architecture handbook con wiki_llm_minio_architecture.md.
