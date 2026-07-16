---
title: "DentalCare Pro — Guida approfondita alla digitalizzazione della cartella clinica del paziente dentale"
author: "Documento operativo e architetturale"
date: "16 luglio 2026"
lang: it-IT
---

# Premessa

La digitalizzazione della cartella clinica odontoiatrica non consiste nel trasferire moduli cartacei in PDF o nel sostituire una penna con una schermata. Consiste nel riprogettare l'intero ciclo di vita dell'informazione clinica affinché ogni dato sia **corretto, attribuibile, aggiornato, consultabile, protetto, interoperabile e conservato nel tempo**.

Per DentalCare Pro la cartella clinica digitale deve diventare il nucleo clinico della piattaforma, separato ma integrato con agenda, segreteria, documenti, immagini, pagamenti, assistente virtuale e moduli di intelligenza artificiale. Il sistema deve aiutare l'odontoiatra a documentare la cura senza trasformarsi in un ostacolo operativo e deve impedire che utenti amministrativi, fornitori o altri tenant accedano a informazioni cliniche non necessarie.

Questa guida è pensata per:

- studi odontoiatrici singoli e associati;
- poliambulatori e reti di cliniche;
- strutture sanitarie private accreditate;
- responsabili clinici, DPO, responsabili qualità e sicurezza;
- product manager, analisti, sviluppatori e tester di DentalCare Pro.

Il documento propone un modello implementativo italiano ed europeo, coerente con GDPR, Codice dell'amministrazione digitale, linee guida AgID sui documenti informatici, disciplina FSE 2.0, standard DICOM e HL7 FHIR. Le indicazioni normative devono essere verificate sul caso concreto con DPO e consulente legale, soprattutto per conservazione, firma, integrazione regionale, ricerca e riuso dei dati.

## Risultato atteso

Al termine del progetto, DentalCare dovrà consentire di:

1. identificare con certezza paziente, professionista, struttura e episodio di cura;
2. raccogliere anamnesi, esame obiettivo, odontogramma, diagnosi, piano di trattamento, procedure e follow-up in forma strutturata;
3. collegare fotografie, radiografie, DICOM, referti, consensi e prescrizioni al corretto episodio clinico;
4. mantenere la storia completa delle modifiche senza sovrascrivere il passato;
5. applicare firme, validazioni e conservazione dove necessario;
6. consentire accessi per ruolo, contesto e relazione di cura;
7. produrre documenti leggibili dal paziente e dati interoperabili con altri sistemi;
8. integrare moduli AI senza confondere l'output algoritmico con la decisione clinica;
9. dimostrare a un controllo chi ha visto o modificato cosa, quando e perché;
10. migrare dal cartaceo senza perdita di informazione o interruzione dell'attività.

# 1. Concetti da non confondere

## 1.1 Cartella clinica odontoiatrica

È l'insieme organizzato delle informazioni generate e utilizzate per la cura del singolo paziente: anamnesi, riscontri clinici, diagnosi, piani, procedure, prescrizioni, consensi, immagini, referti, follow-up e comunicazioni clinicamente rilevanti.

In DentalCare la cartella non deve essere un unico file. Deve essere un **insieme coerente di eventi e documenti**, collegati fra loro e ricostruibili nel tempo.

## 1.2 Dossier sanitario

Il dossier sanitario è un trattamento longitudinale effettuato all'interno di un organismo sanitario per rendere disponibili a più professionisti informazioni provenienti da eventi clinici differenti. Non coincide automaticamente con la cartella del singolo episodio e non deve essere creato implicitamente unendo dati di studi o strutture diverse. Il Garante ha più volte sottolineato la specificità del dossier e la necessità di controlli sugli accessi [R2][R3].

Per DentalCare significa che:

- ogni tenant deve essere isolato;
- la condivisione tra sedi della stessa organizzazione deve essere configurata e documentata;
- la condivisione tra organizzazioni distinte richiede un fondamento giuridico e un modello di responsabilità specifico;
- il paziente deve poter ottenere, nei casi previsti, informazioni sugli accessi effettuati al proprio dossier.

## 1.3 Fascicolo Sanitario Elettronico

Il FSE è l'infrastruttura pubblica nazionale e regionale che raccoglie dati e documenti sanitari generati da eventi clinici presenti e trascorsi. È distinto dalla cartella interna dello studio. Il decreto FSE 2.0 del 7 settembre 2023, successivamente modificato, disciplina il quadro nazionale [R5].

La progettazione corretta è quindi:

```text
Cartella DentalCare (sorgente clinica interna)
             |
             | genera documenti clinici validati
             v
Modulo di interoperabilità / connettore regionale
             |
             | CDA2 + PDF/PAdES + metadati + API
             v
Gateway e infrastrutture FSE 2.0
```

Non si deve modellare tutta la cartella come se fosse un documento FSE. La cartella interna deve rimanere più ricca e strutturata; solo i documenti previsti e appropriati vengono prodotti e trasmessi verso l'esterno.

## 1.4 Archivio documentale e conservazione digitale

Un archivio di file o un bucket MinIO non equivale a un sistema di conservazione a norma. Il backup serve a ripristinare dati dopo un guasto; la conservazione digitale serve a mantenere nel tempo autenticità, integrità, leggibilità, reperibilità e valore probatorio dei documenti informatici secondo il quadro applicabile [R7][R8][R9].

DentalCare deve quindi distinguere:

- **database operativo**;
- **object storage clinico**;
- **backup e disaster recovery**;
- **archivio dei documenti finalizzati**;
- **servizio di conservazione**, quando richiesto dalla politica documentale e dalla natura del documento.

# 2. Principi progettuali

## 2.1 Clinical first

La struttura della cartella deve seguire il ragionamento clinico, non l'organigramma del software. Ogni schermata deve rispondere a una domanda reale:

- chi è il paziente e qual è il contesto di cura?
- quali rischi devo conoscere prima di intervenire?
- che cosa ho osservato?
- quale problema ho identificato?
- quali alternative ho discusso?
- quale trattamento è stato pianificato e quale eseguito?
- come è cambiata la situazione nel tempo?

## 2.2 Dato strutturato più documento leggibile

Occorrono entrambe le rappresentazioni:

- dati strutturati per ricerca, alert, interoperabilità, analisi e AI;
- documenti leggibili per comunicazione, firma, consegna e conservazione.

Un PDF senza struttura non consente una buona continuità clinica; un database senza documento finalizzato può essere difficile da consegnare, firmare e conservare.

## 2.3 Immutabilità logica

Una nota clinica finalizzata non va modificata silenziosamente. La correzione deve avvenire tramite:

1. addendum;
2. rettifica motivata;
3. annullamento logico con conservazione dell'originale;
4. nuova versione collegata alla precedente.

Il sistema deve mostrare chiaramente quale versione è clinicamente valida senza eliminare la storia.

## 2.4 Minimo privilegio e relazione di cura

La segreteria deve vedere dati anagrafici, contatti, appuntamenti e informazioni amministrative necessarie, ma non l'intera anamnesi o le note cliniche. L'odontoiatra deve accedere ai pazienti assegnati o per i quali esiste una relazione di cura. Gli amministratori tecnici non devono avere accesso ordinario ai contenuti clinici in chiaro.

## 2.5 Interoperabilità by design

I concetti clinici devono avere identificatori, codici e versioni. L'integrazione non va aggiunta al termine del progetto. Bisogna modellare fin dall'inizio:

- paziente;
- professionista e ruolo;
- organizzazione e sede;
- episodio/encounter;
- problema/diagnosi;
- osservazione;
- procedura;
- piano di cura;
- immagine e referto;
- consenso;
- provenienza e audit.

FHIR è uno standard per lo scambio elettronico di informazioni sanitarie [R11]; DICOM è lo standard internazionale per immagini mediche e informazioni correlate [R12]. Le specifiche nazionali FSE 2.0 utilizzano documenti CDA2 validati sintatticamente, semanticamente e terminologicamente, con processi di accreditamento e firma PAdES documentati dal Ministero della salute [R6].

## 2.6 Privacy e sicurezza per impostazione predefinita

La protezione dei dati sanitari deve essere incorporata nell'architettura, come richiesto dal GDPR [R1]. Non è sufficiente aggiungere un'informativa privacy dopo lo sviluppo.

# 3. Governance del progetto

## 3.1 Gruppo di lavoro minimo

| Ruolo | Responsabilità principale |
|---|---|
| Sponsor/CEO | approva perimetro, risorse e rischio residuo |
| Responsabile clinico odontoiatrico | definisce contenuti, workflow e criteri di qualità clinica |
| Product owner | traduce bisogni in requisiti e priorità |
| DPO/Privacy | basi giuridiche, DPIA, informative, diritti, fornitori |
| Security officer | architettura, IAM, logging, incidenti, test |
| Responsabile qualità | procedure, evidenze, change control, audit |
| Architect/CTO | modello dati, integrazioni, scalabilità, segregazione |
| UX specialist | usabilità clinica e prevenzione degli errori |
| Data steward | terminologie, qualità, metadati, migrazione |
| Referente FSE | profili CDA, accreditamento, integrazione regionale |
| Referente AI | governance dei modelli e tracciabilità degli output |

## 3.2 Decisioni da formalizzare prima dello sviluppo

- perimetro esatto della cartella;
- tipologie di struttura servite;
- responsabilità di titolare e responsabile del trattamento;
- separazione tra funzioni amministrative e cliniche;
- modello di accesso per medico, segreteria, igienista, assistente, amministratore;
- politica di finalizzazione e firma;
- politica di conservazione per categoria documentale;
- modello multi-sede e multi-tenant;
- integrazioni obbligatorie;
- uso o esclusione dei dati per ricerca e training AI;
- criteri per la migrazione del pregresso;
- RPO, RTO e disponibilità attesa.

## 3.3 Registro delle decisioni architetturali

Ogni scelta significativa deve essere registrata in un Architecture Decision Record, ad esempio:

```text
ADR-012 — Le note cliniche finalizzate sono append-only
Stato: approvato
Decisione: dopo la firma/validazione non è consentito UPDATE del contenuto.
Correzione: addendum collegato alla nota originaria.
Motivazione: integrità, tracciabilità, valore probatorio.
Conseguenze: necessità di UI per rettifica e versioni.
```

# 4. Analisi dello stato iniziale

Prima di configurare il software occorre effettuare un censimento reale dello studio.

## 4.1 Inventario delle fonti

- cartelle cartacee;
- gestionali precedenti;
- fogli Excel;
- software radiologico;
- PACS o repository immagini;
- e-mail e PEC;
- messaggistica istantanea;
- moduli di consenso;
- preventivi;
- agenda;
- prescrizioni;
- referti di laboratorio;
- fotografie su PC o dispositivi mobili;
- modelli Word;
- archivi esterni;
- documenti già presenti nel FSE.

## 4.2 Mappa dei processi

Per ogni processo rilevare:

- attore;
- input;
- attività;
- dato creato;
- documento prodotto;
- approvazione;
- consegna al paziente;
- conservazione;
- eccezioni;
- strumenti utilizzati;
- rischio di errore.

## 4.3 Gap analysis

Classificare ogni lacuna:

| Area | Esempio di gap | Rischio |
|---|---|---|
| Identità | duplicati dello stesso paziente | associazione dati alla persona errata |
| Anamnesi | modulo non aggiornato | mancata conoscenza di terapia o allergia |
| Odontogramma | solo immagine statica | impossibilità di ricostruire evoluzione |
| Procedure | note libere incomplete | scarsa tracciabilità clinica |
| Immagini | file con nomi manuali | errore paziente/esame |
| Accessi | account condivisi | impossibilità di attribuire le azioni |
| Correzioni | sovrascrittura | perdita della storia |
| Backup | copia sullo stesso server | indisponibilità o perdita definitiva |
| Consensi | moduli non versionati | impossibilità di provare cosa è stato accettato |
| Integrazioni | esportazione manuale | errori e duplicazioni |

# 5. Modello clinico minimo della cartella dentale

## 5.1 Identificazione del paziente

Campi raccomandati:

- identificatore interno UUID;
- codice fiscale, quando disponibile e pertinente;
- nome, cognome, data e luogo di nascita;
- sesso amministrativo e informazioni clinicamente rilevanti separate;
- indirizzo e contatti;
- medico curante, se comunicato;
- referente o tutore;
- preferenze linguistiche e di comunicazione;
- identificativi esterni e regionali;
- stato del record: attivo, deceduto, duplicato, archiviato;
- collegamento a eventuale record unificato.

Il codice fiscale non deve essere la chiave primaria tecnica: può mancare, cambiare o essere inserito in modo errato. Il sistema deve avere una procedura di merge dei duplicati con approvazione e audit.

## 5.2 Anamnesi generale

La raccolta deve includere, ove pertinente:

- patologie attuali e pregresse;
- ricoveri e interventi;
- allergie e reazioni avverse;
- farmaci e integratori;
- terapia anticoagulante/antiaggregante;
- diabete;
- cardiopatie e rischio infettivo;
- ipertensione;
- immunodepressione;
- patologie emorragiche;
- gravidanza/allattamento;
- abitudini rilevanti, fumo e alcol;
- precedenti reazioni ad anestetici;
- condizioni neurologiche o cognitive;
- dispositivi impiantati;
- informazioni richieste da protocolli clinici specifici.

Ogni voce deve avere:

- stato: presente, assente, non noto;
- data di rilevazione;
- fonte: paziente, caregiver, documento, professionista;
- autore;
- eventuale data di risoluzione;
- nota e allegato probatorio;
- livello di verifica.

Non usare una sola casella “nessuna patologia”: bisogna distinguere “negato dal paziente”, “non indagato” e “dato non disponibile”.

## 5.3 Anamnesi odontoiatrica

- precedenti trattamenti;
- dolore, sensibilità, sanguinamento;
- parafunzioni e bruxismo;
- igiene orale;
- frequenza delle visite;
- precedenti complicanze;
- esperienza con protesi o impianti;
- aspettative estetiche e funzionali;
- ansia odontoiatrica;
- abitudini alimentari rilevanti;
- storia traumatica;
- precedenti radiografie e data.

## 5.4 Esame obiettivo

La cartella deve supportare:

- esame extraorale;
- mucose e tessuti molli;
- articolazione temporo-mandibolare;
- occlusione;
- stato parodontale;
- mobilità;
- recessioni;
- sondaggio;
- placca e sanguinamento;
- lesioni;
- stato endodontico;
- carie e restauri;
- protesi;
- impianti;
- fotografie;
- misure e scale cliniche.

Ogni osservazione deve essere associabile a:

- dente;
- superficie;
- regione;
- lato;
- data;
- episodio;
- autore;
- metodo di rilevazione;
- stato di conferma.

## 5.5 Odontogramma

L'odontogramma non deve essere un disegno sovrascritto. Deve essere una rappresentazione temporale di fatti clinici.

### Requisiti funzionali

- dentizione permanente e decidua;
- numerazione FDI;
- superfici dentali;
- dente assente, incluso, sovrannumerario o non erotto;
- carie sospetta/confermata/trattata;
- restauri e materiali;
- corone, ponti, protesi;
- trattamento endodontico;
- impianti;
- mobilità e parodontologia;
- lesioni periapicali;
- fratture;
- note e immagini collegate;
- confronto tra date;
- distinzione tra osservazione e procedura;
- indicazione della fonte: esame clinico, radiografia, importazione, AI.

### Modello dati consigliato

```text
DentalFinding
- id
- tenant_id
- patient_id
- encounter_id
- tooth_code
- surface_code
- finding_code
- status
- certainty
- onset_date
- recorded_at
- recorded_by
- source_type
- source_id
- supersedes_id
- void_reason
```

Il rendering grafico deve essere generato dai dati. L'immagine dell'odontogramma può essere prodotta come snapshot leggibile, ma non deve essere l'unica fonte.

## 5.6 Lista dei problemi e diagnosi

La cartella deve mantenere una lista orientata per problemi:

- problema;
- sede/dente;
- stato: sospetto, confermato, risolto, escluso;
- severità;
- evidenze;
- data di insorgenza e diagnosi;
- professionista responsabile;
- collegamento al piano;
- terminologia e versione;
- note differenziali.

Non eliminare una diagnosi esclusa: registrare che è stata esclusa, da chi e sulla base di quale evidenza.

## 5.7 Piano di trattamento

Il piano deve distinguere:

- bisogni e obiettivi;
- alternative;
- benefici e rischi;
- priorità;
- fasi;
- procedure;
- dipendenze;
- professionista previsto;
- tempi;
- costo stimato;
- stato di accettazione;
- consenso collegato;
- motivazione di variazioni e rinunce.

Il preventivo economico è un documento amministrativo collegato al piano, non deve sostituire la descrizione clinica.

## 5.8 Nota della prestazione

Ogni prestazione dovrebbe registrare almeno:

- data, ora e sede;
- professionista e collaboratori;
- motivo della visita;
- valutazione pre-procedura;
- dente/sito;
- procedura eseguita;
- anestetico, dose e lotto quando rilevante;
- materiali e dispositivi;
- identificativi di impianti e componenti;
- esito;
- complicanze;
- istruzioni post-operatorie;
- prescrizioni;
- follow-up;
- allegati;
- firma/finalizzazione.

Le voci precompilate devono essere confermate consapevolmente e non generare note false per default.

## 5.9 Consenso informato

Il consenso clinico non coincide con il consenso privacy. Il sistema deve gestire:

- template versionato;
- procedura o piano cui si riferisce;
- rischi e alternative presentati;
- lingua e modalità di comunicazione;
- soggetto firmatario e titolo;
- data e ora;
- professionista che ha informato;
- firma del paziente e del professionista, secondo la policy;
- revoca o limitazione;
- allegati e materiale informativo consegnato;
- eventuale interprete;
- capacità e rappresentanza per minori o soggetti fragili.

Dopo la firma, il modulo non deve essere modificato. Una nuova versione richiede un nuovo consenso o una integrazione esplicita.

## 5.10 Prescrizioni, certificati e comunicazioni

Separare:

- prescrizione farmacologica;
- richiesta di esame;
- invio a specialista;
- certificazione;
- istruzioni al paziente;
- comunicazione amministrativa;
- comunicazione clinica.

Una e-mail o un messaggio che contiene una decisione clinica deve essere acquisito nella cartella con autore, destinatario, data e contesto.

## 5.11 Immagini e documenti

Tipologie:

- ortopanoramiche;
- endorali;
- CBCT;
- fotografie intraorali/extraorali;
- scansioni;
- impronte digitali;
- file STL/PLY;
- referti radiologici;
- referti istologici;
- documenti di laboratorio;
- prescrizioni protesiche;
- consensi;
- lettere di dimissione o invio.

Ogni oggetto deve avere metadati clinici e non solo un nome file.

# 6. Ciclo di vita dell'informazione clinica

```text
Accettazione paziente
        |
        v
Identificazione e verifica anagrafica
        |
        v
Aggiornamento anamnesi e consensi
        |
        v
Encounter / visita
        |
        +--> osservazioni e odontogramma
        +--> immagini e referti
        +--> diagnosi / lista problemi
        +--> piano e consenso
        +--> procedure e prescrizioni
        |
        v
Revisione del professionista
        |
        v
Finalizzazione / firma / snapshot
        |
        v
Consegna, eventuale FSE, conservazione
        |
        v
Follow-up, addendum, monitoraggio
```

## 6.1 Stati di una nota

| Stato | Significato | Azioni consentite |
|---|---|---|
| Bozza | contenuto in compilazione | modifica, eliminazione controllata |
| Da revisionare | completata ma non finalizzata | revisione, ritorno in bozza |
| Finalizzata | approvata dal professionista | sola lettura, addendum |
| Rettificata | sostituita logicamente da una rettifica | consultazione con collegamento |
| Annullata | non valida ma conservata | consultazione e motivazione |

## 6.2 Regola di correzione

Un addendum deve contenere:

- riferimento all'elemento originale;
- motivo;
- testo della correzione;
- autore;
- data e ora;
- eventuale impatto sul piano o sul paziente;
- notifica agli utenti interessati quando necessaria.

# 7. Architettura informativa

## 7.1 Separare eventi, dati e documenti

Modello raccomandato:

```text
Patient
  |
  +-- Encounter ---------------------------+
  |      |                                 |
  |      +-- Observation                   |
  |      +-- Condition                     |
  |      +-- Procedure                     |
  |      +-- MedicationRequest             |
  |      +-- CarePlan                      |
  |                                        |
  +-- Consent                              |
  +-- Allergy / Medication / History       |
  +-- ImagingStudy ----> DICOM/Object      |
  +-- DocumentReference -> PDF/CDA/File    |
  +-- Provenance / AuditEvent <------------+
```

## 7.2 Entità principali

| Entità | Funzione |
|---|---|
| Tenant | confine organizzativo e di sicurezza |
| Organization/Location | struttura e sede |
| Patient | anagrafica clinica |
| RelatedPerson | tutore, familiare, referente |
| Practitioner | professionista |
| PractitionerRole | ruolo presso una struttura |
| Appointment | pianificazione |
| Encounter | episodio clinico effettivo |
| Observation | misura o riscontro |
| Condition | problema o diagnosi |
| Procedure | atto eseguito |
| CarePlan | piano di trattamento |
| ServiceRequest | richiesta di esame/prestazione |
| MedicationRequest | prescrizione |
| AllergyIntolerance | allergia/reazione |
| Consent | consenso e direttive |
| ImagingStudy | studio di imaging |
| DiagnosticReport | referto |
| DocumentReference | documento e metadati |
| Provenance | origine e trasformazioni |
| AuditEvent | accessi e operazioni |

## 7.3 Identificatori

- UUID interno non significativo;
- identificatori esterni con namespace;
- versione dei code system;
- identificativo univoco del documento;
- hash dell'oggetto;
- correlation ID per transazioni e integrazioni;
- identificatore del modello AI per output algoritmici.

## 7.4 Regole database

- `tenant_id` obbligatorio su tutte le entità cliniche;
- foreign key e vincoli di integrità;
- timestamp in UTC, visualizzazione nel fuso locale;
- autore e provenienza obbligatori;
- campi clinici critici non null quando finalizzati;
- soft delete o stato di annullamento, non cancellazione fisica ordinaria;
- optimistic locking;
- audit separato dal log applicativo;
- versionamento delle terminologie;
- cifratura selettiva per dati particolarmente sensibili, quando utile;
- Row Level Security PostgreSQL come ulteriore barriera, non unico controllo.

## 7.5 Esempio di record clinico API

```json
{
  "id": "0d942f18-7fb1-47c1-8563-e074c7a3549d",
  "tenantId": "clinic-roma-01",
  "patientId": "79f1a25d-5fbf-4afe-a7bb-0c4bd2f9735b",
  "encounterId": "4ab6bb44-903d-4925-b7df-0a02d70a2b1c",
  "type": "DENTAL_FINDING",
  "tooth": "36",
  "surface": "OCCLUSAL",
  "code": {
    "system": "https://dentalcare.example/codes/findings",
    "value": "CARIES_SUSPECTED",
    "version": "2026.1"
  },
  "certainty": "SUSPECTED",
  "source": {
    "type": "CLINICAL_EXAM",
    "reference": null
  },
  "recordedAt": "2026-07-16T11:24:00Z",
  "recordedBy": "practitioner-213",
  "status": "FINAL"
}
```

# 8. Gestione delle immagini dentali

## 8.1 DICOM come fonte primaria quando disponibile

DICOM incorpora immagine e metadati del paziente e dello studio; tali metadati devono essere gestiti con attenzione perché possono contenere dati identificativi [R12].

DentalCare dovrebbe supportare:

- C-STORE o integrazione con PACS, se richiesta;
- DICOMweb per accesso web moderno;
- import di file DICOM;
- JPEG/PNG solo per sorgenti non DICOM;
- associazione a Patient, Encounter e ordine/esame;
- visualizzatore con windowing, zoom e misure appropriate;
- conformance statement per le funzioni DICOM implementate;
- controllo di coerenza fra metadati e paziente selezionato.

## 8.2 Repository MinIO

Struttura logica consigliata:

```text
bucket: dentalcare-clinical
/{tenant-uuid}/{patient-uuid}/{study-uuid}/{object-uuid}
```

Non usare nomi, cognomi o codici fiscali nei path.

Metadati nel database:

- object UUID;
- bucket/key;
- hash SHA-256;
- MIME type;
- dimensione;
- DICOM Study/Series/SOP Instance UID;
- paziente, encounter e ordine;
- uploader e data;
- stato malware scan;
- versione;
- retention class;
- stato di firma/conservazione;
- eventuale pseudonimizzazione.

## 8.3 Controlli in upload

- allowlist formati;
- limite dimensione;
- controllo MIME reale;
- antivirus/antimalware;
- decodifica sicura;
- verifica DICOM;
- quarantena iniziale;
- confronto Patient ID;
- hash e deduplicazione controllata;
- registrazione della provenienza;
- divieto di esposizione pubblica del bucket;
- download tramite URL firmate di breve durata o streaming autorizzato.

## 8.4 De-identificazione

Per ricerca, validazione e training AI:

- non limitarsi a modificare il nome file;
- applicare profili DICOM di de-identificazione;
- rimuovere o trasformare tag identificativi;
- verificare pixel burned-in;
- mantenere una chiave di re-identificazione separata solo se necessaria;
- registrare metodo e versione della procedura;
- effettuare controllo campionario e automatico;
- separare ambiente clinico e ambiente ricerca.

# 9. Documenti, firma e conservazione

## 9.1 Documento nativo digitale

Un documento nativo digitale deve avere:

- contenuto;
- autore;
- data e ora;
- contesto;
- identificatore;
- versione;
- formato;
- impronta/hash;
- stato;
- eventuale firma;
- metadati di classificazione;
- collegamento agli eventi clinici.

## 9.2 Firma e finalizzazione

Non ogni campo del database deve essere firmato digitalmente. È utile adottare livelli diversi:

1. **attribuzione applicativa**: autenticazione forte, utente individuale, timestamp, audit;
2. **finalizzazione clinica**: approvazione esplicita della nota e blocco delle modifiche;
3. **firma elettronica**: per consensi, referti, certificati e documenti previsti dalla policy;
4. **firma qualificata/digitale e marca temporale**: quando richiesta dal flusso o scelta per maggior valore probatorio;
5. **PAdES**: per documenti PDF destinati a specifici flussi, incluso il processo FSE 2.0 descritto nelle specifiche di accreditamento [R6].

La soluzione deve registrare certificato, algoritmo, esito di verifica e data della firma.

## 9.3 Backup non è conservazione

| Funzione | Backup | Conservazione |
|---|---|---|
| Scopo | ripristino tecnico | mantenimento giuridico/documentale |
| Oggetto | database e file | documenti finalizzati e metadati |
| Modificabilità | copie sostituibili | pacchetti e processi controllati |
| Ricerca | tecnica | documentale |
| Evidenze | log di backup | indice, impronte, firme, rapporti |
| Durata | secondo piano DR | secondo massimario/policy |

## 9.4 Politica di conservazione

Creare una matrice per tipologia:

- cartella e note cliniche;
- immagini;
- referti;
- consensi;
- prescrizioni;
- preventivi e fatture;
- log accessi;
- registrazioni vocali;
- dati di telemetria;
- dataset di training;
- backup.

Per ogni categoria indicare:

- finalità;
- base giuridica;
- responsabile;
- periodo;
- evento iniziale;
- sospensione per contenzioso/legal hold;
- modalità di cancellazione;
- necessità di conservazione a norma;
- destino delle copie di backup.

Non inserire nel codice periodi fissi senza una policy approvata. Le regole possono differire tra struttura pubblica, privata, accreditata e singolo professionista.

# 10. Privacy e diritti del paziente

## 10.1 Base giuridica e consenso

Il trattamento necessario alla prestazione sanitaria non deve essere confuso con il consenso informato alla cura o con il consenso a finalità facoltative. Il Garante ha chiarito che la compilazione della cartella clinica non dipende da un consenso privacy, mentre FSE, dossier, ricerca, marketing e ulteriori riusi hanno discipline proprie [R4].

Creare una matrice:

| Trattamento | Finalità | Base/condizione | Consenso separato? |
|---|---|---|---|
| Cartella per cura | diagnosi e trattamento | disciplina sanitaria/GDPR | non come regola generale |
| Consenso clinico | autorizzare trattamento | normativa sanitaria | sì, secondo prestazione |
| Promemoria appuntamenti | gestione servizio | contratto/cura/interesse legittimo valutato | dipende dal canale |
| Marketing | promozione | consenso | sì |
| Dossier multi-evento | continuità interna | disciplina applicabile | da valutare specificamente |
| Training AI | sviluppo/ricerca | base specifica e DPIA | non presumerla |
| Registrazione chiamata | qualità/prova | base e informativa | valutazione dedicata |

## 10.2 Informativa

L'informativa deve descrivere in modo comprensibile:

- titolare;
- DPO, se nominato;
- finalità;
- categorie di dati;
- destinatari e fornitori;
- trasferimenti;
- tempi di conservazione o criteri;
- diritti;
- reclamo;
- eventuale AI;
- eventuale FSE;
- canali di comunicazione;
- conseguenze del mancato conferimento.

## 10.3 Diritti e portale paziente

DentalCare dovrebbe permettere alla struttura di:

- cercare tutti i dati dell'interessato;
- esportarli in formato leggibile;
- fornire documenti necessari alla comprensione;
- correggere dati anagrafici senza alterare documenti storici;
- gestire limitazioni e opposizioni dove applicabili;
- registrare richieste e tempi di risposta;
- produrre un report degli accessi al dossier;
- gestire deleghe e rappresentanza.

Il Garante distingue l'accesso ai dati personali ex articolo 15 GDPR dalla richiesta amministrativa di copia integrale della documentazione; la soluzione deve supportare entrambe le procedure [R4].

## 10.4 DPIA

Una DPIA è fortemente indicata per una piattaforma multi-tenant che tratta sistematicamente dati sanitari, immagini e AI. Deve includere:

- flussi;
- ruoli;
- categorie dati;
- scala;
- tecnologie;
- accessi;
- fornitori;
- trasferimenti;
- minacce;
- misure;
- rischio residuo;
- piano di revisione.

Eventi che richiedono riesame:

- nuovo modulo AI;
- nuova integrazione FSE;
- nuovo fornitore extra SEE;
- registrazione chiamate;
- condivisione tra strutture;
- portale paziente;
- uso secondario dei dati;
- cambiamento della segregazione multi-tenant.

# 11. Identità, ruoli e accessi

## 11.1 Matrice RBAC di riferimento

| Funzione | Segreteria | Odontoiatra assegnato | Igienista assegnato | Amministratore clinico | Amministratore tecnico |
|---|---:|---:|---:|---:|---:|
| Anagrafica | modifica | lettura | lettura minima | modifica | supporto mascherato |
| Appuntamenti | completa | lettura/modifica propri | lettura propri | completa | no contenuto |
| Anamnesi | no o indicatori minimi | completa | secondo protocollo | completa | no |
| Odontogramma | no | completa | limitata | completa | no |
| Note cliniche | no | proprie/assegnate | proprie/assegnate | completa | no |
| Documenti clinici | consegna autorizzata | completa | limitata | completa | no contenuto |
| Dati economici | completa | riepilogo necessario | no | completa | no |
| Audit | no | accessi propri | no | report | log tecnico senza contenuto |
| Configurazione | no | no | no | clinica | tecnica |

## 11.2 Controlli aggiuntivi

- MFA per professionisti e amministratori;
- account individuali;
- SSO OIDC/SAML per clienti enterprise;
- revoca immediata alla cessazione;
- review periodica degli accessi;
- timeout e blocco sessione;
- limitazione download massivi;
- approvazione per esportazioni;
- accesso di assistenza temporaneo e autorizzato;
- registrazione dei tentativi falliti;
- protezione contro credential stuffing.

## 11.3 Break glass

L'accesso di emergenza deve:

- essere disponibile solo a ruoli autorizzati;
- richiedere motivazione;
- avere durata limitata;
- generare alert;
- essere riesaminato;
- essere visibile nei report di audit;
- non aggirare la segregazione tenant.

# 12. Audit trail

## 12.1 Eventi da registrare

- login/logout;
- fallimenti di autenticazione;
- accesso alla cartella;
- visualizzazione di categorie sensibili;
- creazione/modifica/finalizzazione;
- addendum e annullamenti;
- firma;
- download, stampa, export;
- condivisione;
- accesso break glass;
- variazione ruoli;
- migrazione;
- invio FSE;
- consultazione di immagini;
- azione di un agente AI;
- modifica di modello o configurazione;
- accesso amministrativo di supporto.

## 12.2 Campi del log

- event ID;
- tenant;
- utente e ruolo;
- paziente;
- risorsa;
- azione;
- esito;
- data/ora;
- IP e device, quando appropriato;
- sessione;
- motivazione;
- correlation ID;
- versione applicativa;
- prima/dopo per modifiche consentite;
- integrità del log.

## 12.3 Protezione

I log devono essere:

- separati dai normali log applicativi;
- append-only o protetti da alterazioni;
- accessibili solo a funzioni autorizzate;
- sottoposti a retention;
- monitorati;
- esportabili per audit;
- correlati con SIEM;
- minimizzati per non duplicare inutilmente dati clinici.

# 13. Sicurezza tecnica

## 13.1 Architettura di riferimento DentalCare

```text
[Browser / Mobile]
       |
       | TLS + OIDC/MFA
       v
[WAF / API Gateway]
       |
       v
[Angular BFF / Spring Boot APIs]
       |
       +--> [PostgreSQL - dati strutturati]
       +--> [MinIO - immagini e documenti]
       +--> [Audit Service - append only]
       +--> [Identity Provider]
       +--> [Notification Service]
       +--> [FSE Adapter]
       +--> [AI Imaging Service]
       +--> [Voice/LLM Gateway]

Zone separate:
- produzione clinica
- amministrazione
- MLOps/ricerca
- backup/DR
- osservabilità
```

## 13.2 Misure principali

- TLS moderno;
- cifratura database e object storage;
- KMS e rotazione chiavi;
- secret manager;
- segregazione ambienti;
- network policy;
- patch management;
- SAST, DAST e dependency scanning;
- SBOM;
- container signing;
- hardening;
- rate limiting;
- protezione API;
- backup immutabili;
- test di ripristino;
- EDR e monitoring;
- vulnerability management;
- penetration test periodico;
- incident response;
- business continuity.

## 13.3 Multi-tenancy

Difese a strati:

1. autorizzazione applicativa;
2. `tenant_id` obbligatorio;
3. Row Level Security;
4. namespace/bucket policy;
5. cache segregate;
6. code review dedicata;
7. test automatici cross-tenant;
8. chiavi per tenant dove giustificato;
9. amministrazione separata;
10. monitoraggio di query anomale.

Un test di sicurezza deve tentare esplicitamente di accedere a pazienti di un altro tenant modificando ID, URL, token e riferimenti oggetto.

## 13.4 Backup e disaster recovery

Definire:

- RPO;
- RTO;
- frequenza;
- copie separate;
- cifratura;
- immutabilità;
- retention;
- ripristino per tenant e completo;
- test documentati;
- responsabilità;
- comunicazione di crisi.

Non dichiarare “backup effettuato” senza prova di restore.

# 14. Interoperabilità

## 14.1 Strategia duale

- modello interno normalizzato e ricco;
- adapter verso standard esterni.

Non modellare il database copiando direttamente un CDA o un singolo profilo FHIR. Gli standard di scambio evolvono; il dominio interno deve rimanere stabile.

## 14.2 Mappatura FHIR suggerita

| DentalCare | FHIR |
|---|---|
| Paziente | Patient |
| Odontoiatra | Practitioner + PractitionerRole |
| Studio/sede | Organization + Location |
| Visita | Encounter |
| Anamnesi/riscontro | Observation |
| Allergia | AllergyIntolerance |
| Diagnosi/problema | Condition |
| Trattamento eseguito | Procedure |
| Piano | CarePlan |
| Richiesta esame | ServiceRequest |
| Prescrizione | MedicationRequest |
| Studio radiologico | ImagingStudy |
| Referto | DiagnosticReport |
| Documento | DocumentReference |
| Consenso | Consent |
| Provenienza | Provenance |
| Audit | AuditEvent |

L'odontogramma richiede un profilo o modello applicativo dedicato: utilizzare codici dente/superficie e mappature esplicite; non inventare estensioni non governate.

## 14.3 Versioni e profili

La versione “più recente” non è automaticamente quella da usare. FHIR R5 è la versione pubblicata corrente, ma molte integrazioni operative usano R4/R4B. La scelta deve seguire il profilo nazionale o del partner e deve essere registrata nel conformance statement.

## 14.4 FSE 2.0

Per un futuro connettore:

1. generare il documento clinico previsto;
2. costruire CDA2 secondo la specifica applicabile;
3. applicare terminologie e schematron pubblicati;
4. generare il PDF con CDA integrato secondo il flusso richiesto;
5. apporre firma PAdES;
6. autenticarsi con certificati e JWT;
7. invocare validazione;
8. gestire pubblicazione, sostituzione, annullamento e metadati;
9. memorizzare esito, identificatori e ricevute;
10. gestire specificità regionali e accreditamento.

Il repository ufficiale del Ministero descrive controllo sintattico, semantico e terminologico dei CDA2, firma PAdES e uso di certificati X.509/JWT [R6].

## 14.5 European Health Data Space

Il regolamento EHDS stabilisce un quadro europeo per accesso, controllo e scambio dei dati sanitari elettronici [R10]. DentalCare deve prepararsi a:

- esportazione strutturata;
- portabilità;
- identificazione delle categorie prioritarie;
- logging e trasparenza;
- interoperabilità semantica;
- separazione tra uso primario e secondario;
- conformità futura dei sistemi EHR.

# 15. Migrazione dalla carta e dai sistemi legacy

## 15.1 Non digitalizzare tutto allo stesso modo

Classificare il pregresso:

| Categoria | Strategia |
|---|---|
| Pazienti attivi | migrazione strutturata + documenti |
| Pazienti recenti ma inattivi | dati essenziali + scansioni indicizzate |
| Archivio storico | scansione selettiva o accesso legacy controllato |
| Immagini DICOM | migrazione con UID e riconciliazione |
| Consensi | scansione, metadati e verifica |
| Dati economici | migrazione separata |
| Dati non affidabili | import marcato “non verificato” |

## 15.2 Processo di scansione

1. presa in carico e inventario;
2. preparazione fascicolo;
3. assegnazione barcode/ID;
4. scansione;
5. controllo leggibilità e completezza;
6. OCR per indicizzazione, non come fonte clinica automatica;
7. classificazione;
8. associazione al paziente;
9. doppio controllo per campioni o categorie critiche;
10. hash e import;
11. verbale di esito;
12. gestione del cartaceo secondo policy.

Non distruggere il cartaceo subito dopo la scansione senza una decisione documentale e legale.

## 15.3 Migrazione dati strutturati

Fasi:

- profiling;
- mapping;
- cleansing controllato;
- deduplicazione;
- trasformazione;
- caricamento prova;
- riconciliazione;
- approvazione clinica;
- caricamento finale;
- freeze legacy;
- report di migrazione.

## 15.4 Controlli di riconciliazione

- numero pazienti;
- numero cartelle;
- numero documenti;
- numero immagini;
- hash;
- distribuzione per anno;
- campi obbligatori;
- duplicati;
- record orfani;
- associazioni dente/procedura;
- firme e date;
- confronto campionario clinico.

## 15.5 Provenienza del dato migrato

Ogni dato importato deve indicare:

- sistema sorgente;
- identificativo originario;
- data migrazione;
- batch;
- trasformazioni;
- livello di verifica;
- operatore;
- eventuale anomalia.

# 16. Esperienza utente clinica

## 16.1 Ridurre il carico senza perdere qualità

- riepilogo iniziale dei rischi;
- evidenza delle informazioni scadute;
- scorciatoie configurabili;
- template per specialità;
- dettatura con revisione;
- campi strutturati e testo libero bilanciati;
- copia controllata dal precedente;
- firma in pochi passaggi;
- alert solo ad alta rilevanza;
- cronologia visiva;
- confronto odontogrammi;
- accesso rapido all'immagine originale.

## 16.2 Prevenire errori

- conferma paziente persistente nell'interfaccia;
- foto o ulteriori identificatori secondo policy;
- avviso se l'immagine DICOM appartiene a un altro paziente;
- warning su allergie e farmaci;
- blocco per campi clinici essenziali;
- nessuna pre-selezione di “assenza patologie”;
- distinzione netta tra pianificato ed eseguito;
- anteprima prima di firma o invio;
- annullamento guidato;
- nessun uso di colori come unico veicolo informativo.

## 16.3 Accessibilità

- navigazione da tastiera;
- contrasto;
- etichette;
- dimensionamento;
- screen reader;
- alternative testuali;
- linguaggio comprensibile per il portale paziente;
- stampa leggibile.

# 17. Integrazione dell'intelligenza artificiale

## 17.1 Regola fondamentale

L'output AI deve essere conservato come **proposta o osservazione algoritmica**, distinta dalla diagnosi o decisione finale del professionista.

## 17.2 Metadati minimi dell'output radiologico

- paziente e immagine;
- modello e versione;
- checksum dei pesi;
- runtime;
- data e ora;
- preprocessing;
- classe;
- localizzazione;
- confidence;
- soglia;
- qualità input;
- eventuale astensione;
- odontoiatra revisore;
- accettato, modificato o rifiutato;
- esito finale;
- motivo del disaccordo, se raccolto.

## 17.3 Workflow

```text
Immagine originale
      |
      v
Controllo qualità e compatibilità
      |
      v
Inferenza AI --------> log modello/versione
      |
      v
Overlay separato e disattivabile
      |
      v
Revisione odontoiatra
      +--> accetta
      +--> modifica
      +--> rifiuta
      |
      v
Decisione clinica firmata
```

## 17.4 Feedback e riaddestramento

- il feedback non aggiorna il modello in tempo reale;
- la correzione non è automaticamente ground truth;
- occorrono review e adjudication;
- il dataset deve avere base giuridica e provenienza;
- training e produzione devono essere separati;
- ogni nuova versione segue change control e validazione;
- l'output originario rimane ricostruibile.

## 17.5 LLM e assistente vocale

- non inviare cartelle complete a modelli esterni;
- applicare minimizzazione e redazione;
- vietare training del fornitore;
- limitare tool e permessi;
- richiedere conferma umana per azioni sensibili;
- registrare tool call;
- rilevare prompt injection;
- non consentire diagnosi o prescrizione all'assistente amministrativo;
- inserire il risultato nella cartella solo dopo revisione del professionista.

# 18. Piano di implementazione

## Fase 0 — Mandato e perimetro

Deliverable:

- project charter;
- RACI;
- inventario processi;
- data flow;
- risk register;
- classificazione documentale;
- decisioni su tenant e sedi.

Gate: approvazione sponsor, responsabile clinico, DPO e security.

## Fase 1 — Modello clinico e prototipo

- workshop con odontoiatri;
- dataset minimo;
- odontogramma;
- workflow visita;
- consenso;
- nota procedura;
- immagini;
- correzione;
- prototipo UX.

Gate: simulazione completa su casi realistici.

## Fase 2 — Fondazioni tecniche

- IAM;
- tenant isolation;
- PostgreSQL schema;
- MinIO;
- audit;
- document service;
- terminology service;
- backup;
- CI/CD;
- logging e monitoring.

Gate: security architecture review.

## Fase 3 — MVP clinico

- anagrafica;
- anamnesi;
- odontogramma;
- encounter;
- diagnosi;
- piano;
- procedure;
- documenti;
- consensi;
- export cartella;
- audit.

Gate: UAT clinico e DPIA aggiornata.

## Fase 4 — Migrazione pilota

- selezione studio;
- import pazienti;
- scansioni;
- immagini;
- formazione;
- parallel run limitato;
- riconciliazione;
- correzioni.

Gate: verbale di accettazione.

## Fase 5 — Go-live

- freeze;
- migrazione finale;
- supporto;
- monitoraggio;
- piano fallback;
- comunicazione pazienti;
- gestione incidenti.

## Fase 6 — Interoperabilità e AI

Solo dopo stabilità del nucleo:

- FHIR API;
- DICOMweb/PACS;
- FSE adapter;
- portale paziente;
- AI imaging;
- assistente vocale;
- analytics.

# 19. Test e validazione

## 19.1 Test funzionali

- workflow completi;
- stati;
- firme;
- rettifiche;
- deleghe;
- consensi;
- export;
- invii;
- errori;
- concorrenza.

## 19.2 Test clinici

Scenari:

- prima visita;
- urgenza;
- paziente anticoagulato;
- allergia;
- minore;
- piano multiprofessionale;
- impianto;
- endodonzia;
- parodontologia;
- rettifica;
- immagine errata;
- duplicato paziente;
- trasferimento di cura.

Ogni scenario deve essere eseguito da odontoiatri reali con criteri di accettazione.

## 19.3 Test privacy e sicurezza

- accesso non autorizzato;
- cross-tenant;
- escalation privilegio;
- IDOR;
- export massivo;
- URL firmate;
- log tampering;
- MFA bypass;
- perdita sessione;
- restore;
- data breach drill;
- accesso di supporto.

## 19.4 Test di migrazione

- conteggi;
- hash;
- completezza;
- leggibilità;
- mapping;
- duplicati;
- campionamento clinico;
- rollback.

## 19.5 Test interoperabilità

- validazione profili;
- terminologie;
- errori di schema;
- idempotenza;
- retry;
- firma;
- certificati;
- gestione delle ricevute;
- sostituzione e annullamento;
- clock skew;
- indisponibilità partner.

## 19.6 Performance

- apertura cartella;
- rendering odontogramma;
- caricamento immagini;
- upload grandi file;
- ricerca;
- export;
- contemporaneità;
- code asincrone;
- degradazione controllata.

# 20. Formazione e change management

## 20.1 Formazione per ruolo

| Ruolo | Moduli |
|---|---|
| Segreteria | identità, appuntamenti, privacy, documenti, escalation |
| Odontoiatra | cartella, firma, rettifica, consensi, imaging, AI |
| Igienista | workflow assegnati, parodontologia, note |
| Amministratore clinico | ruoli, audit, template, qualità |
| IT | sicurezza, backup, integrazioni, incidenti |
| DPO/Quality | report, diritti, DPIA, audit, conservazione |

## 20.2 Esercitazioni obbligatorie

- paziente duplicato;
- cartella sbagliata;
- rettifica;
- downtime;
- richiesta copia;
- accesso di emergenza;
- data breach;
- output AI errato;
- revoca di un consenso;
- caricamento DICOM incoerente.

## 20.3 Super-user

Ogni sede deve avere super-user clinici e amministrativi, ma non devono ottenere privilegi tecnici indiscriminati.

# 21. Go-live

## 21.1 Checklist

- [ ] DPIA approvata;
- [ ] informative aggiornate;
- [ ] DPA fornitori;
- [ ] ruoli validati;
- [ ] MFA attiva;
- [ ] backup e restore testati;
- [ ] audit funzionante;
- [ ] migration report approvato;
- [ ] formazione completata;
- [ ] supporto e escalation;
- [ ] piano downtime;
- [ ] monitoraggio;
- [ ] template finali;
- [ ] politica firma;
- [ ] politica conservazione;
- [ ] pen test e remediation;
- [ ] approvazione clinica.

## 21.2 Downtime procedure

In caso di indisponibilità:

- identificazione paziente;
- modulo temporaneo controllato;
- registrazione minima sicura;
- accesso a dati critici offline, se previsto;
- numerazione univoca;
- successiva riconciliazione;
- verifica del professionista;
- distruzione/conservazione del supporto temporaneo secondo policy;
- post-incident review.

# 22. Gestione operativa

## 22.1 Change control

Ogni modifica deve indicare:

- richiesta;
- motivazione;
- impatto clinico;
- impatto privacy;
- impatto sicurezza;
- impatto interoperabilità;
- test;
- migrazione;
- formazione;
- rollback;
- approvazione.

## 22.2 Gestione terminologie

- catalogo versionato;
- proprietario;
- mapping;
- data efficacia;
- deprecazioni;
- test;
- tracciabilità nei record storici;
- aggiornamento non retroattivo senza regole esplicite.

## 22.3 Qualità dei dati

Controlli periodici:

- duplicati;
- campi mancanti;
- diagnosi senza piano;
- procedure senza sito;
- consensi mancanti;
- immagini orfane;
- note non finalizzate;
- account inattivi;
- accessi anomali;
- errori FSE;
- dati non verificati dal legacy.

# 23. Indicatori

## 23.1 KPI clinico-operativi

- percentuale cartelle complete;
- anamnesi aggiornata negli ultimi intervalli definiti;
- note finalizzate entro la giornata;
- procedure con dente/sito valorizzato;
- piani con consenso collegato;
- immagini correttamente associate;
- duplicati per 1.000 pazienti;
- tempo medio di apertura cartella;
- rettifiche per modulo;
- incidenti di identificazione.

## 23.2 KPI sicurezza e privacy

- MFA coverage;
- access review completate;
- tentativi cross-tenant;
- esportazioni massive;
- tempo di revoca account;
- vulnerabilità aperte;
- esito restore test;
- data breach;
- richieste interessati e tempi;
- accessi break glass.

## 23.3 KPI interoperabilità

- documenti validati;
- errori per regola;
- retry;
- invii falliti;
- tempo di pubblicazione;
- sostituzioni/annullamenti;
- mismatch terminologici;
- certificati in scadenza.

# 24. Preparazione ai controlli

## 24.1 Evidence pack

Cartelle consigliate:

1. governance;
2. mappa dati;
3. DPIA e privacy;
4. contratti fornitori;
5. architettura e sicurezza;
6. matrice ruoli;
7. audit e access review;
8. politica documentale;
9. firma e conservazione;
10. migrazione;
11. test;
12. formazione;
13. incidenti;
14. interoperabilità;
15. AI;
16. change e release.

## 24.2 Domande tipiche

- Come impedite alla segreteria di vedere le diagnosi?
- Come ricostruite la cartella a una data storica?
- Che cosa accade quando una nota è errata?
- Chi ha scaricato il documento?
- Come individuate accessi fuori dalla relazione di cura?
- Come provate il consenso informato?
- Come verificate che il DICOM appartenga al paziente?
- Dove sono conservate le immagini?
- Il backup è stato ripristinato almeno una volta?
- Quali fornitori possono vedere dati sanitari?
- Come rispondete a una richiesta di accesso?
- Come separate i tenant?
- Come viene autorizzato un addetto all'assistenza?
- Quale versione del modello AI ha generato un reperto?
- Come trasmettete un documento al FSE?

# 25. Requisiti di prodotto per DentalCare Pro

## 25.1 Requisiti P0

- identità paziente e merge duplicati;
- tenant isolation;
- RBAC e assegnazione;
- anamnesi versionata;
- odontogramma strutturato e temporale;
- encounter;
- diagnosi e lista problemi;
- piano e procedure;
- consensi versionati;
- documenti e immagini;
- finalizzazione e addendum;
- audit;
- export completo;
- backup/restore;
- privacy workflow.

## 25.2 Requisiti P1

- portale paziente;
- firma avanzata/qualificata integrata;
- conservazione;
- DICOMweb;
- FHIR API;
- terminology service;
- connettore FSE;
- report accessi;
- analytics qualità;
- moduli parodontali avanzati.

## 25.3 Requisiti P2

- AI radiologica certificata;
- dettatura e summarization controllata;
- federazione tra reti;
- ricerca e secondary use;
- EHDS readiness avanzata;
- integrazione laboratori e dispositivi;
- mobile offline controllato.

# 26. Criteri di accettazione esemplificativi

## 26.1 Nota finalizzata

```gherkin
Dato un odontoiatra autenticato e assegnato al paziente
Quando finalizza una nota clinica completa
Allora il contenuto riceve identificatore, autore, timestamp e hash
E non può più essere modificato direttamente
E ogni correzione avviene tramite addendum
E l'evento è registrato nell'audit trail
```

## 26.2 Segreteria

```gherkin
Dato un utente con ruolo Segreteria
Quando apre il profilo di un paziente
Allora vede anagrafica e appuntamenti
Ma non vede anamnesi, diagnosi, odontogramma o note cliniche
E ogni tentativo diretto alle API cliniche viene negato e registrato
```

## 26.3 Cross-tenant

```gherkin
Dato un token valido per il tenant A
Quando l'utente usa l'identificatore di un paziente del tenant B
Allora la risposta non rivela l'esistenza del record
E l'evento è registrato come tentativo anomalo
```

## 26.4 Output AI

```gherkin
Dato un risultato AI su una ortopanoramica
Quando l'odontoiatra lo revisiona
Allora il sistema conserva risultato originale, modello e confidence
E registra accettazione, modifica o rifiuto
E la diagnosi finale è un oggetto distinto firmato dal professionista
```

# 27. Checklist di valutazione di un fornitore

- [ ] data residency dichiarata;
- [ ] DPA e sub-responsabili;
- [ ] cifratura;
- [ ] MFA/SSO;
- [ ] segregazione tenant;
- [ ] audit accessi;
- [ ] export completo;
- [ ] API documentate;
- [ ] DICOM/FHIR;
- [ ] firma e conservazione;
- [ ] RPO/RTO;
- [ ] restore test;
- [ ] incident notification;
- [ ] pen test;
- [ ] vulnerability management;
- [ ] exit plan;
- [ ] cancellazione verificabile;
- [ ] no training sui dati;
- [ ] change notification;
- [ ] supporto accreditamento FSE;
- [ ] disponibilità di evidenze.

# 28. Errori da evitare

1. scansionare tutto e chiamarlo cartella digitale;
2. usare account condivisi;
3. consentire alla segreteria l'accesso indiscriminato;
4. sovrascrivere note finalizzate;
5. salvare immagini con nome paziente nel filesystem;
6. usare il codice fiscale come chiave primaria;
7. confondere backup e conservazione;
8. inviare dati sanitari a LLM pubblici;
9. generare note precompilate non veritiere;
10. migrare senza riconciliazione;
11. cancellare il cartaceo senza policy;
12. costruire il database copiando un unico standard di scambio;
13. aggiungere il FSE come esportazione manuale non tracciata;
14. addestrare l'AI con correzioni non validate;
15. ignorare la provenienza dei dati;
16. non testare il ripristino;
17. non registrare download e stampe;
18. permettere agli amministratori tecnici di leggere tutto;
19. fare go-live senza downtime procedure;
20. non coinvolgere odontoiatri nei test.

# 29. Roadmap consigliata per DentalCare Pro

## 0–3 mesi

- governance;
- modello dati;
- RBAC;
- prototipo clinico;
- DPIA;
- audit;
- policy documentale;
- piano migrazione.

## 3–6 mesi

- MVP;
- MinIO clinico;
- firme/finalizzazione;
- odontogramma;
- export;
- test;
- pilot.

## 6–12 mesi

- multi-sede;
- portale;
- DICOMweb;
- terminology service;
- conservazione;
- FHIR API;
- connettore FSE proof of concept.

## 12–18 mesi

- accreditamento FSE per documenti scelti;
- AI imaging con percorso regolatorio;
- analytics qualità;
- integrazioni enterprise;
- EHDS readiness.

# 30. Allegato A — Data dictionary minimo

| Campo | Tipo | Obbligatorio | Note |
|---|---|---:|---|
| patient.id | UUID | sì | interno, non significativo |
| patient.tenant_id | UUID | sì | confine di sicurezza |
| patient.fiscal_code | string | no | validato, non PK |
| encounter.id | UUID | sì | episodio |
| encounter.status | enum | sì | planned/in-progress/finished |
| clinical_entry.author | UUID | sì | professionista |
| clinical_entry.recorded_at | instant | sì | UTC |
| clinical_entry.status | enum | sì | draft/final/amended/void |
| clinical_entry.version | integer | sì | concorrenza/versione |
| clinical_entry.hash | string | final | integrità |
| tooth.code | string | se applicabile | FDI |
| surface.code | enum | no | superficie |
| document.object_id | UUID | sì | riferimento MinIO |
| document.mime_type | string | sì | verificato |
| document.sha256 | string | sì | impronta |
| ai_result.model_version | string | se AI | versione esatta |
| provenance.source | string | sì | manuale/import/AI |

# 31. Allegato B — Template di nota odontoiatrica

```text
DATA/ORA:
STRUTTURA:
PROFESSIONISTA:
MOTIVO DELLA VISITA:
ANAMNESI AGGIORNATA: sì/no — variazioni:
ALLERGIE/FARMACI CRITICI:
ESAME CLINICO:
IMMAGINI/ESAMI CONSULTATI:
DIAGNOSI/PROBLEMI:
ALTERNATIVE DISCUSSE:
PIANO CONCORDATO:
PROCEDURA ESEGUITA:
DENTE/SITO:
ANESTESIA E MATERIALI:
COMPLICANZE:
PRESCRIZIONI/ISTRUZIONI:
FOLLOW-UP:
CONSENSO COLLEGATO:
ALLEGATI:
FIRMA/FINALIZZAZIONE:
```

# 32. Allegato C — Registro di migrazione

| Batch | Sorgente | Pazienti | Documenti | Immagini | Errori | Verifica | Approvazione |
|---|---|---:|---:|---:|---:|---|---|
| MIG-001 | gestionale legacy |  |  |  |  |  |  |
| MIG-002 | cartelle cartacee |  |  |  |  |  |  |
| MIG-003 | archivio radiologico |  |  |  |  |  |  |

# 33. Allegato D — Inspection readiness checklist

- [ ] inventario sistemi e dati;
- [ ] organigramma e deleghe;
- [ ] RACI;
- [ ] DPIA;
- [ ] registro trattamenti;
- [ ] informative;
- [ ] DPA;
- [ ] matrice accessi;
- [ ] access review;
- [ ] audit report;
- [ ] document retention schedule;
- [ ] firma e conservazione;
- [ ] backup/restore evidence;
- [ ] migration report;
- [ ] test report;
- [ ] training evidence;
- [ ] incident register;
- [ ] FSE conformance evidence;
- [ ] AI model and output traceability;
- [ ] release e change records.

# 34. Conclusione

Una cartella clinica dentale è realmente digitale quando il sistema non si limita a custodire file, ma governa identità, contesto, significato, responsabilità e storia di ogni informazione.

Per DentalCare Pro la sequenza corretta è:

```text
Governance
   -> modello clinico
      -> identità e accessi
         -> dati strutturati e documenti
            -> integrità e audit
               -> immagini e interoperabilità
                  -> migrazione controllata
                     -> validazione clinica
                        -> go-live
                           -> monitoraggio e miglioramento
```

La priorità iniziale deve essere un nucleo clinico affidabile, semplice da usare e dimostrabile. FSE, portale, AI e automazioni devono essere costruiti sopra questo nucleo, non al suo posto.

# Riferimenti normativi e tecnici

**[R1] Regolamento (UE) 2016/679 — GDPR**  
https://eur-lex.europa.eu/eli/reg/2016/679/oj/ita

**[R2] Garante — Linee guida in tema di FSE e dossier sanitario**  
https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/1634116

**[R3] Garante — FAQ sul dossier sanitario**  
https://www.garanteprivacy.it/faq/dossier-sanitario

**[R4] Garante — Cartelle cliniche e diritto di accesso**  
https://www.garanteprivacy.it/temi/sanita-e-ricerca-scientifica/cartelle-cliniche

**[R5] Decreto 7 settembre 2023 — Fascicolo Sanitario Elettronico 2.0 e modifiche successive**  
https://www.gazzettaufficiale.it/eli/id/2023/10/24/23A05829/sg

**[R6] Ministero della salute — Supporto tecnico FSE 2.0**  
https://github.com/ministero-salute/it-fse-support  
https://github.com/ministero-salute/it-fse-catalogs

**[R7] AgID — Gestione documentale e conservazione**  
https://www.agid.gov.it/it/ambiti-intervento/gestione-documentale

**[R8] AgID — Linee guida sulla formazione, gestione e conservazione dei documenti informatici**  
https://www.agid.gov.it/it/linee-guida

**[R9] Decreto legislativo 7 marzo 2005, n. 82 — Codice dell'amministrazione digitale**  
https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2005-03-07;82

**[R10] Regolamento (UE) 2025/327 — European Health Data Space**  
https://eur-lex.europa.eu/eli/reg/2025/327/oj/ita

**[R11] HL7 FHIR**  
https://hl7.org/fhir/

**[R12] DICOM Standard**  
https://www.dicomstandard.org/current

**[R13] Raccomandazione (UE) 2019/243 — European Electronic Health Record exchange format**  
https://eur-lex.europa.eu/eli/reco/2019/243/oj/ita

**[R14] FNOMCeO — Codice deontologico**  
https://portale.fnomceo.it/codice-deontologico/

---

**Versione del documento:** 1.0  
**Data:** 16 luglio 2026  
**Ambito:** Italia/Unione europea — DentalCare Pro
