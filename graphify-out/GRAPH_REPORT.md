# Graph Report - d:\dentalcare  (2026-07-16)

## Corpus Check
- Large corpus: 529 files · ~1,149,121 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 3720 nodes · 7677 edges · 189 communities (148 shown, 41 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 386 edges (avg confidence: 0.79)
- Token cost: 463,778 input · 9,500 output

## Community Hubs (Navigation)
- Amministrazione Tenant (API)
- Bootstrap Dati Demo
- Catalogo Prestazioni (API)
- DTO Preventivi e Richiami
- Gestione Provider (API)
- Magazzino (modelli FE)
- Richiami (modelli FE)
- Appuntamenti (API)
- Prompt Manager AI (API)
- Preventivi (API)
- Chat Copilot (API)
- Annotazioni REST condivise
- Catalogo Anamnesi (API)
- Impostazioni (UI)
- Dipendenze Angular
- Prodotti Magazzino (API)
- Chat Copilot (frontend)
- Cartella Clinica (API)
- Routing e Autenticazione FE
- Gestione Errori Backend
- Scheda Paziente (UI)
- Analisi AI Radiologica
- Prestazioni (modelli FE)
- Piani di Cura (frontend)
- Prescrizioni (API)
- Odontogramma (UI)
- Piani di Cura (API)
- Pazienti (modelli FE)
- Fornitori (API)
- Anamnesi (frontend)
- TreatmentItemStatus
- DiagnosiController
- AdminTenantComponent
- ClinicSettingsController
- InvoiceDetailDto
- TreatmentPlanService
- Backend Java Wiki services (WikiOcrServi
- app
- AgendaComponent
- AnamnesisController
- Angular App Shell (index.html) with Odon
- appointment.model
- RecallContactDto
- anamnesis-catalog.model
- InvoiceController
- JwtAuthenticationFilter
- Appointment (Appuntamento) — domain conc
- odontogram.model
- PublicController
- StockMovementController
- ai-prompt.model
- provider.model
- admin-tenant.component
- PreventiviComponent
- PatientDocumentAnalysisController
- PatientController
- estimate.model
- Appointment
- CLAUDE.md — Istruzioni Operative Progett
- DocumentiTabComponent
- PrestazioniComponent
- LoginConfirmRequest
- RecallController
- Patient
- onnx_yolo
- PreventivoDetailComponent
- DashboardController
- OdontogramController
- PatientDocumentService
- invoice.model
- Retell.io phone agent integration
- patient-document.model
- copilot-context.service
- DashboardComponent
- FatturaDetailComponent
- FatturazioneComponent
- CartellaClinciComponent
- CartellaClinicalTabComponent
- chat.system.en.txt — SegretarIA System P
- EncryptionMigrationController
- HolidayController
- PatientDocumentController
- OdontogramSyncServiceTest
- CopilotSuggestionService
- wiki_llm_minio_architecture.md (external
- odontogramma-tab.component
- Roadmap Release 1.x-5.x
- Provider
- TenantSchemaRegistry
- DocumentEncryptionService
- config
- schematics
- patient-analysis.model
- CreateProductCategoryRequest
- PatientDocumentSummaryDto
- annotations
- main
- prescrizione.model
- dentex_disease_v1.onnx (Impacted/Caries/
- AiJobRequest
- EncryptionException
- ConfigMasterKeyProvider
- TenantEncryptionServiceTest
- EncryptionMigrationServiceTest
- retraining
- clinic-billing.model
- clinical-record.model
- role.guard
- diagnosi.model
- AiCallbackController
- TenantUser
- User
- SecurityConfig
- CopilotSuggestionSchedulerTest
- NoOpDocumentEncryptionService
- PatientServiceTest
- minio_client
- visualization
- DiagnosiComponent
- DocumentoAnalisiComponent
- AiCallbackRequest
- SseEmitterRegistry
- postprocessing
- test_minio_client
- docker-compose.yml (backend+frontend, si
- Appointment
- install.sh
- P2 Implementation Plan (#12.C, #3, #14)
- callback
- serve
- LoginComponent
- PrescrizioniComponent
- registrazione.component
- mvnw
- AuthController
- ClinicOption
- AppointmentService
- NuovoAppuntamentoComponent
- build_workflow
- Clinic
- AiAuditService
- ToolLayerService
- pipeline
- FlywayConfig
- CopilotController
- HmacVerifierTest
- Master Key Fail-Fast Prerequisite (befor
- angular
- DentalcareApiApplicationTests
- PatientService.findAll/findById visibili
- ReviewAnalysisRequest
- segretaria_architettura_multitenant_ai.m
- DentalcareApiApplication
- HomeController
- src/styles.css
- Component
- landing.component
- Lombok 1.18.40 dependency
- DemoConfigResponse
- Sistema AI di Revisione Radiografica — D
- build
- production
- prefix
- CreatePlanFromOdontogramRequest
- agenda-page.component
- cartella-page.component
- magazzino-page.component
- preventivi-page.component
- richiami-page.component
- TenantAspect
- StartAnalysisResponse
- CreateCatalogCategoryRequest
- CreateCatalogItemRequest
- CreateRecallContactRequest
- GenerateRecallsResponse
- UpdateCatalogCategoryRequest
- UpdateCatalogItemRequest
- Product (Inventory)
- environment.prod
- com.dentalcare:dentalcare-api

## God Nodes (most connected - your core abstractions)
1. `DentalCareAiTools` - 68 edges
2. `ImpostazioniComponent` - 55 edges
3. `ResourceNotFoundException` - 51 edges
4. `AgendaComponent` - 51 edges
5. `Patient (Paziente) — domain concept` - 51 edges
6. `PazienteDetailComponent` - 40 edges
7. `AuthService` - 37 edges
8. `OdontogrammaTabComponent` - 35 edges
9. `AppointmentService` - 34 edges
10. `AdminTenantComponent` - 33 edges

## Surprising Connections (you probably didn't know these)
- `ai-den-secretary.png (src/assets) – Content Mismatch: Renaissance-era Portrait, Unrelated to Dental/AI Theme` --conceptually_related_to--> `AI Copilot / SegretarIA assistant — domain concept`  [AMBIGUOUS]
  frontend/src/assets/ai-den-secretary.png → directives/segretaria_architettura_multitenant_ai.md
- `Pipeline OCR → Wiki Markdown → DB sync` --semantically_similar_to--> `Spec: Servizio AI YOLO — Inferenza ortopanoramiche + integrazione DentalCare (#6)`  [INFERRED] [semantically similar]
  directives/wiki_llm_minio_architecture.md → docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md
- `n8n Webhook / Chat Trigger` --conceptually_related_to--> `Richiami Management Screen (App)`  [INFERRED]
  userdocument/Compiled n8n Docs (1).pdf → frontend/src/app/features/richiami/richiami.component.html
- `primary_provider_id Visibility Model` --semantically_similar_to--> `Multitenancy Pattern (tenant_id / schema-per-tenant)`  [INFERRED] [semantically similar]
  directives/analisi-cambio-medico-riferimento.md → CLAUDE.MD
- `Role/Permission Model (Dentista/Assistente/Segreteria/Admin)` --semantically_similar_to--> `JWT Auth + Roles (ROLE_ADMIN/ROLE_USER/ROLE_MANAGER, 401 vs 403)`  [INFERRED] [semantically similar]
  directives/DIRECTIVE_CARTELLA_CLINICA_DENTALCARE_PRO.md → CLAUDE.MD

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SegretarIA / Copilot AI Chat Subsystem** — backend_src_main_resources_ai_prompts_chat_system_it, backend_src_main_resources_ai_prompts_chat_system_en, readme_segretaria_ai, directives_proposte_modifiche_p17_prompt_manager, directives_proposte_modifiche_p13_copilot_operativo [INFERRED 0.85]
- **AI YOLO Dental Radiograph Analysis Pipeline** — dentalcare_ai_service_readme, directives_dentalcare_ai_service_spec, directives_proposte_modifiche_p6_ai_yolo_carie, ai_service_dentex_fdi_model, ai_service_dentex_disease_model, directives_manuale_installazione_prod [INFERRED 0.85]
- **GDPR Per-Tenant Field Encryption Rollout** — directives_proposte_modifiche_p7_gdpr_cifratura, directives_deploy_gdpr_slice1_prod, directives_proposte_modifiche_tenant_encryption_service, directives_proposte_modifiche_config_master_key_provider, directives_feature_to_documentation_mapping [EXTRACTED 1.00]
- **GDPR field-level encryption rollout (TenantEncryptionService dual-write→migrate→cutover)** — docs_superpowers_specs_2026_07_04_gdpr_encryption_design, docs_superpowers_plans_2026_07_04_gdpr_encryption_slice1_birthdate, docs_superpowers_specs_2026_07_08_gdpr_slice2a_fiscalcode_design, docs_superpowers_plans_2026_07_08_gdpr_slice2a_fiscalcode [INFERRED 0.95]
- **AI YOLO ortopanoramic analysis feature (spec + Python service + Spring integration)** — docs_superpowers_specs_2026_06_26_ai_yolo_service_design, docs_superpowers_plans_2026_06_26_ai_service_python, docs_superpowers_plans_2026_06_26_ai_integration_dentalcare [EXTRACTED 1.00]
- **MinIO-based patient document storage architecture (bucket-per-tenant, MinioStorageService)** — directives_wiki_llm_minio_architecture, docs_superpowers_specs_2026_06_26_patient_documents_design, docs_superpowers_plans_2026_06_26_patient_documents [INFERRED 0.85]
- **Patient Detail Tab Suite** — frontend_src_app_features_pazienti_paziente_detail_paziente_detail_component_screen, frontend_src_app_features_pazienti_cartella_tab_cartella_tab_component_screen, frontend_src_app_features_pazienti_anamnesi_tab_anamnesi_tab_component_screen, frontend_src_app_features_pazienti_odontogramma_tab_odontogramma_tab_component_screen, frontend_src_app_features_pazienti_piano_cura_tab_piano_cura_tab_component_screen, frontend_src_app_features_pazienti_richiami_tab_richiami_tab_component_screen, frontend_src_app_features_pazienti_documenti_tab_documenti_tab_component_screen [INFERRED 0.95]
- **Odontogram to Treatment Plan Flow** — frontend_src_app_features_pazienti_odontogramma_tab_odontogramma_tab_component_screen, frontend_src_app_features_pazienti_piano_cura_tab_piano_cura_tab_component_screen, frontend_src_app_features_pazienti_piano_cura_detail_piano_cura_detail_component_screen [INFERRED 0.85]
- **Treatment Plan to Estimate to Invoice Flow** — frontend_src_app_features_pazienti_piano_cura_detail_piano_cura_detail_component_screen, frontend_src_app_features_fatturazione_fatturazione_component_screen, frontend_src_app_features_fatturazione_fattura_detail_fattura_detail_component_screen [INFERRED 0.75]
- **Public Marketing Site Funnel (Landing to Feature Pages to Registration)** — frontend_src_app_features_public_landing_landing_component_screen, frontend_src_app_features_public_agenda_page_agenda_page_component_screen, frontend_src_app_features_public_cartella_page_cartella_page_component_screen, frontend_src_app_features_public_magazzino_page_magazzino_page_component_screen, frontend_src_app_features_public_preventivi_page_preventivi_page_component_screen, frontend_src_app_features_public_richiami_page_richiami_page_component_screen, frontend_src_app_features_public_registrazione_registrazione_component_screen [INFERRED 0.85]
- **n8n/Retell Automation Powering SegretarIA Chat and Richiami Reminders** — userdocument_compiled_n8n_docs_1_webhook_trigger, frontend_src_app_features_segretaria_segretaria_component_screen, frontend_src_app_features_richiami_richiami_component_screen [INFERRED 0.75]
- **Treatment Plan to Estimate to Invoice Workflow (Manuale Utente)** — userdocument_manuale_utente_pazienti, userdocument_manuale_utente_preventivi, userdocument_manuale_utente_fatturazione [INFERRED 0.85]

## Communities (189 total, 41 thin omitted)

### Community 0 - "Amministrazione Tenant (API)"
Cohesion: 0.06
Nodes (31): DeleteMapping, GetMapping, HttpServletResponse, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController (+23 more)

### Community 1 - "Bootstrap Dati Demo"
Cohesion: 0.05
Nodes (32): ApplicationRunner, DemoDataInitializer, ApplicationArguments, Component, JdbcTemplate, Logger, Override, PasswordEncoder (+24 more)

### Community 2 - "Catalogo Prestazioni (API)"
Cohesion: 0.07
Nodes (24): DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController, ServiceCatalogController (+16 more)

### Community 3 - "DTO Preventivi e Richiami"
Cohesion: 0.08
Nodes (13): CreateEstimateRequest, CreateRecallRequest, DailyBriefingDto, PatientSummaryDto, UpdateRecallRequest, DentalCareAiTools, Component, Logger (+5 more)

### Community 4 - "Gestione Provider (API)"
Cohesion: 0.06
Nodes (27): DeleteMapping, GetMapping, PatchMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController (+19 more)

### Community 5 - "Magazzino (modelli FE)"
Cohesion: 0.05
Nodes (19): CreateProductCategoryRequest, CreateProductRequest, Product, ProductCategory, UpdateProductRequest, CreateStockMovementRequest, StockMovement, CreateSupplierRequest (+11 more)

### Community 6 - "Richiami (modelli FE)"
Cohesion: 0.05
Nodes (14): CreateRecallContactRequest, CreateRecallRequest, GenerateRecallsResponse, Recall, RecallContact, UpdateRecallRequest, RecallService, Injectable (+6 more)

### Community 7 - "Appuntamenti (API)"
Cohesion: 0.09
Nodes (21): AppointmentController, GetMapping, PatchMapping, PostMapping, RequestMapping, ResponseEntity, ResponseStatus, RestController (+13 more)

### Community 8 - "Prompt Manager AI (API)"
Cohesion: 0.06
Nodes (27): AiPromptController, DeleteMapping, GetMapping, PutMapping, RequestMapping, ResponseStatus, RestController, ChatResponse (+19 more)

### Community 9 - "Preventivi (API)"
Cohesion: 0.07
Nodes (20): EstimateController, DeleteMapping, GetMapping, PatchMapping, PostMapping, RequestMapping, ResponseStatus, RestController (+12 more)

### Community 10 - "Chat Copilot (API)"
Cohesion: 0.08
Nodes (21): ChatController, DeleteMapping, GetMapping, RequestMapping, ResponseStatus, RestController, SseEmitter, ChatMessageDto (+13 more)

### Community 11 - "Annotazioni REST condivise"
Cohesion: 0.08
Nodes (25): DeleteMapping, GetMapping, PatchMapping, PostMapping, PutMapping, RequestMapping, ResponseEntity, ResponseStatus (+17 more)

### Community 12 - "Catalogo Anamnesi (API)"
Cohesion: 0.08
Nodes (22): AnamnesisCatalogController, CreateCatalogCategoryRequest, CreateCatalogItemRequest, DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping (+14 more)

### Community 14 - "Dipendenze Angular"
Cohesion: 0.05
Nodes (40): @angular/build, @angular/cli, @angular/common, @angular/compiler, @angular/compiler-cli, @angular/core, @angular/forms, @angular/platform-browser (+32 more)

### Community 15 - "Prodotti Magazzino (API)"
Cohesion: 0.12
Nodes (16): DeleteMapping, GetMapping, PostMapping, PutMapping, ResponseStatus, RestController, ProductController, CreateProductCategoryRequest (+8 more)

### Community 16 - "Chat Copilot (frontend)"
Cohesion: 0.07
Nodes (17): ChatMessageDto, ChatRequest, ChatResponse, ChatService, ChatSessionDto, ChatStreamEvent, ChatTurn, ChatUiContext (+9 more)

### Community 17 - "Cartella Clinica (API)"
Cohesion: 0.10
Nodes (16): ClinicalRecordController, DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController (+8 more)

### Community 18 - "Routing e Autenticazione FE"
Cohesion: 0.10
Nodes (12): AuthUser, ClinicOption, DemoConfigResponse, LoginConfirmRequest, LoginPreflightResponse, LoginRequest, LoginResponse, AuthService (+4 more)

### Community 19 - "Gestione Errori Backend"
Cohesion: 0.13
Nodes (14): ErrorResponse, AppointmentConflictException, GlobalExceptionHandler, Logger, ResponseStatus, PatientNotDeletableException, GlobalExceptionHandlerTest, BeforeEach (+6 more)

### Community 21 - "Analisi AI Radiologica"
Cohesion: 0.12
Nodes (16): GetMapping, AnalysisDto, LabelDto, AnalysisReconciler, Component, JdbcTemplate, Logger, Scheduled (+8 more)

### Community 22 - "Prestazioni (modelli FE)"
Cohesion: 0.11
Nodes (14): AddBundleItemRequest, ConditionDefault, CreateConditionDefaultRequest, CreateServiceCategoryRequest, CreateServiceRequest, ServiceAdmin, ServiceCategory, ServiceItem (+6 more)

### Community 23 - "Piani di Cura (frontend)"
Cohesion: 0.09
Nodes (10): CreatePlanFromOdontogramRequest, OdontogramPlanItem, TreatmentPlan, TreatmentPlanStatus, TreatmentPlanSummary, TreatmentPlanService, Injectable, PianoCuraTabComponent (+2 more)

### Community 24 - "Prescrizioni (API)"
Cohesion: 0.12
Nodes (15): DeleteMapping, GetMapping, PatchMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController (+7 more)

### Community 25 - "Odontogramma (UI)"
Cohesion: 0.08
Nodes (5): ACTIONABLE, genId(), OdontogrammaTabComponent, Component, Input

### Community 26 - "Piani di Cura (API)"
Cohesion: 0.09
Nodes (15): CreatePlanFromOdontogramRequest, DeleteMapping, GetMapping, PatchMapping, PostMapping, RequestMapping, ResponseStatus, RestController (+7 more)

### Community 27 - "Pazienti (modelli FE)"
Cohesion: 0.10
Nodes (7): PatientDetail, PatientListItem, CreatePatientRequest, PatientService, Injectable, PazientiComponent, Component

### Community 28 - "Fornitori (API)"
Cohesion: 0.13
Nodes (15): DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController, SupplierController (+7 more)

### Community 29 - "Anamnesi (frontend)"
Cohesion: 0.09
Nodes (9): AnamnesisCategoryDto, AnamnesisItemDto, SaveAnamnesisRequest, AnamnesisService, Injectable, AnamnesiTabComponent, Component, Input (+1 more)

### Community 30 - "TreatmentItemStatus"
Cohesion: 0.08
Nodes (4): TreatmentItemStatus, TreatmentPlanItem, PianoCuraDetailComponent, Component

### Community 31 - "DiagnosiController"
Cohesion: 0.13
Nodes (14): DiagnosiController, DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController (+6 more)

### Community 32 - "AdminTenantComponent"
Cohesion: 0.10
Nodes (4): AdminTenantComponent, emptyClinicForm(), emptyUserForm(), Component

### Community 33 - "ClinicSettingsController"
Cohesion: 0.13
Nodes (14): ClinicSettingsController, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController, ClinicBillingDto (+6 more)

### Community 34 - "InvoiceDetailDto"
Cohesion: 0.15
Nodes (8): InvoiceDetailDto, InvoiceDto, InvoiceLineDto, InvoiceService, NamedParameterJdbcTemplate, ResultSet, Service, Transactional

### Community 35 - "TreatmentPlanService"
Cohesion: 0.15
Nodes (7): BigDecimalHolder, CreatePlanFromOdontogramRequest, NamedParameterJdbcTemplate, ResultSet, Service, Transactional, TreatmentPlanService

### Community 36 - "Backend Java Wiki services (WikiOcrServi"
Cohesion: 0.10
Nodes (30): Tenant / Clinic — multitenancy domain concept, OCR & Wiki RAG Pipeline for DentalCare (spec breve), GPT-4o dual-task processing (Task A DB extraction, Task B Wiki), Wiki LLM — Progettazione con MinIO Multitenant, Struttura bucket MinIO per-tenant (dc-<schema>), Wiki globale knowledge base (tassonomia, procedure, condizioni), Backend Java Wiki services (WikiOcrService, WikiLlmService, WikiStorageService...), Pipeline OCR → Wiki Markdown → DB sync (+22 more)

### Community 37 - "app"
Cohesion: 0.09
Nodes (10): App, appConfig, Selettore utente/ruolo demo (segreteria/medici), routes, Component, HostListener, authInterceptor(), LayoutService (+2 more)

### Community 39 - "AnamnesisController"
Cohesion: 0.13
Nodes (15): AnamnesisController, GetMapping, PutMapping, RequestMapping, ResponseEntity, RestController, AnamnesisCategoryDto, AnamnesisItemDto (+7 more)

### Community 40 - "Angular App Shell (index.html) with Odon"
Cohesion: 0.15
Nodes (29): Anamnesis, Clinic, Diagnosis, Document, Patient (Paziente) — domain concept, Prescription, Provider, Tooth (+21 more)

### Community 41 - "appointment.model"
Cohesion: 0.12
Nodes (12): Dashboard, Holiday, CreateAppointmentRequest, DashboardService, Injectable, HolidayService, Injectable, Calendario multi-vista con colonne poltrona e heatmap occupazione (+4 more)

### Community 42 - "RecallContactDto"
Cohesion: 0.17
Nodes (11): RecallContactDto, RecallDto, CreateRecallContactRequest, CreateRecallRequest, GenerateRecallsResponse, NamedParameterJdbcTemplate, ResultSet, Service (+3 more)

### Community 43 - "anamnesis-catalog.model"
Cohesion: 0.14
Nodes (10): CatalogCategory, CatalogItem, CreateCatalogCategoryRequest, CreateCatalogItemRequest, UpdateCatalogCategoryRequest, UpdateCatalogItemRequest, AnamnesisCatalogService, Injectable (+2 more)

### Community 44 - "InvoiceController"
Cohesion: 0.10
Nodes (12): InvoiceController, DeleteMapping, GetMapping, PatchMapping, PostMapping, RequestMapping, ResponseStatus, RestController (+4 more)

### Community 45 - "JwtAuthenticationFilter"
Cohesion: 0.14
Nodes (14): Component, HttpServletResponse, Override, JwtAuthenticationFilter, Component, JwtService, AiInferenceClient, Service (+6 more)

### Community 46 - "Appointment (Appuntamento) — domain conc"
Cohesion: 0.16
Nodes (26): Appointment (Appuntamento) — domain concept, Estimate (Preventivo) — domain concept, Recall, Patient Delete Implementation Plan, Guard FK su 11 tabelle prima del DELETE paziente, Richiami Tab, Dettaglio Visita Screen (Visit Entry Editor), Preventivi List Screen (Estimates) (+18 more)

### Community 47 - "odontogram.model"
Cohesion: 0.09
Nodes (19): SaveOdontogramRequest, ToothCondition, OdontogramService, Injectable, CONDITIONS, POLY, Q1, Q2 (+11 more)

### Community 48 - "PublicController"
Cohesion: 0.14
Nodes (12): GetMapping, Logger, PostMapping, RequestMapping, ResponseEntity, ResponseStatus, RestController, PublicController (+4 more)

### Community 49 - "StockMovementController"
Cohesion: 0.15
Nodes (13): GetMapping, PostMapping, RequestMapping, ResponseStatus, RestController, StockMovementController, CreateStockMovementRequest, StockMovementDto (+5 more)

### Community 50 - "ai-prompt.model"
Cohesion: 0.12
Nodes (7): AiPrompt, AiPromptLocale, UpdateAiPromptRequest, AiPromptService, Injectable, AiPromptsComponent, Component

### Community 51 - "provider.model"
Cohesion: 0.13
Nodes (7): CreateProviderRequest, Provider, UpdateProviderProfileRequest, ProviderService, Injectable, notWeekendValidator(), Autocomplete ricerca paziente (CF/telefono in anteprima)

### Community 52 - "admin-tenant.component"
Cohesion: 0.14
Nodes (8): AVAILABLE_ROLES, Gestione utenti per studio (creazione, ruoli), CreateTenantClinicRequest, CreateTenantUserRequest, TenantClinicDto, TenantUserDto, AdminTenantService, Injectable

### Community 54 - "PatientDocumentAnalysisController"
Cohesion: 0.12
Nodes (14): PostMapping, PutMapping, RequestMapping, ResponseStatus, RestController, ReviewAnalysisRequest, SseEmitter, StartAnalysisResponse (+6 more)

### Community 55 - "PatientController"
Cohesion: 0.18
Nodes (6): PatientDetailDto, PatientListDto, NamedParameterJdbcTemplate, ResultSet, Service, PatientService

### Community 56 - "estimate.model"
Cohesion: 0.14
Nodes (6): Estimate, EstimateDetail, EstimateLine, PlanItemCoverage, EstimateService, Injectable

### Community 58 - "CLAUDE.md — Istruzioni Operative Progett"
Cohesion: 0.11
Nodes (23): Communication Style Directive ("caveman" style), DTO/Entity Separation Principle, GlobalExceptionHandler (@RestControllerAdvice pattern), JWT Auth + Roles (ROLE_ADMIN/ROLE_USER/ROLE_MANAGER, 401 vs 403), Layered Architecture (Controller→Service→Repository→Database), Locale IT Registration (avoids NG0701), CLAUDE.md — Istruzioni Operative Progetto DentalCare, Three-Column Layout (LayoutService right panel) (+15 more)

### Community 59 - "DocumentiTabComponent"
Cohesion: 0.11
Nodes (3): DocumentiTabComponent, Component, Input

### Community 61 - "LoginConfirmRequest"
Cohesion: 0.16
Nodes (10): LoginConfirmRequest, LoginRequest, AuthService, JdbcTemplate, Logger, LoginResponse, NamedParameterJdbcTemplate, PasswordEncoder (+2 more)

### Community 62 - "RecallController"
Cohesion: 0.12
Nodes (12): CreateRecallContactRequest, CreateRecallRequest, DeleteMapping, GenerateRecallsResponse, GetMapping, PostMapping, PutMapping, RequestMapping (+4 more)

### Community 64 - "onnx_yolo"
Cohesion: 0.13
Nodes (13): OnnxYoloDetector, ndarray, letterbox(), ndarray, to_model_input(), test_is_loaded_false_for_missing_file(), test_output_shape_logged_only_once(), test_predict_maps_class_names() (+5 more)

### Community 66 - "DashboardController"
Cohesion: 0.16
Nodes (8): DashboardController, GetMapping, RequestMapping, RestController, DashboardDto, DashboardService, NamedParameterJdbcTemplate, Service

### Community 67 - "OdontogramController"
Cohesion: 0.15
Nodes (12): GetMapping, PutMapping, RequestMapping, ResponseStatus, RestController, OdontogramController, SaveOdontogramRequest, ToothConditionDto (+4 more)

### Community 68 - "PatientDocumentService"
Cohesion: 0.27
Nodes (6): PatientDocumentSummaryDto, MultipartFile, NamedParameterJdbcTemplate, Service, Transactional, PatientDocumentService

### Community 69 - "invoice.model"
Cohesion: 0.16
Nodes (5): Invoice, InvoiceDetail, InvoiceLine, InvoiceService, Injectable

### Community 70 - "Retell.io phone agent integration"
Cohesion: 0.13
Nodes (19): AI Copilot / SegretarIA assistant — domain concept, SegretarIA — Architettura tecnica multitenant AI, Audit log e tracciabilità richieste AI, n8n workflow integration, Rationale: l'AI non deve mai accedere direttamente al database, RBAC + ABAC authorization model, Retell.io phone agent integration, PostgreSQL Row Level Security (isolamento tenant) (+11 more)

### Community 71 - "patient-document.model"
Cohesion: 0.20
Nodes (5): DOCUMENT_TYPE_LABELS, PatientDocumentSummary, UpdatePatientDocumentRequest, PatientDocumentService, Injectable

### Community 72 - "copilot-context.service"
Cohesion: 0.12
Nodes (7): RescheduleAppointmentRequest, CopilotContextService, Injectable, UpdatePatientRequest, fiscalCodeValidator(), NuovoPazienteComponent, Component

### Community 77 - "CartellaClinicalTabComponent"
Cohesion: 0.11
Nodes (4): CartellaClinicalTabComponent, Component, Input, Output

### Community 78 - "chat.system.en.txt — SegretarIA System P"
Cohesion: 0.16
Nodes (18): Mandatory getAppointments-first Rule (no UUID reuse), Clinical Disclaimer (AI is decision support, not diagnosis), Preview → Confirmation Code → confirmAction Pattern, chat.system.en.txt — SegretarIA System Prompt (EN), chat.system.it.txt — SegretarIA System Prompt (IT), Proposta #17 — Prompt Manager AI (multilingua editabile), Proposta #9 — Isolamento chat per utente (hardening IDOR), SegretarIA Chat AI Tool List (Spring AI @Tool) (+10 more)

### Community 79 - "EncryptionMigrationController"
Cohesion: 0.21
Nodes (9): EncryptionMigrationController, PostMapping, RequestMapping, RestController, EncryptionMigrationService, NamedParameterJdbcTemplate, Service, Transactional (+1 more)

### Community 80 - "HolidayController"
Cohesion: 0.20
Nodes (10): HolidayController, GetMapping, RequestMapping, RestController, HolidayDto, HolidayService, NamedParameterJdbcTemplate, Service (+2 more)

### Community 81 - "PatientDocumentController"
Cohesion: 0.14
Nodes (10): DeleteMapping, GetMapping, MultipartFile, PostMapping, PutMapping, RequestMapping, ResponseEntity, ResponseStatus (+2 more)

### Community 82 - "OdontogramSyncServiceTest"
Cohesion: 0.16
Nodes (8): AfterEach, BeforeEach, NamedParameterJdbcTemplate, Test, OdontogramSyncServiceTest, BeforeEach, BeforeEach, BeforeEach

### Community 83 - "CopilotSuggestionService"
Cohesion: 0.23
Nodes (8): CopilotSuggestionService, Component, Logger, ObjectMapper, SseEmitter, SuggestionPayload, CopilotSuggestionServiceTest, Test

### Community 84 - "wiki_llm_minio_architecture.md (external"
Cohesion: 0.29
Nodes (18): Feature-to-Documentation Mapping, wiki_llm_minio_architecture.md (external reference), Proposte di Modifica — Registro Tracking, Proposta #10 — Da SegretarIA a DentalCare AI Copilot (roadmap a fasi), Proposta #11 — Rinomina UI Segreteria AI → Copilot AI, Proposta #12 — CRUD anagrafiche per-tenant (prestazioni/anamnesi/magazzino), Proposta #13 — Copilot operativo (scrittura sui moduli), Proposta #14 — Copilot contestuale e proattivo (+10 more)

### Community 85 - "odontogramma-tab.component"
Cohesion: 0.11
Nodes (17): CONDITION_TREATMENT_HINT, CONDITIONS, PianificaItem, POLY, Q1, Q2, Q3, Q4 (+9 more)

### Community 86 - "Roadmap Release 1.x-5.x"
Cohesion: 0.20
Nodes (18): SegretarIA / Copilot AI Chat Screen (App), AI Copilot Governance, AI Radiology (YOLO/Dentex), DentalCare Pro — Documento di Progetto, Roadmap e Architettura, GDPR Encryption e Compliance (#7), Architettura Multitenant, Pipeline OCR/LLM (Wiki Worker), RAG e Memoria Clinica (Roadmap) (+10 more)

### Community 88 - "TenantSchemaRegistry"
Cohesion: 0.19
Nodes (9): Component, Logger, NamedParameterJdbcTemplate, PostConstruct, TenantSchemaRegistry, CopilotSuggestionScheduler, Component, Logger (+1 more)

### Community 89 - "DocumentEncryptionService"
Cohesion: 0.20
Nodes (6): DocumentEncryptionService, Logger, PostConstruct, Service, MinioStorageService, S3Client

### Community 90 - "config"
Cohesion: 0.19
Nodes (9): BaseSettings, Settings, InferenceJobRequest, JobService, Read the job index JSON. `bucket` must be the job's output_bucket., _req(), test_run_job_failure_sets_failed_status(), test_run_job_writes_result_and_calls_callback() (+1 more)

### Community 91 - "schematics"
Cohesion: 0.12
Nodes (17): schematics, skipTests, skipTests, skipTests, skipTests, skipTests, skipTests, skipTests (+9 more)

### Community 92 - "patient-analysis.model"
Cohesion: 0.26
Nodes (8): AnalysisLabel, DISEASE_LABELS, PatientAnalysis, quadrantColor(), ReviewAnalysisRequest, StartAnalysisResponse, PatientAnalysisService, Injectable

### Community 93 - "CreateProductCategoryRequest"
Cohesion: 0.23
Nodes (5): AfterEach, ExtendWith, NamedParameterJdbcTemplate, Test, ProductCategoryServiceTest

### Community 94 - "PatientDocumentSummaryDto"
Cohesion: 0.21
Nodes (6): UpdatePatientDocumentRequest, AfterEach, ExtendWith, NamedParameterJdbcTemplate, Test, PatientDocumentServiceTest

### Community 95 - "annotations"
Cohesion: 0.19
Nodes (11): BackgroundTasks, BaseModel, save_annotations(), create_job(), get_job(), AnnotationRequest, DetectionOut, JobCreatedResponse (+3 more)

### Community 96 - "main"
Cohesion: 0.18
Nodes (9): _auth(), test_annotations_saves_and_returns_keys(), test_annotations_unknown_study_id(), test_retraining_stub_returns_501(), _auth(), test_create_job_returns_queued(), test_get_job_404_on_missing_object(), test_get_job_missing_result_bucket_422() (+1 more)

### Community 97 - "prescrizione.model"
Cohesion: 0.25
Nodes (5): CreatePrescrizioneRequest, Prescrizione, UpdatePrescrizioneRequest, PrescrizioneService, Injectable

### Community 98 - "dentex_disease_v1.onnx (Impacted/Caries/"
Cohesion: 0.23
Nodes (15): dentex_disease_v1.onnx (Impacted/Caries/Periapical/Deep_Caries), dentex_fdi_v1.onnx (32 FDI tooth classes), AI Service Docker/Compose Deployment (CPU/GPU), IoU + Center-Fallback Matching (FDI ↔ disease boxes), AI Service JWT Bearer Verification, MinIO Client (download/upload/upload_json/object_exists), OnnxYoloDetector class, dentalcare-ai-service README (+7 more)

### Community 99 - "AiJobRequest"
Cohesion: 0.22
Nodes (7): AiJobRequest, SuppressWarnings, AiInferenceClientTest, AfterEach, BeforeEach, Test, MockWebServer

### Community 100 - "EncryptionException"
Cohesion: 0.22
Nodes (6): EncryptionException, MasterKeyProvider, SecureRandom, Service, TenantEncryptionService, SecretKeySpec

### Community 101 - "ConfigMasterKeyProvider"
Cohesion: 0.20
Nodes (6): ConfigMasterKeyProvider, Component, Override, ConfigMasterKeyProviderTest, Test, ConditionalOnProperty

### Community 103 - "EncryptionMigrationServiceTest"
Cohesion: 0.24
Nodes (7): EncryptionMigrationServiceTest, AfterEach, BeforeEach, ExtendWith, NamedParameterJdbcTemplate, SuppressWarnings, Test

### Community 104 - "retraining"
Cohesion: 0.26
Nodes (11): decode_token(), require_jwt(), test_alg_none_rejected(), test_decode_expired_token_raises_401(), test_decode_valid_token_all_hmac_algorithms(), test_decode_valid_token_returns_claims(), test_decode_wrong_secret_raises_401(), test_require_jwt_missing_header_raises_401() (+3 more)

### Community 105 - "clinic-billing.model"
Cohesion: 0.19
Nodes (5): ClinicBilling, AppSettingsService, Injectable, ClinicSettingsService, Injectable

### Community 106 - "clinical-record.model"
Cohesion: 0.28
Nodes (5): ClinicalHistoryEntry, OdontogramSummary, TreatmentPlanSummary, ClinicalRecordService, Injectable

### Community 107 - "role.guard"
Cohesion: 0.20
Nodes (7): categorize(), defaultRoute(), roleGuard(), RouteRole, MEDICAL_JWT_ROLES, Injectable, UserContextService

### Community 108 - "diagnosi.model"
Cohesion: 0.30
Nodes (4): CreateDiagnosiRequest, Diagnosi, DiagnosiService, Injectable

### Community 109 - "AiCallbackController"
Cohesion: 0.23
Nodes (8): AiCallbackController, ObjectMapper, PostMapping, RequestMapping, ResponseEntity, RestController, HmacVerifier, Component

### Community 112 - "SecurityConfig"
Cohesion: 0.28
Nodes (8): Bean, Configuration, PasswordEncoder, SecurityConfig, CorsConfigurationSource, EnableWebSecurity, HttpSecurity, SecurityFilterChain

### Community 113 - "CopilotSuggestionSchedulerTest"
Cohesion: 0.36
Nodes (4): CopilotSuggestionSchedulerTest, AfterEach, ExtendWith, Test

### Community 114 - "NoOpDocumentEncryptionService"
Cohesion: 0.24
Nodes (5): Override, Service, NoOpDocumentEncryptionService, Test, MinioStorageServiceBucketTest

### Community 115 - "PatientServiceTest"
Cohesion: 0.24
Nodes (8): AfterEach, BeforeEach, ExtendWith, NamedParameterJdbcTemplate, PatientService, SuppressWarnings, Test, PatientServiceTest

### Community 116 - "minio_client"
Cohesion: 0.28
Nodes (9): get_settings(), get_minio(), health(), models_status(), get_disease_detector(), get_fdi_detector(), get_job_service(), main() (+1 more)

### Community 117 - "visualization"
Cohesion: 0.26
Nodes (11): draw_detections(), ndarray, quadrant_color(), test_draw_detections_accepts_numpy_int_bbox(), test_draw_detections_null_tooth_annotates(), test_draw_detections_returns_same_shape_copy(), test_quadrant_color_null_is_grey(), test_quadrant_color_q1_green_bgr() (+3 more)

### Community 119 - "DocumentoAnalisiComponent"
Cohesion: 0.21
Nodes (3): DocumentoAnalisiComponent, Component, Input

### Community 120 - "AiCallbackRequest"
Cohesion: 0.32
Nodes (6): AiCallbackRequest, Detection, AfterEach, NamedParameterJdbcTemplate, Test, PatientDocumentAnalysisServiceTest

### Community 121 - "SseEmitterRegistry"
Cohesion: 0.32
Nodes (6): Component, Logger, SseEmitter, SseEmitterRegistry, Test, SseEmitterRegistryTest

### Community 122 - "postprocessing"
Cohesion: 0.27
Nodes (10): iou_xyxy(), nms(), parse_yolo_output(), ndarray, test_iou_disjoint_boxes_is_zero(), test_iou_identical_boxes_is_one(), test_nms_drops_overlapping_lower_score(), test_parse_yolo_output_applies_padding() (+2 more)

### Community 123 - "test_minio_client"
Cohesion: 0.24
Nodes (5): MinioClient, _client_with_mock(), test_object_exists_false_when_stat_raises(), test_object_exists_true_when_stat_succeeds(), test_upload_json_puts_object_with_json_content_type()

### Community 124 - "docker-compose.yml (backend+frontend, si"
Cohesion: 0.24
Nodes (12): Procedure Deploy — trigger "deploy in produzione"/"lavoriamo in dev", Trigger "lavoriamo in dev" Procedure, Trigger "deploy in produzione" Procedure, docker-compose.yml (backend+frontend, single file), install.sh (Docker deploy script), database/install.sql (parametric master installer), setup.sh (bootstrap script), Demo Tenant t_9d754153 (+4 more)

### Community 126 - "install.sh"
Cohesion: 0.24
Nodes (8): err(), log(), install.sh script, warn(), err(), log(), setup.sh script, update.sh script

### Community 127 - "P2 Implementation Plan (#12.C, #3, #14)"
Cohesion: 0.31
Nodes (11): Invoice (Fattura) — domain concept, P2 Implementation Plan (#12.C, #3, #14), #3 Validazione codice fiscale (@ValidFiscalCode) + flag paziente straniero, #12.C CRUD categorie prodotto magazzino, GDPR Cifratura — Slice 1 (birth_date) Implementation Plan, GDPR Slice 2a — cifratura fiscal_code paziente — Implementation Plan, GDPR — Cifratura campo-per-campo con chiavi per-tenant (#7) — Design, MasterKeyProvider seam (Config ora, Vault futuro) (+3 more)

### Community 128 - "callback"
Cohesion: 0.29
Nodes (8): send_callback(), sign_body(), log_event(), setup_logging(), test_send_callback_posts_with_signature(), test_send_callback_returns_false_after_retries(), test_send_callback_returns_false_on_persistent_500(), test_sign_body_matches_hmac_sha256()

### Community 129 - "serve"
Cohesion: 0.18
Nodes (11): serve, development, buildTarget, extractLicenses, optimization, sourceMap, proxyConfig, builder (+3 more)

### Community 132 - "registrazione.component"
Cohesion: 0.18
Nodes (5): AdminForm, PlanType, RegistrazioneComponent, StudioForm, Component

### Community 133 - "mvnw"
Cohesion: 0.33
Nodes (6): mvnw script, clean(), die(), exec_maven(), set_java_home(), verbose()

### Community 134 - "AuthController"
Cohesion: 0.22
Nodes (6): AuthController, PostMapping, RequestMapping, ResponseStatus, RestController, ChangePasswordRequest

### Community 135 - "ClinicOption"
Cohesion: 0.31
Nodes (4): ClinicOption, JsonInclude, LoginPreflightResponse, Match

### Community 137 - "NuovoAppuntamentoComponent"
Cohesion: 0.20
Nodes (3): NuovoAppuntamentoComponent, Component, ViewChild

### Community 138 - "build_workflow"
Cohesion: 0.33
Nodes (8): auth_header(), http_tool(), make_login_node(), make_service_key_node(), orig_copy(), orig_node(), Set node — user changes SERVICE_KEY_PLACEHOLDER with the actual secret once., uid()

### Community 140 - "AiAuditService"
Cohesion: 0.36
Nodes (4): AiAuditService, Logger, NamedParameterJdbcTemplate, Service

### Community 141 - "ToolLayerService"
Cohesion: 0.44
Nodes (3): Service, Transactional, ToolLayerService

### Community 142 - "pipeline"
Cohesion: 0.47
Nodes (7): _center_inside(), match_detections(), _dis(), _fdi(), test_match_by_center_fallback_when_iou_low(), test_match_by_iou_assigns_tooth(), test_no_match_sets_needs_review()

### Community 143 - "FlywayConfig"
Cohesion: 0.43
Nodes (6): FlywayConfig, ApplicationRunner, Bean, Configuration, Logger, DataSource

### Community 144 - "CopilotController"
Cohesion: 0.39
Nodes (5): CopilotController, GetMapping, RequestMapping, RestController, SseEmitter

### Community 146 - "Master Key Fail-Fast Prerequisite (befor"
Cohesion: 0.39
Nodes (8): Master Key Fail-Fast Prerequisite (before deploy), GDPR Slice 1 Migration Procedure (backup→key→deploy→migrate→verify), GDPR Slice 1 Rollback Procedure, Deploy Prod — GDPR Slice 1 Runbook (#7), ConfigMasterKeyProvider (fail-fast MasterKeyProvider seam), POST /api/admin/encryption/migrate (idempotent, tenant-scoped), Proposta #7 — GDPR cifratura per-tenant (HKDF+AES-256-GCM), TenantEncryptionService (HKDF-SHA256 → AES-256-GCM + blind index)

### Community 147 - "angular"
Cohesion: 0.25
Nodes (7): cli, analytics, packageManager, newProjectRoot, projects, $schema, version

### Community 149 - "DentalcareApiApplicationTests"
Cohesion: 0.48
Nodes (5): ActiveProfiles, DentalcareApiApplicationTests, Test, Disabled, SpringBootTest

### Community 150 - "PatientService.findAll/findById visibili"
Cohesion: 0.43
Nodes (7): Minimal FE Fix Proposal (confirm() dialog on provider change), PatientService.findAll/findById visibility filter, paziente-detail.component.saveAnagrafica, Self-Lockout Risk (doctor loses patient visibility), primary_provider_id Visibility Model, Multitenancy Pattern (tenant_id / schema-per-tenant), Analisi Impatto — Cambio Medico di Riferimento (FIX #2)

### Community 151 - "ReviewAnalysisRequest"
Cohesion: 0.43
Nodes (3): ReviewAnalysisRequest, Test, PatientDocumentAnalysisControllerTest

### Community 152 - "segretaria_architettura_multitenant_ai.m"
Cohesion: 0.33
Nodes (6): AI-First Cloud-Native Positioning Strategy, Go-to-Market 4-Phase Sequence, SaaS Pricing Tiers (Base/Pro/Enterprise/Add-on AI), MDR/CE Regulatory Risk for AI Radiographic Module, Analisi di Mercato e Strategia di Vendita — DentalCare Pro, segretaria_architettura_multitenant_ai.md (external reference)

### Community 153 - "DentalcareApiApplication"
Cohesion: 0.53
Nodes (4): DentalcareApiApplication, ComponentScan, EnableScheduling, SpringBootApplication

### Community 154 - "HomeController"
Cohesion: 0.53
Nodes (3): HomeController, GetMapping, RestController

### Community 155 - "src/styles.css"
Cohesion: 0.33
Nodes (6): options, assets, browser, styles, tsConfig, src/styles.css

### Community 158 - "landing.component"
Cohesion: 0.33
Nodes (3): LandingComponent, Component, HostListener

### Community 159 - "Lombok 1.18.40 dependency"
Cohesion: 0.70
Nodes (5): Lombok Java 25 Upgrade Summary, Java 25 Upgrade, Lombok 1.18.40 dependency, maven-compiler-plugin config (annotationProcessorPaths), sun.misc.Unsafe Deprecation Warning (Lombok annotation processor)

### Community 160 - "DemoConfigResponse"
Cohesion: 0.50
Nodes (3): DemoConfigResponse, JsonInclude, DemoConfigResponse

### Community 161 - "Sistema AI di Revisione Radiografica — D"
Cohesion: 0.60
Nodes (5): Sistema AI di Revisione Radiografica — Design Doc, Dual-Engine Architecture (YOLO Detector + Claude Reasoner), Ciclo A — Prompt Evolution (few-shot update), Ciclo B — Retraining Detector (YOLO/SAM periodico), Radiographic Review DB Schema (ai_finding/doctor_review/model_version)

### Community 162 - "build"
Cohesion: 0.40
Nodes (5): build, builder, configurations, defaultConfiguration, architect

### Community 163 - "production"
Cohesion: 0.40
Nodes (5): production, budgets, buildTarget, fileReplacements, outputHashing

### Community 164 - "prefix"
Cohesion: 0.40
Nodes (5): prefix, projectType, root, sourceRoot, dentalcare-frontend

## Ambiguous Edges - Review These
- `MinioWikiListener Python worker` → `dentalcare-ai-service container`  [AMBIGUOUS]
  directives/wiki_llm_minio_architecture.md · relation: conceptually_related_to
- `AI Copilot / SegretarIA assistant — domain concept` → `ai-den-secretary.png (src/assets) – Content Mismatch: Renaissance-era Portrait, Unrelated to Dental/AI Theme`  [AMBIGUOUS]
  frontend/src/assets/ai-den-secretary.png · relation: conceptually_related_to
- `Login` → `Provider`  [AMBIGUOUS]
  frontend/src/app/features/login/login.component.html · relation: conceptually_related_to
- `AI Secretary Hologram – Dental Reception Desk Visual` → `ai-den-secretary.png (src/assets) – Content Mismatch: Renaissance-era Portrait, Unrelated to Dental/AI Theme`  [AMBIGUOUS]
  frontend/public/ai-den-secretary.png · relation: semantically_similar_to

## Knowledge Gaps
- **166 isolated node(s):** `com.dentalcare:dentalcare-api`, `TenantAspect`, `CreateCatalogCategoryRequest`, `CreateCatalogItemRequest`, `CreateRecallContactRequest` (+161 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **41 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `MinioWikiListener Python worker` and `dentalcare-ai-service container`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `AI Copilot / SegretarIA assistant — domain concept` and `ai-den-secretary.png (src/assets) – Content Mismatch: Renaissance-era Portrait, Unrelated to Dental/AI Theme`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Login` and `Provider`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `AI Secretary Hologram – Dental Reception Desk Visual` and `ai-den-secretary.png (src/assets) – Content Mismatch: Renaissance-era Portrait, Unrelated to Dental/AI Theme`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **Why does `DentalCareAiTools` connect `DTO Preventivi e Richiami` to `DashboardController`, `InvoiceDetailDto`, `OdontogramController`, `Gestione Provider (API)`, `Catalogo Prestazioni (API)`, `Appuntamenti (API)`, `Prompt Manager AI (API)`, `AnamnesisController`, `Preventivi (API)`, `RecallContactDto`, `AiAuditService`, `Prodotti Magazzino (API)`, `Cartella Clinica (API)`, `TreatmentPlanService`, `PatientController`, `Prescrizioni (API)`, `DiagnosiController`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `environment` connect `appointment.model` to `Magazzino (modelli FE)`, `Richiami (modelli FE)`, `Chat Copilot (frontend)`, `Routing e Autenticazione FE`, `Prestazioni (modelli FE)`, `Piani di Cura (frontend)`, `Pazienti (modelli FE)`, `anamnesis-catalog.model`, `odontogram.model`, `ai-prompt.model`, `provider.model`, `admin-tenant.component`, `estimate.model`, `invoice.model`, `patient-document.model`, `patient-analysis.model`, `prescrizione.model`, `clinic-billing.model`, `clinical-record.model`, `diagnosi.model`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `AuthService` connect `LoginConfirmRequest` to `DemoConfigResponse`, `Bootstrap Dati Demo`, `TreatmentPlanService`, `AuthController`, `ClinicOption`, `JwtAuthenticationFilter`, `PublicController`, `TenantSchemaRegistry`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._