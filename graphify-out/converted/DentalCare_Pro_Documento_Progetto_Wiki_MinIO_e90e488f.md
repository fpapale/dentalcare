<!-- converted from DentalCare_Pro_Documento_Progetto_Wiki_MinIO.docx -->

DentalCare Pro
Documento di Progetto, Roadmap e Architettura
Con approfondimento su Wiki Knowledge Base implementata in MinIO




# Indice ragionato
- 1. Sintesi esecutiva
- 2. Visione del progetto e razionale di mercato
- 3. Ambito funzionale della piattaforma
- 4. Stato attuale e roadmap di rilascio
- 5. Architettura applicativa e componenti principali
- 6. Wiki Knowledge Base su MinIO
- 7. Pipeline OCR, LLM e sincronizzazione dati
- 8. RAG, memoria clinica e ricerca semantica
- 9. Sicurezza, privacy e compliance GDPR
- 10. DevOps, deployment e ambienti
- 11. Piano di implementazione operativo
- 12. Rischi, dipendenze e mitigazioni
- 13. Governance documentale e allineamento GitHub
- 14. Conclusioni e prossimi passi
# 1. Sintesi esecutiva
DentalCare Pro è una piattaforma AI-native per studi odontoiatrici pensata per unificare gestione operativa, automazione intelligente, documentazione clinica, analisi radiologica e knowledge management. Il progetto parte da un nucleo già implementato in ambiente di sviluppo e lo estende verso una soluzione scalabile, multi-tenant, compliance-ready e predisposta alla vendita a studi o reti odontoiatriche.
L’allegato fornito mappa la documentazione GitHub DentalCare-Documentation con le feature implementate o proposte nel repository locale dentalcare. Da tale mapping emerge che la Release 1.x, corrispondente alla fase P1, risulta sostanzialmente completata in sviluppo, mentre le fasi successive introducono funzioni più avanzate: compliance GDPR, Wiki Knowledge Base, RAG, supporto DICOM nativo, multistudio e copilot contestuale.


# 2. Visione del progetto e razionale di mercato
## 2.1 Visione prodotto
La visione di DentalCare Pro è costruire una piattaforma gestionale evoluta per studi odontoiatrici, capace di integrare in un unico ambiente funzioni tradizionali di practice management e capacità AI di nuova generazione. Il prodotto non deve essere percepito come un semplice gestionale con chatbot, ma come un sistema operativo clinico-amministrativo in grado di comprendere documenti, immagini, conversazioni, agenda e dati di studio.
- AI-native by design: l’intelligenza artificiale non è un componente accessorio, ma un livello trasversale che aiuta operatori, medici e amministratori.
- Multitenancy nativo: ogni studio deve essere isolato a livello dati, configurazioni, storage e permessi.
- Knowledge-first: la documentazione clinica e amministrativa deve diventare conoscenza strutturata e recuperabile.
- Compliance-ready: audit, consenso, cifratura e separazione dei dati devono essere previsti fin dalle prime release commerciali.
- Estendibilità: la piattaforma deve supportare moduli futuri come DICOM, RAG avanzato, memoria clinica, BI e integrazioni esterne.
## 2.2 Problemi che il progetto risolve

## 2.3 Posizionamento atteso
Il posizionamento consigliato è quello di una piattaforma verticale per il settore odontoiatrico, focalizzata inizialmente su studi singoli o piccoli network, con possibilità di espansione verso strutture multi-sede. Il vantaggio competitivo non deriva solo dal gestionale, ma dalla combinazione fra:
- automazione operativa su agenda e moduli;
- AI Copilot con azioni controllate e auditabili;
- Voice Agent integrato nei flussi di studio;
- analisi radiologica assistita;
- Wiki clinica su MinIO con potenziale RAG;
- architettura multi-tenant predisposta alla compliance.
# 3. Ambito funzionale della piattaforma
## 3.1 Macro-moduli funzionali

## 3.2 Funzionalità P1 già consolidate in sviluppo
- CRUD prestazioni, prezzi e bundle: consente allo studio di modellare il listino e le prestazioni in modo strutturato.
- Agenda realtime: abilita un’esperienza utente coerente in presenza di più operatori o aggiornamenti concorrenti.
- Copilot governance: introduce disclaimer, gating e audit delle azioni AI, riducendo il rischio operativo.
- Copilot operativo: permette al Copilot di assistere l’operatore nella compilazione o modifica controllata di moduli.
- Prompt management multilingua: separa i prompt dal codice e consente configurazione evolutiva IT/EN.
## 3.3 Funzionalità evolutive
Le funzionalità evolutive proposte devono essere considerate non come moduli isolati, ma come progressiva costruzione di un ecosistema AI e compliance. La Wiki Knowledge Base su MinIO, ad esempio, diventa il presupposto naturale per il RAG, mentre la cifratura GDPR rappresenta un prerequisito trasversale per l’adozione commerciale.

# 4. Stato attuale e roadmap di rilascio
Il mapping allegato organizza il progetto secondo una logica Release 1.x-5.x, collegata alle fasi P1, P2, P3 e Future. Questa impostazione è utile perché separa ciò che è già pronto per deployment da ciò che richiede decisioni architetturali o di compliance.

## 4.1 Criterio di priorità pianificato
- Portare in produzione P1: validare build, migrazioni, configurazioni, sicurezza minima e test end-to-end.
- Anticipare GDPR se c’è vendita reale: la cifratura e l’audit diventano prerequisiti, non feature opzionali.
- Progettare Wiki MinIO prima del RAG: senza un repository documentale strutturato, il RAG rischia di essere fragile.
- Rinviare DICOM nativo a dopo stabilizzazione AI service: l’inferenza su immagini esportate può essere sufficiente per la fase iniziale.
- Evitare over-engineering: Qdrant/pgvector e memoria avanzata vanno introdotti solo dopo aver stabilizzato Markdown, indici e chunk.
## 4.2 Definition of Done per Release 1.x

# 5. Architettura applicativa e componenti principali
## 5.1 Visione architetturale
L’architettura di DentalCare Pro è organizzata a livelli: frontend Angular, backend Spring Boot, database PostgreSQL multi-tenant, storage MinIO, servizi AI specializzati e orchestrazioni n8n/Retell. L’obiettivo è mantenere il core gestionale stabile, mentre le capacità AI e documentali vengono estese tramite servizi separati e integrabili.
[ Angular 17 Frontend ]
        | REST / SSE / JWT
[ Spring Boot 3 Backend ] ---- [ PostgreSQL multi-tenant ]
        |
        +---- [ MinIO: raw docs, images, wiki, chunks ]
        |
        +---- [ AI Service: radiology / inference / callbacks ]
        |
        +---- [ Wiki Worker: OCR -> LLM -> Markdown -> MinIO ]
        |
        +---- [ n8n / Retell: voice agent and workflow automation ]
        |
        +---- [ OpenAI / LLM provider: copilot, extraction, summarization ]
## 5.2 Componenti principali

## 5.3 Backend architecture
- Controller REST: espongono API tipizzate e validate, senza far filtrare entity JPA al frontend.
- Service layer: contiene logica applicativa, transazioni, validazioni e orchestrazione fra repository, storage e servizi esterni.
- Repository layer: gestisce persistenza tramite JPA, query derivate o @Query quando necessario.
- DTO e mapper: separano il contratto API dal modello di persistenza.
- Error handling: centralizzato tramite @RestControllerAdvice e messaggi coerenti per frontend.
- TenantContext: assicura che ogni chiamata operi nel contesto corretto di studio/tenant.
## 5.4 Frontend architecture
- core/: servizi trasversali, guard, interceptor, configurazioni.
- shared/: componenti, pipe, direttive e modelli riutilizzabili.
- features/: moduli funzionali separati: agenda, pazienti, prestazioni, impostazioni, copilot.
- layout/: struttura applicativa, pannelli laterali, KPI e shell utente.
- Reactive Forms: validazioni e gestione stato dei form più robuste rispetto ai template-driven forms.
## 5.5 Multitenancy
L’isolamento multi-tenant viene mantenuto su tre livelli: database, storage e applicazione. Il database usa schemi separati o filtri tenant-aware; MinIO usa bucket/prefix segregati; il backend propaga il TenantContext verso repository e servizi storage.

# 6. Wiki Knowledge Base su MinIO
## 6.1 Obiettivo della Wiki
La Wiki Knowledge Base ha l’obiettivo di trasformare documenti clinici e amministrativi caricati su DentalCare in pagine Markdown strutturate, versionate e collegate al paziente. Questa Wiki non deve essere un semplice export testuale: deve diventare il repository canonico della conoscenza documentale, utilizzabile da operatori, medici, Copilot e futuri servizi RAG.

## 6.2 Struttura bucket progettata
La struttura progettata prevede la separazione fra documenti originali, Wiki generata e file di processo. Questa separazione riduce il rischio di loop di processamento e facilita policy diverse per raw data, output generati ed errori.
dental-records/
  raw/
    {tenant_id}/
      {patient_id}/
        {document_id}/
          original.pdf
          metadata.json

dental-wiki/
  patients/
    {tenant_id}/
      {patient_id}/
        index.md
        index.json
        documents/
          {document_id}.md
        chunks/
          {document_id}/
            chunk-0001.json
            chunk-0002.json
        versions/
          {document_id}/
            {timestamp}.md

dental-processing/
  failed/
  logs/
  tmp/

## 6.3 File Wiki per paziente
Ogni paziente deve avere una pagina indice e una pagina per ciascun documento processato. L’indice paziente deve fungere da punto di accesso umano e applicativo, mentre index.json deve essere usato per sincronizzazioni, UI e ricerca programmatica.
dental-wiki/patients/{tenant_id}/{patient_id}/index.md
dental-wiki/patients/{tenant_id}/{patient_id}/index.json
dental-wiki/patients/{tenant_id}/{patient_id}/documents/{document_id}.md
## 6.4 Template Markdown standard
---
tenant_id: "tenant-demo"
patient_id: "P12345"
patient_name: "Mario Rossi"
document_id: "DOC-2026-0001"
source_object: "s3://dental-records/raw/tenant-demo/P12345/DOC-2026-0001/original.pdf"
created_at: "2026-07-03T10:30:00Z"
exam_date: "2026-06-28"
exam_type: "Ortopanoramica"
language: "it"
status: "processed"
confidence: 0.87
---

# Mario Rossi - 2026-06-28

## Summary
Sintesi clinica generata dal sistema.

## Clinical Findings
- Evidenza clinica 1
- Evidenza clinica 2

## Actions / Treatment Plan
- Azione consigliata 1
- Azione consigliata 2

## Source Document
- MinIO object: s3://dental-records/.../original.pdf

## Raw Extracted Text
Testo estratto oppure riferimento a oggetto raw-extraction.txt.
## 6.5 Perché Markdown in MinIO

# 7. Pipeline OCR, LLM e sincronizzazione dati
## 7.1 Workflow end-to-end
- Upload documento: il backend o una procedura batch carica il documento originale in dental-records/raw.
- Evento MinIO: il worker riceve un evento s3: ObjectCreated e verifica che l’oggetto sia processabile.
- Download temporaneo: il file viene scaricato in una directory locale effimera per OCR/conversione.
- Estrazione testo: PyMuPDF per PDF nativi; Docling per documenti complessi o scansionati; Tesseract come fallback.
- Elaborazione LLM: il testo estratto viene trasformato in JSON strutturato e Markdown Wiki.
- Upload Wiki: il Markdown viene salvato in dental-wiki/patients/.../documents.
- Aggiornamento indice: index.md e index.json del paziente vengono aggiornati.
- Chunking RAG: il Markdown viene suddiviso in chunk JSON pronti per embedding futuro.
- Sync SQL: il database conserva metadati, stato, summary e riferimenti agli oggetti MinIO.
- Cleanup: i file temporanei locali vengono eliminati.
## 7.2 Strategie di estrazione

## 7.3 Output JSON strutturato
{
  "tenant_id": "tenant-demo",
  "patient_id": "P12345",
  "document_id": "DOC-2026-0001",
  "patient_name": "Mario Rossi",
  "exam_date": "2026-06-28",
  "exam_type": "Ortopanoramica",
  "summary": "Sintesi clinica del documento",
  "clinical_findings": ["Finding 1", "Finding 2"],
  "recommended_actions": ["Action 1", "Action 2"],
  "confidence": 0.87,
  "requires_human_review": false
}
## 7.4 Modello dati SQL consigliato

## 7.5 Stati di processo

## 7.6 Pseudocodice del worker
def process_new_document(event):
    source = parse_minio_event(event)

    if not source.key.startswith("raw/"):
        return

    metadata = load_metadata(source)
    mark_status(metadata.document_id, "processing")

    local_file = download_to_tmp(source)

    try:
        text = extract_text(local_file)
        structured = llm_extract_json(text, metadata)
        validate(structured)

        markdown = llm_generate_markdown(text, structured, source)
        wiki_uri = upload_wiki_markdown(markdown, structured)

        update_patient_index(structured, wiki_uri, source.uri)
        chunks = create_chunks(markdown)
        upload_chunks(chunks, structured)

        sync_sql(structured, source.uri, wiki_uri)
        mark_status(metadata.document_id, "processed")

    except LowConfidenceError:
        save_partial_output()
        mark_status(metadata.document_id, "needs_review")

    except Exception as exc:
        save_error_to_minio(metadata, exc)
        mark_status(metadata.document_id, "failed")

    finally:
        cleanup_tmp(local_file)
# 8. RAG, memoria clinica e ricerca semantica
## 8.1 Ruolo della Wiki nel RAG
Il RAG non dovrebbe indicizzare direttamente i PDF originali. Il flusso consigliato è:
documento originale -> testo estratto -> Markdown normalizzato -> chunk semantici -> embedding.
In questo modo il contenuto indicizzato è già pulito, strutturato, collegato al paziente e corredato da metadati clinici.
Original PDF/DOCX
      ↓
Text extraction + OCR
      ↓
LLM normalization
      ↓
Canonical Markdown in MinIO
      ↓
Chunk JSON in MinIO
      ↓
Embedding worker
      ↓
Vector DB: Qdrant / pgvector / OpenSearch
      ↓
Copilot retrieval with tenant and patient filters
## 8.2 Chunk JSON
{
  "tenant_id": "tenant-demo",
  "patient_id": "P12345",
  "document_id": "DOC-2026-0001",
  "chunk_id": "chunk-0001",
  "source_wiki_object": "s3://dental-wiki/patients/.../DOC-2026-0001.md",
  "section": "Clinical Findings",
  "text": "Testo del chunk",
  "embedding_status": "pending",
  "created_at": "2026-07-03T10:30:00Z"
}
## 8.3 Recupero sicuro del contesto
- Ogni query RAG deve includere tenant_id e, quando applicabile, patient_id.
- Il Copilot non deve poter interrogare documenti di pazienti o tenant diversi dal contesto corrente.
- I risultati recuperati devono indicare sempre fonte, data, tipologia documento e confidenza.
- Per output clinici, il sistema deve presentare disclaimer e richiedere supervisione umana.
- Le fonti devono essere consultabili tramite link sicuri o endpoint backend, non tramite URL pubblici persistenti.
## 8.4 Roadmap RAG consigliata

# 9. Sicurezza, privacy e compliance GDPR
## 9.1 Dati trattati
Il progetto tratta dati personali e potenzialmente dati sanitari. Per questo motivo la sicurezza non può essere affrontata solo a livello infrastrutturale, ma deve essere integrata nel modello applicativo, nello storage, nei workflow AI e nella documentazione generata.

## 9.2 Misure di sicurezza baseline
- Autenticazione JWT: token validati lato backend e trasmessi solo su canale sicuro.
- Autorizzazione RBAC: ruoli differenziati per admin, user, manager e ruoli clinici futuri.
- Tenant isolation: database e MinIO devono applicare sempre il contesto tenant.
- Audit trail: azioni AI, accessi documentali e modifiche sensibili devono essere tracciati.
- Bucket privati: MinIO non deve esporre policy pubbliche su documenti clinici o Wiki.
- Presigned URL brevi: eventuali download/preview devono usare URL temporanei e scope limitato.
- No PHI nei log: logging tecnico senza contenuti clinici o anagrafici non necessari.
## 9.3 Cifratura GDPR proposta
La soluzione progettata (#7) prevede cifratura AES-256-GCM, derivazione chiavi per tenant e gestione separata dei segreti. In fase iniziale può essere sufficiente cifrare i contenuti più sensibili; in fase commerciale la cifratura dovrebbe essere estesa a documenti raw, Wiki, chunk e campi DB critici.

## 9.4 Governance AI
- Disclaimer: ogni output clinico deve ricordare che il sistema supporta, ma non sostituisce, il professionista sanitario.
- Approval gate: le scritture sui moduli o le sintesi cliniche devono poter essere accettate o modificate dall’utente.
- Confidence score: le estrazioni documentali con confidenza bassa devono andare in needs_review.
- Audit AI: prompt, azioni, utente, tenant, contesto e outcome devono essere tracciati con minimizzazione dei dati.
- Prompt versioning: i prompt multilingua devono avere versioni e stato attivo/inattivo.
# 10. DevOps, deployment e ambienti
## 10.1 Approccio deployment
Il deployment consigliato per la fase iniziale è Docker Compose, coerente con lo stato attuale del progetto e con l’obiettivo di mantenere semplicità operativa.
Kubernetes può essere valutato in una fase successiva, quando il prodotto richiederà scalabilità multi-cliente, alta disponibilità o deployment gestito.

## 10.2 Docker Compose indicativo per Wiki Worker
services:
  dentalcare-wiki-worker:
    build: ./wiki-worker
    container_name: dentalcare-wiki-worker
    environment:
      MINIO_ENDPOINT: http://minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ACCESS_KEY}
      MINIO_SECRET_KEY: ${MINIO_SECRET_KEY}
      MINIO_RECORDS_BUCKET: dental-records
      MINIO_WIKI_BUCKET: dental-wiki
      DATABASE_URL: ${DATABASE_URL}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      OCR_ENGINE_PRIMARY: docling
      OCR_ENGINE_FALLBACK: tesseract
    volumes:
      - /tmp/dentalcare-processing:/tmp/dentalcare-processing
    depends_on:
      - minio
      - postgres
    restart: unless-stopped
## 10.3 Checklist pre-produzione

# 11. Piano di implementazione operativo
## 11.1 Piano per portare P1 in produzione

## 11.2 Piano per Wiki Knowledge Base su MinIO

## 11.3 Acceptance criteria Wiki MinIO
- Caricando un PDF/DOCX in MinIO sotto dental-records/raw viene attivata la pipeline.
- Il documento originale rimane inalterato in dental-records.
- Il Markdown generato viene salvato in dental-wiki nel path del paziente corretto.
- index.md e index.json vengono creati o aggiornati.
- Il database contiene metadati, stato e riferimenti agli oggetti MinIO.
- I documenti falliti generano error.json in dental-processing/failed.
- Il filesystem locale è usato solo per file temporanei e viene ripulito.
- Il bucket dental-wiki ha versioning abilitato.
- I chunk RAG vengono generati come JSON in MinIO.
- Nessun dato clinico sensibile viene scritto nei log tecnici.
## 11.4 Ruoli e responsabilità

# 12. Rischi, dipendenze e mitigazioni
## 12.1 Risk register

## 12.2 Dipendenze principali

# 13. Governance documentale e allineamento GitHub
## 13.1 Struttura documentale target
L’allegato evidenzia una struttura GitHub coerente: Studio di Fattibilità, Business Plan, Product Roadmap e Architecture Handbook. La raccomandazione è trasformare i file locali di proposta e architettura in documentazione ufficiale versionata nella repository DentalCare-Documentation.

## 13.2 Documenti da creare o aggiornare
- Release-1.x.md con commit, stato deployment e checklist go-live.
- Release-2.x.md con #12.C, #3 e #14 dettagliati.
- Release-3.x.md con #7, #2, #16 e #8 come blocchi principali.
- 04-AI.md con Prompt Manager, Copilot operativo, Wiki LLM e RAG roadmap.
- 06-Multitenancy.md con isolamento MinIO per tenant e TenantContext.
- 07-Security.md con audit trail, encryption per tenant e policy PHI.
- 11-Wiki-LLM-MinIO.md come deep dive dedicato alla Wiki Knowledge Base.
## 13.3 Dashboard di stato consigliata

# 14. Conclusioni e prossimi passi
DentalCare Pro presenta una base progettuale solida: il nucleo P1 è già implementato in sviluppo e la roadmap evolutiva è coerente con un prodotto odontoiatrico AI-native.
Il passaggio strategico più importante è trasformare la gestione documentale in una Knowledge Base versionata su MinIO, perché questo abilita sia la consultazione clinica strutturata sia il futuro RAG del Copilot.

## 14.1 Prossimi passi consigliati
- Chiudere P1 e deploy: validare build, migrazioni, configurazione prod, smoke test e rollback plan.
- Aggiornare GitHub documentation: sincronizzare Release-1.x, AI.md, Security.md e Multitenancy.md.
- Formalizzare #7 GDPR: decidere se alzare la cifratura a prerequisito P1 in caso di dati reali o vendita.
- Avviare #16 Wiki LLM: creare bucket MinIO, schema SQL, worker base e template Markdown.
- Posticipare RAG avanzato: generare prima Markdown e chunk JSON stabili; poi introdurre vector DB.
- Preparare validation plan: test con documenti clinici campione anonimizzati e criteri di qualità OCR/LLM.
## 14.2 Decisioni da prendere

# Appendice A - Sintesi del mapping allegato
L’allegato ricevuto stabilisce il collegamento tra documentazione GitHub, feature locali e stato di implementazione. I punti più rilevanti sono riportati in forma sintetica per mantenere tracciabilità fra questo documento e il materiale di partenza.

# Appendice B - Glossario operativo

Nota: il documento è stato redatto a partire dall’allegato “Feature-to-Documentation Mapping” e riorganizzato in forma di documento progettuale approfondito, includendo l’impostazione della Wiki Knowledge Base con storage primario in MinIO.
| Campo | Valore |
| --- | --- |
| Versione documento | 1.0 |
| Data | 03/07/2026 |
| Ambito | DentalCare Pro - roadmap, architettura, AI, MinIO Wiki, compliance e piano di implementazione |
| Input di riferimento | Allegato: Feature-to-Documentation Mapping; materiali progettuali CLAUDE.md, proposte-modifiche.md e wiki_llm_minio_architecture.md citati nell’allegato |
| Destinatari | Team prodotto, architettura, sviluppo, compliance, stakeholder business |
| Obiettivo del documento
Fornire una descrizione approfondita e coerente del progetto DentalCare Pro, trasformando il mapping allegato in un documento operativo utile per decisioni di prodotto, architettura, pianificazione tecnica e avvio implementativo della Wiki clinica su MinIO. |
| --- |
| Area | Stato sintetico | Impatto progettuale |
| --- | --- | --- |
| Core Practice Management | Implementato in dev | Base funzionale del prodotto: anagrafiche, agenda, prestazioni, prezzi, bundle, flussi operativi. |
| AI Copilot | Implementato in dev per chat, governance, prompt e azioni operative | Differenziazione forte del prodotto: supporto all’operatore, automazione assistita, scritture controllate sui moduli. |
| Voice Agent | Implementato tramite n8n e Retell | Canale conversazionale per prenotazioni, reminder, interazioni telefoniche e automazioni di front office. |
| AI Radiology | Implementazione YOLO/Dentex avviata | Capacità di supporto clinico e generazione di callback o annotazioni collegate al paziente. |
| Wiki Knowledge Base | Proposta architetturale | Componente chiave per trasformare documenti clinici in conoscenza interrogabile, versionata e RAG-ready. |
| GDPR & Security | Parziale; encryption proposta | Prerequisito per vendita esterna e gestione robusta dei dati sanitari. |
| Decisione architetturale principale
La Wiki clinica deve essere implementata all’interno di MinIO: i file Markdown, gli indici paziente, i chunk RAG e le versioni storiche devono essere oggetti S3-compatible. Il filesystem locale resta solo un’area temporanea di elaborazione. |
| --- |
| Problema | Effetto nello studio odontoiatrico | Risposta DentalCare Pro |
| --- | --- | --- |
| Frammentazione degli strumenti | Agenda, cartella clinica, immagini, documenti e comunicazioni sono spesso separati. | Piattaforma integrata con backend unico, storage documentale e moduli AI. |
| Documentazione non interrogabile | PDF, referti e immagini restano archivi passivi. | Pipeline OCR/LLM che genera Wiki Markdown e dati strutturati. |
| Operazioni ripetitive di front office | Tempo perso in prenotazioni, reminder, raccolta dati e aggiornamento schede. | Copilot operativo e Voice Agent per automatizzare attività controllate. |
| Rischio compliance | Dati sanitari gestiti senza audit fine-grained o cifratura per tenant. | Audit log, RBAC, storage privato e proposta di cifratura AES-256-GCM per tenant. |
| Difficoltà nell’uso dell’AI clinica | Output non tracciati, rischio di automazione non supervisionata. | Human-in-the-loop, disclaimer, approval gate e registrazione delle azioni AI. |
| Modulo | Descrizione | Stato | Priorità |
| --- | --- | --- | --- |
| Core PM | Gestione operativa dello studio: pazienti, appuntamenti, prestazioni, prezzi, bundle e configurazioni. | Implementato in dev | P1 |
| Agenda realtime | Aggiornamento in tempo reale degli eventi tramite SSE e sincronizzazione frontend. | Implementato in dev | P1 |
| AI Copilot | Chat intelligente, azioni sui moduli, prompt multilingua, governance e audit. | Implementato in dev | P1 |
| Voice Assistant | Automazione conversazionale tramite Retell/n8n per front office e multi-studio futuro. | Implementato/proposto per estensione | P1/P3 |
| Radiology AI | Servizio AI per ortopanoramiche, modello Dentex YOLO e callback applicativo. | Parziale/implementato | P1-P3 |
| Wiki Knowledge Base | Trasformazione documenti clinici in Markdown versionato su MinIO e base per RAG. | Proposto | P3 |
| RAG & Memory | Ricerca semantica e memoria contestuale su documenti, note e dati clinici. | Proposto futuro | Release 4.x |
| GDPR Encryption | Cifratura forte per tenant, gestione chiavi, audit e controlli di accesso. | Proposto | P1 se vendita, altrimenti P3 |
| Feature evolutiva | Motivazione | Dipendenze |
| --- | --- | --- |
| Anagrafiche per-studio e categorie prodotto | Aumentano la configurabilità multi-tenant e riducono hardcoding applicativo. | Core PM stabile |
| Validazione codice fiscale e dati anagrafici | Migliora qualità dati e compliance documentale. | Regole locali e UX di correzione |
| Copilot proattivo e cross-modulo | Trasforma il Copilot da chat reattiva ad assistente operativo contestuale. | Agenda realtime, Copilot operativo |
| Wiki Knowledge Base | Centralizza conoscenza clinica/documentale e prepara il RAG. | MinIO, OCR, LLM, policy PHI |
| DICOM nativo | Permette gestione completa imaging medico e interoperabilità. | AI service, librerie DICOM, storage sicuro |
| Release | Fase | Contenuto principale | Stato | Target indicativo |
| --- | --- | --- | --- | --- |
| Release 1.x | P1 - Subito | Core PM, agenda realtime, Copilot chat/operativo, prompt manager, audit AI, Voice Agent, Radiology AI base. | Completato in dev; deployment pending | Luglio 2026 |
| Release 2.x | P2 - Poi | Categorie prodotto, validazione dati, Copilot context-aware, miglioramenti UX e data quality. | Proposto | Agosto 2026 |
| Release 3.x | P3 - Compliance/Scale | GDPR encryption, multistudio, Wiki Knowledge Base, DICOM nativo. | Proposto | Ottobre 2026 |
| Release 4.x | Future | RAG avanzato, memoria clinica, Copilot multimodale, anamnesi avanzata per tenant. | R&D | 2027 Q1 |
| Release 5.x | Future+ | Scalabilità commerciale, reporting avanzato, dashboard compliance, integrazioni esterne estese. | Da definire | 2027+ |
| Area | Criterio di completamento |
| --- | --- |
| Build e deployment | Backend, frontend, DB, MinIO, AI service e integrazioni devono avviarsi con profilo prod senza workaround manuali. |
| Migrazioni dati | Schema PostgreSQL aggiornato, tabelle prompt/audit disponibili, dati seed coerenti. |
| AI Copilot | Azioni operative disponibili solo con gating, loggate e supervisionate. |
| Security baseline | JWT, RBAC, CORS, validazioni input, logging privo di PHI non necessari. |
| Test E2E | Flussi principali verificati: login, paziente, agenda, prestazioni, Copilot, Voice callback se previsto. |
| Documentazione | Release-1.x e Architecture Handbook aggiornati con stato reale di implementazione. |
| Componente | Ruolo | Tecnologie/Note |
| --- | --- | --- |
| Frontend | Esperienza utente per operatori, medici e amministratori. | Angular 17, moduli feature, servizi HTTP, guard/interceptor, SSE. |
| Backend | API REST, logica applicativa, validazioni, sicurezza, orchestrazione verso DB/MinIO/AI. | Spring Boot 3, JPA, DTO, @Transactional, @RestControllerAdvice. |
| Database | Dati strutturati, utenti, tenant, audit, metadati documentali. | PostgreSQL con isolamento per schema/tenant. |
| MinIO | Object storage per documenti, immagini, file generati, Wiki e chunk. | S3-compatible, bucket/prefix per tenant, versioning. |
| AI Copilot | Assistente applicativo e operativo. | Spring AI/OpenAI, prompt DB, audit e gating. |
| AI Radiology Service | Inferenza su immagini radiologiche e callback. | Python, ONNX/YOLO, Docker, MinIO input/output. |
| Wiki Worker | Pipeline OCR/LLM per trasformare documenti in Wiki Markdown. | Python, PyMuPDF, Docling, Tesseract fallback, boto3/MinIO SDK. |
| n8n/Retell | Automazione conversazionale e integrazioni voice. | Workflow low-code, agenti parametrizzati. |
| Livello | Meccanismo | Nota operativa |
| --- | --- | --- |
| Database | Schema per tenant o filtri tenant-aware | Riduce rischio di leakage e semplifica backup/esportazioni per studio. |
| MinIO | Prefix o bucket per tenant | Consente policy, lifecycle e versioning differenziati. |
| Applicazione | TenantContext, RBAC, JWT claims | Ogni richiesta deve risolvere tenant e permessi prima di accedere ai dati. |
| AI | Prompt e contesto tenant-scoped | Il Copilot non deve recuperare dati di altri tenant. |
| Audit | Log con tenant_id e user_id | Indispensabile per tracciabilità e compliance. |
| Principio chiave
MinIO diventa il repository principale della Wiki. I file Markdown, gli indici paziente, i chunk RAG e le versioni storiche devono essere salvati come oggetti. Il database conserva metadati e riferimenti agli oggetti, non il contenuto completo. |
| --- |
| Bucket/Prefix | Contenuto | Policy consigliata |
| --- | --- | --- |
| dental-records/raw | Documenti originali caricati dagli utenti o da integrazioni. | Privato, versioning opzionale, retention conforme. |
| dental-wiki/patients | Markdown, indici e chunk generati. | Privato, versioning abilitato, accesso tramite backend. |
| dental-wiki/versions | Copie storiche leggibili delle revisioni Markdown. | Privato, lifecycle controllato. |
| dental-processing/failed | Errori, diagnostica tecnica senza PHI e riferimenti agli oggetti. | Privato, retention limitata. |
| dental-processing/tmp | Area temporanea se usata in MinIO; preferibile filesystem effimero. | Retention breve e pulizia automatica. |
| Vantaggio | Descrizione |
| --- | --- |
| Portabilità | Markdown è leggibile da applicazioni, sviluppatori e strumenti AI senza lock-in proprietario. |
| Versionabilità | MinIO Object Versioning preserva revisioni precedenti e consente audit documentale. |
| RAG-ready | Il Markdown è un formato ideale per chunking semantico e embedding. |
| Separazione dati/metadati | Il database resta leggero e conserva riferimenti, mentre MinIO contiene il corpo documentale. |
| Scalabilità | Object storage è più adatto di filesystem locale o colonne CLOB per documenti e output generati. |
| Sicurezza | Accesso mediato dal backend tramite policy e presigned URL temporanei. |
| Tipo documento | Motore primario | Fallback | Note |
| --- | --- | --- | --- |
| PDF nativo | PyMuPDF | Docling | Più veloce e adatto a PDF testuali. |
| PDF scansionato | Docling | Tesseract OCR | Richiede maggiore controllo qualità su testo vuoto o rumoroso. |
| DOCX | Docling o parser DOCX | Conversione tramite LibreOffice se necessario | Da normalizzare in Markdown con sezioni coerenti. |
| Immagine | Docling/OCR | Tesseract | Applicare preprocessing se la qualità è bassa. |
| DICOM | Modulo futuro | Export immagine se supportato | Da gestire dopo definizione DICOM nativo. |
| Campo | Tipo logico | Descrizione |
| --- | --- | --- |
| id | UUID/BIGINT | Identificativo interno. |
| tenant_id | string | Tenant/studio proprietario del documento. |
| patient_id | string/FK | Paziente collegato. |
| document_id | string | Identificativo documento applicativo. |
| source_object_uri | string | URI MinIO del file originale. |
| wiki_object_uri | string | URI MinIO della pagina Markdown generata. |
| index_object_uri | string | URI dell’indice paziente. |
| exam_date | date | Data esame/referto quando disponibile. |
| exam_type | string | Tipologia documento/esame. |
| summary | text breve | Sintesi salvata per preview e ricerca rapida. |
| status | enum | uploaded, processing, processed, needs_review, failed. |
| confidence | decimal | Confidenza dell’estrazione AI. |
| created_at / updated_at | timestamp | Tracciabilità temporale. |
| Stato | Significato | Azione UI consigliata |
| --- | --- | --- |
| uploaded | Documento caricato ma non ancora preso in carico dal worker. | Mostrare come in attesa. |
| processing | Pipeline in esecuzione. | Mostrare spinner o stato di elaborazione. |
| processed | Markdown e metadati generati correttamente. | Abilitare visualizzazione Wiki. |
| needs_review | Output AI incompleto o confidenza bassa. | Richiedere revisione operatore/medico. |
| failed | Errore tecnico o documento non processabile. | Mostrare errore controllato e permettere retry. |
| Fase | Descrizione | Motivo |
| --- | --- | --- |
| RAG 0 | Solo Markdown e chunk in MinIO, senza vector DB. | Stabilizza pipeline e formato canonico. |
| RAG 1 | Embedding worker batch e indicizzazione Qdrant/pgvector. | Introduce ricerca semantica controllata. |
| RAG 2 | Copilot con retrieval paziente/studio e citazione fonti. | Aumenta utilità operativa del Copilot. |
| RAG 3 | Memoria clinica e multimodale con immagini/referti. | Abilita scenari avanzati ma richiede governance forte. |
| Categoria dato | Esempi | Rischio | Controllo consigliato |
| --- | --- | --- | --- |
| Anagrafica | Nome, contatti, codice fiscale | Identificazione diretta | RBAC, validazione, audit accessi. |
| Clinico | Referti, anamnesi, piano cure | Dato sanitario | Cifratura, accesso minimo, audit, human review. |
| Imaging | Ortopanoramiche, DICOM futuro | Dato sanitario e biometrico indiretto | Storage privato, presigned URL, retention. |
| AI output | Sintesi, finding, azioni suggerite | Errore clinico o decisione non supervisionata | Disclaimer, confidence, approval gate. |
| Log tecnici | Errori, trace, metriche | Leakage involontario PHI | Redazione log e policy no-PHI. |
| Elemento | Raccomandazione |
| --- | --- |
| Algoritmo | AES-256-GCM per garantire confidenzialità e integrità. |
| Chiavi | Derivazione per tenant tramite HKDF o integrazione con Vault/KMS. |
| Rotazione | Policy di rotazione e migrazione versionata dei dati cifrati. |
| MinIO | Valutare SSE lato storage e/o cifratura applicativa prima dell’upload. |
| Database | Cifrare campi sensibili o memorizzare solo riferimenti a contenuto cifrato. |
| AI | Limitare invio di PHI al minimo necessario e tracciare base giuridica/consenso. |
| Servizio | Responsabilità | Note deployment |
| --- | --- | --- |
| frontend | UI Angular servita via web server | Build statico, configurazione API base URL. |
| backend | API Spring Boot e business logic | Profilo prod, variabili ambiente, healthcheck. |
| postgres | Database multi-tenant | Backup, migrazioni, volumi persistenti. |
| minio | Object storage documentale | Bucket init, versioning, policy private. |
| ai-service | Inferenza radiologica | ONNX Runtime CPU/GPU opzionale, accesso MinIO. |
| wiki-worker | OCR/LLM/Wiki pipeline | CPU-only, accesso MinIO, OpenAI key, DB. |
| n8n | Workflow automation | Credenziali protette, workflow versionati. |
| Area | Verifica |
| --- | --- |
| Build | Frontend e backend compilano senza errori; immagini Docker riproducibili. |
| Migrazioni DB | Migrazioni applicate su ambiente pulito e su dati esistenti. |
| MinIO | Bucket creati, versioning dental-wiki abilitato, policy private, lifecycle definito. |
| Sicurezza | JWT, RBAC, CORS, segreti, password e chiavi API gestiti via variabili/secret store. |
| AI | Prompt versionati, audit attivo, fallback/errore gestito. |
| Backup | Backup DB e MinIO pianificati e test di restore eseguito. |
| Logging | Log tecnici senza PHI; retention e accessi definiti. |
| Test | Smoke test, E2E principali e test upload documento/Wiki. |
| Step | Attività | Output |
| --- | --- | --- |
| 1 | Verifica commit e stato branch P1 | Elenco commit e changelog Release 1.x. |
| 2 | Build backend/frontend/AI service | Artefatti o immagini Docker versionate. |
| 3 | Migrazioni DB | Schema aggiornato e seed coerenti. |
| 4 | Configurazione ambiente prod | application-prod, .env, CORS, URL, credenziali. |
| 5 | Smoke test funzionale | Login, agenda, prestazioni, Copilot, prompt, audit. |
| 6 | Go-live controllato | Deploy con rollback plan. |
| Fase | Deliverable | Dettaglio |
| --- | --- | --- |
| Fase 0 - Design | Spec tecnica definitiva | Naming bucket, metadata, schema SQL, sicurezza, template Markdown. |
| Fase 1 - Storage | Bucket e path MinIO | dental-records, dental-wiki, versioning, policy private, test upload/download. |
| Fase 2 - Worker base | Pipeline evento -> download -> estrazione | Listener MinIO, PyMuPDF, Docling/Tesseract fallback. |
| Fase 3 - LLM | JSON extraction + Markdown generation | Prompt, schema validation, confidence, needs_review. |
| Fase 4 - Sync | SQL + index.md/index.json | Persistenza metadati e aggiornamento Wiki paziente. |
| Fase 5 - UI minima | Viewer Wiki | Lista documenti paziente e preview Markdown. |
| Fase 6 - RAG-ready | Chunk JSON | Chunking e oggetti pronti per embedding futuro. |
| Ruolo | Responsabilità |
| --- | --- |
| Product owner | Priorità release, validazione requisiti, decisioni su scope e go-live. |
| Architect | Scelte architetturali, MinIO Wiki design, sicurezza, integrazioni. |
| Backend developer | API, DB, MinIO service, audit, security, sync metadata. |
| Frontend developer | UI operativa, viewer Wiki, stati documento, gestione errori. |
| AI engineer | Prompt, OCR/LLM worker, radiology service, RAG pipeline. |
| DevOps | Docker Compose, ambienti, segreti, backup, monitoring. |
| Compliance/DPO | Valutazione GDPR, minimizzazione, base giuridica, DPIA se necessaria. |
| Rischio | Impatto | Probabilità | Mitigazione |
| --- | --- | --- | --- |
| Gestione non adeguata di dati sanitari | Molto alto | Media | Anticipare GDPR encryption, audit, access policy e DPIA. |
| Output AI errati o non supervisionati | Alto | Media | Human-in-the-loop, confidence score, disclaimer, audit. |
| OCR di bassa qualità | Medio/alto | Media | Fallback multipli, needs_review, test con campioni reali. |
| RAG su fonti non controllate | Alto | Media | Usare Markdown canonico, metadata e filtri tenant/paziente. |
| Over-engineering prematuro | Medio | Alta | Partire da Wiki MinIO e chunk JSON prima di vector DB. |
| Lock-in su provider LLM | Medio | Media | Astrazione client LLM e prompt versionati. |
| Performance CPU-only | Medio | Media | Queue, batch, timeout, worker scalabili e OCR asincrono. |
| Mancata sincronizzazione documentazione/codice | Medio | Alta | Roadmap GitHub e stato implementativo aggiornati a ogni release. |
| Dipendenza | Condiziona | Nota |
| --- | --- | --- |
| #7 GDPR encryption | Vendita clinica, Wiki, RAG, gestione PHI | Da alzare a P1 se si passa a dati reali. |
| #13 Copilot operativo | #14 Copilot context-aware | Già implementato in dev, base per evoluzioni cross-modulo. |
| #16 Wiki LLM | #15 RAG | La Wiki MinIO è fondazione del RAG. |
| AI Service radiology | #8 DICOM nativo | DICOM dopo stabilizzazione inferenza e storage imaging. |
| MinIO bucket policy | Wiki, documenti, chunk | Deve essere definita prima del worker. |
| Area GitHub | Contenuto da aggiornare | Priorità |
| --- | --- | --- |
| 01-Studio-di-Fattibilita | Vision, analisi mercato, SWOT, rischi, validation plan. | Media |
| 02-Business-Plan | Business model, revenue, go-to-market, pricing e assunzioni commerciali. | Media |
| 03-Product-Roadmap | Release 1.x-5.x, backlog, stato implementativo, dipendenze. | Alta |
| 04-Architecture-Handbook | Backend, frontend, AI, MinIO, multitenancy, security, Wiki LLM. | Alta |
| 07-Security o sezione equivalente | GDPR encryption, audit AI, PHI handling, data retention. | Critica |
| Elemento dashboard | Descrizione |
| --- | --- |
| Feature | Nome e numero proposta, es. #16 Wiki LLM. |
| Release target | Release 1.x, 2.x, 3.x, Future. |
| Stato | Proposto, in sviluppo, dev done, deployed, deferred. |
| Dipendenze | Feature o decisioni necessarie. |
| Commit/PR | Riferimento GitHub o repo locale. |
| Documentazione | Link al file markdown aggiornato. |
| Rischio | Compliance, tecnico, prodotto, operativo. |
| Conclusione operativa
La priorità immediata è portare in produzione la Release 1.x e, in parallelo, definire formalmente l’architettura Wiki MinIO e la strategia GDPR. Senza questi due elementi, RAG, DICOM nativo e Copilot avanzato rischiano di crescere su fondamenta non sufficientemente governate. |
| --- |
| Decisione | Opzioni | Raccomandazione |
| --- | --- | --- |
| Strategia bucket MinIO | Bucket separati o bucket unico con prefix | Preferire bucket separati dental-records/dental-wiki. |
| Versioning Wiki | Solo MinIO versioning o anche copie in versions/ | Usare entrambi: versioning nativo + archivio leggibile. |
| Vector DB | Qdrant, pgvector, OpenSearch, nessuno inizialmente | Nessuno in Fase 1; predisporre chunk JSON. |
| Cifratura | SSE MinIO, cifratura applicativa, entrambe | Cifratura applicativa per PHI + valutare SSE. |
| LLM provider | OpenAI diretto, astrazione provider, locale futuro | Creare astrazione client LLM per evitare lock-in. |
| UI Wiki | Viewer minimo o editor completo | Viewer minimo; editing manuale in fase successiva. |
| Area | Messaggio chiave dal mapping |
| --- | --- |
| Struttura documentale | La repo GitHub è organizzata in fattibilità, business plan, roadmap e handbook architetturale. |
| P1/Release 1.x | Completata in dev e pronta per deployment previa validazione. |
| P2/Release 2.x | Include data quality, categorie prodotto e Copilot context-aware. |
| P3/Release 3.x | Include compliance GDPR, multi-studio, Wiki Knowledge Base e DICOM. |
| Future/Release 4.x+ | Include RAG, memoria, multimodalità e funzionalità cliniche avanzate. |
| Gap critico | La cifratura GDPR è il principale prerequisito per vendita e uso con dati reali. |
| Opportunità | La Wiki MinIO è un nuovo blocco architetturale da aggiungere all’Architecture Handbook. |
| Termine | Definizione nel progetto |
| --- | --- |
| AI-native | Applicazione progettata con capacità AI integrate nei flussi principali, non aggiunte come accessorio. |
| Copilot operativo | Assistente AI che può proporre o preparare azioni sui moduli, sempre con controllo utente. |
| RAG | Retrieval-Augmented Generation: generazione LLM arricchita da recupero di fonti interne. |
| Wiki MinIO | Knowledge base in Markdown salvata come oggetti MinIO, con indici, versioni e chunk. |
| PHI | Protected Health Information: dati sanitari o identificativi connessi alla salute. |
| Tenant | Studio o organizzazione isolata logicamente nel sistema. |
| Chunk | Porzione di testo derivata dal Markdown, usata per embedding e ricerca semantica. |
| Presigned URL | URL temporaneo e firmato per accedere a un oggetto privato MinIO/S3. |