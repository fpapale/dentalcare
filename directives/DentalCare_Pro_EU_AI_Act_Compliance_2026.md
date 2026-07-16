# DentalCare Pro — Piano completo di conformità EU AI Act, MDR e GDPR

**Versione:** 1.0  
**Data di riferimento:** 16 luglio 2026  
**Perimetro:** DentalCare Pro / SegretarIA e relativi moduli di intelligenza artificiale  
**Finalità:** predisporre la soluzione, l'organizzazione e le evidenze documentali per l'immissione sul mercato e per eventuali controlli delle autorità.

> **Avvertenza legale**
>
> Questo documento è una guida operativa di compliance e progettazione. Non sostituisce un parere legale, una classificazione MDR formalmente sottoscritta, il confronto con un organismo notificato o le valutazioni del DPO. Prima di utilizzare il modulo radiologico su pazienti reali è necessario validare il perimetro regolatorio con un consulente Regulatory Affairs esperto di Medical Device Software e con un organismo notificato MDR.

---

## 1. Conclusione esecutiva

La prima precisazione è fondamentale:

- l'**EU AI Act è entrato in vigore il 1° agosto 2024**;
- il **2 agosto 2026** diventa applicabile la maggior parte delle disposizioni generali ancora non applicabili, incluse importanti regole di trasparenza e l'avvio dell'enforcement sulle norme già applicabili;
- gli obblighi specifici per i sistemi ad alto rischio incorporati in prodotti regolamentati, tra cui i dispositivi medici, sono stati rinviati dal Digital Omnibus al **2 agosto 2028**;
- alla data del presente documento il Consiglio dell'Unione europea ha approvato definitivamente il Digital Omnibus il 29 giugno 2026; occorre comunque conservare evidenza dell'avvenuta pubblicazione in Gazzetta ufficiale UE e della data di entrata in vigore del testo modificativo.

Per DentalCare non esiste una sola classificazione. La piattaforma deve essere scomposta in sistemi e funzionalità distinte:

1. **gestionale odontoiatrico, agenda, fatturazione e cartella clinica senza inferenza AI**: non è di per sé un sistema AI e normalmente non è un dispositivo medico;
2. **assistente vocale o chatbot per prenotazioni**: sistema AI soggetto almeno a trasparenza, AI literacy, governance, sicurezza e GDPR;
3. **automazioni amministrative con LLM**: normalmente non high-risk, purché non producano valutazioni cliniche o decisioni che incidano sui pazienti;
4. **riassunti o suggerimenti clinici generati da AI**: possono diventare Medical Device Software in funzione dello scopo dichiarato e dell'uso effettivo;
5. **modulo che analizza ortopanoramiche e individua denti, carie, lesioni o altre patologie**: è molto probabilmente Medical Device Software ai sensi del MDR;
6. **pipeline di annotazione e riaddestramento**: fa parte del ciclo di vita regolamentato del prodotto e deve essere governata con procedure formali, versionamento, validazione e change control.

Il modulo radiologico di DentalCare è verosimilmente:

- un **Medical Device Software**;
- almeno **classe IIa MDR** ai sensi della Rule 11, salvo che l'analisi dei rischi e l'intended purpose conducano a IIb o III;
- un sistema AI ad alto rischio ai sensi dell'articolo 6, paragrafo 1, AI Act quando richiede la valutazione di conformità di un organismo notificato.

La regola prudenziale è quindi:

> **Non utilizzare il modulo radiologico su pazienti reali per finalità diagnostiche o terapeutiche prima della necessaria conformità MDR e della marcatura CE.**  
> La qualifica di prototipo, beta, ricerca o “solo supporto” non neutralizza il MDR quando il prodotto viene impiegato nella pratica clinica o presentato con finalità mediche.

---

## 2. Perimetro DentalCare assunto nel presente documento

Il piano considera la seguente architettura funzionale, da confermare formalmente:

- applicazione web Angular;
- backend Spring Boot / Hibernate;
- database PostgreSQL;
- gestione multi-tenant per studi odontoiatrici;
- cartella paziente, anamnesi, odontogramma e piano di trattamento;
- ruoli differenziati per segreteria e odontoiatri;
- repository documentale e immagini in MinIO;
- modulo AI radiologico basato su modelli ONNX;
- modello di identificazione dentale/FDI;
- modello di rilevazione di patologie dentali;
- interfaccia di revisione e annotazione da parte dell'odontoiatra;
- possibile riutilizzo delle annotazioni per il riaddestramento;
- assistente vocale “Giulia” basato su Retell o servizi equivalenti;
- workflow n8n/OpenClaw e modelli linguistici esterni;
- API REST protette da JWT;
- possibile utilizzo futuro in più strutture, anche ospedaliere.

Se una di queste ipotesi cambia, deve essere aggiornata la classificazione regolatoria.

---

# PARTE I — CLASSIFICAZIONE DELLA SOLUZIONE

## 3. Creare immediatamente il Registro dei sistemi AI

DentalCare deve avere un inventario ufficiale, approvato e mantenuto aggiornato. Non è sufficiente un elenco informale delle funzionalità.

### 3.1 Campi minimi del Registro AI

Per ogni sistema o componente registrare:

| Campo | Contenuto richiesto |
|---|---|
| ID univoco | Es. `AI-DC-IMG-001` |
| Nome | Es. DentalCare Imaging Assistant |
| Versione | Versione software e modello |
| Proprietario interno | Responsabile aziendale |
| Scopo previsto | Descrizione controllata e approvata |
| Utenti | Segreteria, odontoiatra, amministratore, paziente |
| Persone interessate | Pazienti, operatori, chiamanti |
| Input | Audio, testo, DICOM, immagini, anamnesi |
| Output | Prenotazione, testo, bounding box, probabilità, alert |
| Modello/fornitore | Proprietario, open source, cloud |
| Hosting | UE, SEE, extra SEE, on-premise |
| Dati personali | Sì/no e categorie |
| Dati sanitari | Sì/no |
| Ruolo AI Act | Provider, deployer, importatore, distributore |
| Classificazione AI Act | Non-AI, trasparenza, high-risk, altro |
| Qualifica MDR | Non-MD, MDSW, da valutare |
| Classe MDR | I, IIa, IIb, III o N/A |
| Stato | Sperimentale, validazione, produzione |
| Documentazione | Collegamenti a fascicolo tecnico e DPIA |
| Rischio residuo | Basso, medio, alto, non accettabile |
| Ultimo riesame | Data e approvatore |

### 3.2 Regola di separazione

Ogni modulo deve poter essere:

- attivato e disattivato separatamente;
- versionato separatamente;
- autorizzato tramite ruoli separati;
- tracciato tramite log distinti;
- commercializzato con claim distinti;
- sottoposto a change control indipendente.

Questo evita che una funzione clinica regolamentata renda ambiguo l'intero prodotto e consente di dimostrare con precisione quale parte è soggetta a MDR e AI Act high-risk.

---

## 4. Classificazione preliminare per modulo

| Modulo DentalCare | AI Act | MDR | Azione |
|---|---|---|---|
| Agenda e prenotazioni tradizionali | Non-AI | Normalmente non MD | Sicurezza, GDPR e qualità software |
| Cartella clinica come archivio | Non-AI | Normalmente non MD | GDPR, controllo accessi, audit log |
| Giulia — voce/chat per appuntamenti | AI con obblighi di trasparenza | Non MD se solo amministrativa | Informare subito che è AI, fallback umano |
| NLP per classificare richieste amministrative | AI non high-risk nella maggior parte dei casi | Non MD | Registro, test, monitoring, privacy |
| LLM che scrive e-mail o promemoria | AI generativa | Non MD | Trasparenza dove applicabile, revisione umana |
| LLM che riassume dati clinici senza suggerire diagnosi | Da valutare | Può diventare MDSW secondo intended purpose | Valutazione Regulatory prima del rilascio |
| LLM che propone diagnosi, terapia o priorità clinica | Probabile high-risk product AI | Probabile MDSW | Percorso MDR completo |
| Analisi ortopanoramica per reperti/patologie | Probabile high-risk ex art. 6(1) | Probabile MDSW IIa o superiore | Organismo notificato e marcatura CE |
| Modello di identificazione denti FDI | Dipende dall'uso | Parte/accessorio del MDSW se usato nel processo diagnostico | Includere nel fascicolo del sistema |
| Interfaccia di annotazione clinica | Parte del ciclo di vita AI | Parte del QMS e data governance | SOP di annotazione e validazione |
| Riaddestramento automatico in produzione | Elevato rischio regolatorio | Modifica potenzialmente sostanziale | Vietarlo salvo piano certificato |
| Analisi aggregate per KPI di studio | Generalmente non high-risk | Non MD | Anonimizzazione, governance e controlli |

---

## 5. Perché il modulo radiologico è probabilmente un dispositivo medico

La qualificazione non dipende dal linguaggio tecnico usato internamente, ma dallo **scopo previsto** dichiarato dal fabbricante e dimostrato anche tramite:

- sito web;
- brochure;
- contratti;
- presentazioni commerciali;
- istruzioni per l'uso;
- schermate dell'applicazione;
- descrizioni negli store;
- materiale di formazione;
- dichiarazioni dei commerciali;
- utilizzo effettivamente incoraggiato.

Un software che cerca nelle immagini mediche reperti a supporto di un'ipotesi diagnostica è espressamente ricondotto dalla guida MDCG alla categoria Medical Device Software.

### 5.1 Intended purpose prudenziale

Una bozza di scopo previsto potrebbe essere:

> DentalCare Imaging Assistant è un software destinato a essere utilizzato da odontoiatri qualificati per supportare l'identificazione e la localizzazione di reperti radiografici predefiniti nelle immagini ortopanoramiche digitali acquisite con dispositivi compatibili. Il software fornisce indicazioni visive e punteggi di confidenza che devono essere verificati dall'odontoiatra. Non formula autonomamente la diagnosi definitiva, non sostituisce l'interpretazione clinica e non determina automaticamente il trattamento.

Questa formulazione:

- non elimina la qualifica di dispositivo medico;
- delimita utenti, immagini, patologie e output;
- deve corrispondere alle prestazioni effettivamente validate;
- non deve includere patologie o modalità di acquisizione non coperte dall'evidenza.

### 5.2 Classificazione MDR

La Rule 11 del MDR prevede, in sintesi:

- classe **IIa** per software che fornisce informazioni usate per decisioni diagnostiche o terapeutiche;
- classe **IIb** se una decisione errata può causare un grave deterioramento della salute o un intervento chirurgico;
- classe **III** se una decisione errata può causare morte o deterioramento irreversibile.

Per DentalCare la classe IIa è un'ipotesi iniziale ragionevole, non una conclusione definitiva. Occorre produrre un **MDR Qualification and Classification Memo** firmato, con:

- intended purpose;
- popolazione;
- utenti;
- patologie;
- flusso clinico;
- gravità delle conseguenze dei falsi negativi e falsi positivi;
- possibili ritardi diagnostici;
- rischio di trattamenti inutili o invasivi;
- ruolo dell'odontoiatra;
- applicazione della Rule 11 e delle implementation rules.

---

## 6. Quando DentalCare diventa “provider” e quando la clinica è “deployer”

### 6.1 DentalCare come provider

DentalCare è normalmente provider quando:

- sviluppa il sistema AI;
- lo commercializza con il proprio nome o marchio;
- determina lo scopo previsto;
- integra modelli di terzi nella propria soluzione;
- modifica sostanzialmente un sistema di terzi;
- mette in servizio il sistema con il proprio marchio.

L'uso di un modello open source o di API di terzi non trasferisce automaticamente la responsabilità al fornitore del modello.

### 6.2 Studio odontoiatrico come deployer

Lo studio è normalmente deployer quando usa DentalCare sotto la propria autorità.

Lo studio deve:

- usare il sistema secondo le istruzioni;
- assegnare operatori competenti;
- esercitare la supervisione umana;
- controllare la pertinenza dei dati di input;
- monitorare anomalie e incidenti;
- conservare i log di propria competenza;
- sospendere l'uso in caso di rischio;
- informare DentalCare di errori e incidenti.

### 6.3 Quando la clinica può diventare provider

La clinica può assumere obblighi da provider se:

- cambia lo scopo previsto;
- rebrandizza il sistema;
- effettua una modifica sostanziale;
- abilita un uso clinico escluso dalle istruzioni;
- riaddestra o modifica il modello fuori dal processo autorizzato.

Questa distinzione deve essere esplicitata nei contratti.

---

# PARTE II — SCADENZE

## 7. Calendario normativo operativo

| Data | Cosa accade | Impatto DentalCare |
|---|---|---|
| 1 agosto 2024 | Entrata in vigore dell'AI Act | Avvio del programma di compliance |
| 2 febbraio 2025 | Applicazione divieti e AI literacy | Obblighi già vigenti |
| 2 agosto 2025 | Governance e GPAI | Due diligence sui modelli generali |
| 2 agosto 2026 | Applicazione della maggioranza delle altre norme e trasparenza art. 50 | Scadenza immediata per voce/chat e governance |
| 2 dicembre 2026 | Termine collegato ad alcune nuove regole del Digital Omnibus, inclusa la transizione per marcatura dei contenuti sintetici prevista dal testo modificativo | Verificare applicabilità ai contenuti generati |
| 2 dicembre 2027 | Obblighi high-risk per sistemi standalone dell'Annex III | Potenzialmente non centrale per il modulo medico |
| 2 agosto 2028 | Obblighi high-risk per sistemi incorporati in prodotti dell'Annex I | Data chiave AI Act per il modulo radiologico MDSW |

> **Controllo legale obbligatorio**
>
> Conservare nel fascicolo una copia del Digital Omnibus pubblicato nella Gazzetta ufficiale dell'Unione europea. Alla data del 16 luglio 2026 il Consiglio aveva annunciato la pubblicazione “a breve”. Il responsabile legale/regolatorio deve verificare numero, data di pubblicazione e testo definitivo prima di approvare la timeline aziendale.

---

# PARTE III — COSA FARE ENTRO IL 2 AGOSTO 2026

## 8. Pacchetto minimo non rinviabile

Entro il 2 agosto 2026 DentalCare deve almeno completare le seguenti attività.

### 8.1 Registro AI approvato

- [ ] Tutti i sistemi AI sono inventariati.
- [ ] Ogni sistema ha proprietario e responsabile.
- [ ] È registrata la versione del modello.
- [ ] Sono definiti provider, deployer e fornitori.
- [ ] È presente una classificazione preliminare AI Act/MDR.
- [ ] È definito lo stato: test, ricerca, pilota, produzione.
- [ ] Le funzionalità non approvate sono disabilitate in produzione.

### 8.2 Policy aziendale sull'uso dell'AI

La policy deve vietare almeno:

- inserimento non autorizzato di dati sanitari in chatbot pubblici;
- utilizzo di account personali per dati DentalCare;
- generazione automatica di diagnosi non approvate;
- uso di output AI senza verifica nei processi clinici;
- riaddestramento diretto sui dati di produzione;
- copia di immagini o dati paziente in ambienti non autorizzati;
- modifica di prompt, modelli o soglie direttamente in produzione;
- uso di strumenti AI non censiti;
- esportazione di dati verso paesi terzi senza valutazione privacy;
- profilazione discriminatoria o accesso differenziato alle cure.

### 8.3 AI literacy

L'obbligo di alfabetizzazione AI è già applicabile.

Creare un programma formativo differenziato:

| Destinatari | Contenuti |
|---|---|
| Sviluppatori | AI Act, secure SDLC, data leakage, bias, validation |
| Data scientist | dataset governance, metriche cliniche, drift, change control |
| Product manager | intended purpose, claim control, classificazione |
| Commerciali | claim consentiti e vietati |
| Supporto | raccolta incidenti, escalation, comunicazioni |
| Odontoiatri | limiti del modello, falsi negativi/positivi, override |
| Segreteria | trasparenza, uso dell'assistente, privacy |
| Management | responsabilità, rischi, sanzioni, decisioni di rilascio |

Evidenze da conservare:

- piano formativo;
- materiali;
- registro partecipanti;
- test di apprendimento;
- data e durata;
- qualifica del docente;
- aggiornamenti periodici;
- formazione specifica per ogni nuova versione.

### 8.4 Trasparenza dell'assistente Giulia

All'inizio di ogni interazione:

> “Buongiorno, sono Giulia, l'assistente virtuale basata su intelligenza artificiale di [nome studio]. Posso aiutarla con appuntamenti e informazioni amministrative. In qualsiasi momento può chiedere di parlare con un operatore.”

Il messaggio:

- deve essere pronunciato prima di raccogliere informazioni significative;
- non deve essere nascosto in termini e condizioni;
- deve essere comprensibile;
- deve essere disponibile anche per persone con disabilità;
- deve indicare come raggiungere un operatore umano.

Se la chiamata è registrata, l'informativa sulla registrazione è distinta dall'informazione che si sta parlando con un'AI.

### 8.5 Limiti operativi di Giulia

Giulia deve:

- gestire appuntamenti e informazioni amministrative;
- non diagnosticare;
- non valutare urgenze cliniche autonomamente;
- non prescrivere;
- non modificare terapie;
- non interpretare referti;
- indirizzare emergenze e richieste cliniche a una persona;
- applicare regole deterministiche per escalation;
- interrompere l'automazione quando l'utente è confuso o vulnerabile;
- consentire sempre il fallback umano.

Esempio:

> “Non posso valutare clinicamente il sintomo. La metto in contatto con lo studio. In caso di emergenza sanitaria contatti i servizi di emergenza competenti.”

### 8.6 Informazione ai pazienti sull'uso sanitario dell'AI

La legge italiana n. 132/2025 riconosce il diritto dell'interessato a essere informato dell'impiego di AI in sanità e stabilisce che la decisione resta al professionista sanitario.

Predisporre:

- informativa breve nell'interfaccia;
- sezione estesa nella documentazione del paziente;
- indicazione nel referto o nella schermata quando è usato il modulo radiologico;
- descrizione del ruolo dell'odontoiatra;
- limiti e possibilità di errore;
- canale per domande e reclami;
- aggiornamento dell'informativa privacy.

Formula esemplificativa:

> “Per supportare l'odontoiatra nell'esame dell'immagine radiografica, la struttura può utilizzare un software di intelligenza artificiale che evidenzia possibili reperti. Il risultato è sottoposto alla verifica del professionista e non determina automaticamente diagnosi o trattamento.”

### 8.7 Privacy e DPIA

Prima dell'uso su larga scala di dati sanitari e AI:

- [ ] definire titolare e responsabili;
- [ ] aggiornare il registro dei trattamenti;
- [ ] completare una DPIA;
- [ ] definire basi giuridiche;
- [ ] applicare minimizzazione;
- [ ] determinare tempi di conservazione;
- [ ] valutare trasferimenti extra SEE;
- [ ] stipulare DPA ex art. 28 GDPR;
- [ ] predisporre misure di sicurezza;
- [ ] definire gestione degli interessati;
- [ ] gestire data breach;
- [ ] separare trattamento assistenziale e training.

Il consenso privacy non è una scorciatoia universale. La base giuridica deve essere identificata per ogni trattamento.

---

# PARTE IV — PERCORSO MDR E HIGH-RISK PER IL MODULO RADIOLOGICO

## 9. Gate “no clinical release”

Introdurre un gate formale:

> Nessuna versione del modulo radiologico può essere resa disponibile per decisioni cliniche reali senza approvazione Regulatory, Quality, Clinical Safety, Security e DPO.

Possibili ambienti:

1. **sviluppo**: dati sintetici o adeguatamente pseudonimizzati;
2. **validazione offline**: nessun output mostrato per la cura;
3. **studio clinico/real-world testing autorizzato**: protocollo e autorizzazioni;
4. **produzione clinica CE**: solo versione certificata;
5. **shadow mode**: output non visibile o non usato nella decisione, comunque previa valutazione legale e privacy.

---

## 10. Sistema di gestione della qualità

Per un MDSW di classe IIa o superiore serve un QMS coerente con il MDR.

SOP minime:

- controllo documenti;
- controllo registrazioni;
- sviluppo software;
- requisiti e design;
- verifica e validazione;
- gestione configurazione;
- gestione rischi;
- data governance;
- annotazione;
- training e validation dei modelli;
- cybersecurity;
- gestione fornitori;
- gestione reclami;
- vigilanza;
- CAPA;
- audit interni;
- post-market surveillance;
- PMCF;
- gestione change e release;
- gestione incidenti AI;
- formazione;
- conservazione dei log;
- backup e disaster recovery;
- decommissioning.

Standard utili come base, previa verifica delle versioni e dello stato di armonizzazione:

- ISO 13485;
- ISO 14971;
- IEC 62304;
- IEC 62366-1;
- IEC 81001-5-1;
- ISO/IEC 27001;
- ISO/IEC 42001;
- ISO/IEC 23894.

L'adozione di uno standard non equivale automaticamente a conformità normativa, ma fornisce struttura, evidenze e controlli.

---

## 11. Fascicolo tecnico del modulo radiologico

Indice minimo consigliato:

1. descrizione del dispositivo;
2. intended purpose;
3. utenti e popolazione;
4. indicazioni e controindicazioni;
5. varianti e configurazioni;
6. architettura software;
7. dipendenze;
8. modelli AI e versioni;
9. requisiti funzionali e di sicurezza;
10. design;
11. software bill of materials;
12. file di gestione dei rischi;
13. data management plan;
14. documentazione dei dataset;
15. procedura di annotazione;
16. piano e report di verifica;
17. piano e report di validazione;
18. clinical evaluation plan;
19. clinical evaluation report;
20. cybersecurity file;
21. usability engineering file;
22. istruzioni per l'uso;
23. etichettatura;
24. dichiarazione UE di conformità;
25. PMS plan;
26. PMCF plan;
27. PSUR, se applicabile;
28. procedure di vigilanza;
29. piano di change control;
30. mappatura AI Act articoli 8-15;
31. log design;
32. human oversight plan;
33. model card;
34. performance report;
35. bias and subgroup report;
36. supplier evidence;
37. record delle release.

---

## 12. Gestione dei rischi

Il risk management deve coprire rischi clinici, tecnici, organizzativi, privacy e diritti fondamentali.

### 12.1 Hazard principali

- mancata rilevazione di carie;
- mancata rilevazione di lesioni periapicali;
- falso positivo;
- errata numerazione FDI;
- associazione della lesione al dente sbagliato;
- output su immagine non compatibile;
- immagine di qualità insufficiente;
- uso su popolazione non validata;
- errore dovuto al dispositivo radiografico;
- dataset non rappresentativo;
- automation bias;
- eccessiva fiducia dell'odontoiatra;
- alert fatigue;
- modello o soglia sbagliata in produzione;
- mismatch fra frontend, backend e modello;
- corruzione dell'immagine;
- mancata corrispondenza paziente/immagine;
- accesso non autorizzato;
- manipolazione del modello;
- prompt injection nei moduli LLM;
- esfiltrazione di dati;
- drift;
- aggiornamento non validato;
- perdita dei log;
- indisponibilità del servizio;
- uso off-label;
- traduzione errata dell'interfaccia;
- discriminazione indiretta;
- mancata informazione del paziente.

### 12.2 Controlli

- verifica qualità immagine;
- rifiuto/abstention sotto soglia;
- visualizzazione del livello di confidenza;
- indicazione della versione;
- avviso sui limiti;
- verifica obbligatoria del dentista;
- possibilità di confermare, modificare o rifiutare;
- divieto di trasferire automaticamente l'output nel referto definitivo;
- soglie validate;
- test per device e centro;
- monitoring;
- rollback;
- firme e approvazioni di release;
- RBAC;
- MFA;
- cifratura;
- segregazione tenant;
- audit log;
- incident response.

---

## 13. Data governance

### 13.1 Provenienza e liceità

Per ogni dataset documentare:

- origine;
- titolare;
- licenza;
- diritti d'uso;
- consenso o altra base giuridica;
- finalità originaria;
- compatibilità del riuso;
- autorizzazioni;
- pseudonimizzazione;
- metodo di trasferimento;
- restrizioni;
- periodo di conservazione;
- referente.

Non utilizzare dati scaricati o ricevuti senza catena documentale.

### 13.2 Separazione dei dataset

Mantenere separati:

- training;
- validation;
- test interno;
- test esterno;
- test per sito;
- challenge set;
- post-market set.

Prevenire il leakage:

- split per paziente, non solo per immagine;
- controllo dei duplicati;
- controllo di immagini derivate;
- controllo degli hash;
- attenzione a più esami dello stesso paziente;
- nessun tuning sul test set finale.

### 13.3 Rappresentatività

Analizzare almeno:

- età;
- sesso, quando rilevante e lecito;
- qualità radiografica;
- fabbricante/modello del dispositivo;
- risoluzione;
- protocolli di acquisizione;
- sito clinico;
- popolazione geografica;
- presenza di restauri, impianti e apparecchi;
- edentulia;
- patologie concomitanti;
- casi pediatrici, se inclusi;
- distribuzione delle classi.

Le categorie sensibili devono essere trattate solo con base giuridica e necessità documentata.

### 13.4 Annotazione

La SOP deve definire:

- qualifiche degli annotatori;
- istruzioni;
- tassonomia delle patologie;
- formato;
- regole per casi dubbi;
- doppia lettura;
- adjudication;
- controllo qualità;
- misura dell'accordo inter-rater;
- tracciamento delle correzioni;
- blind review;
- gestione dei conflitti;
- versione delle linee guida.

### 13.5 Dataset card

Per ogni dataset creare una scheda con:

- scopo;
- origine;
- popolazione;
- criteri inclusione/esclusione;
- preprocessing;
- labeling;
- distribuzione;
- missing data;
- limitazioni;
- bias;
- licenza;
- privacy;
- split;
- versione;
- approvazione.

---

## 14. Metriche di validazione

Non limitarsi a mAP o accuracy tecnica.

Per ogni patologia e per il sistema complessivo considerare:

- sensitivity/recall;
- specificity;
- precision/PPV;
- NPV;
- F1;
- ROC-AUC, se appropriata;
- PR-AUC per classi rare;
- tasso di falsi negativi;
- tasso di falsi positivi;
- localizzazione;
- IoU;
- calibration;
- intervalli di confidenza;
- prestazioni per sottogruppo;
- prestazioni per dispositivo;
- prestazioni per centro;
- prestazioni su immagini degradate;
- tasso di astensione;
- tempo di elaborazione;
- stabilità;
- riproducibilità;
- beneficio clinico;
- impatto sul flusso;
- errori dell'utente;
- performance uomo vs AI vs uomo+AI.

Definire in anticipo:

- endpoint primario;
- soglie di accettazione;
- numerosità;
- analisi statistica;
- gestione dei casi esclusi;
- protocol deviations;
- criteri di fallimento.

---

## 15. Valutazione clinica

La valutazione clinica deve dimostrare:

- validità dell'associazione fra output e condizione clinica;
- prestazioni tecniche;
- prestazioni cliniche;
- sicurezza;
- beneficio clinico;
- rapporto beneficio/rischio;
- stato dell'arte;
- equivalenza, solo se realmente dimostrabile;
- adeguatezza per utenti e popolazione;
- generalizzabilità;
- limiti.

Documenti:

- Clinical Evaluation Plan;
- protocollo;
- Statistical Analysis Plan;
- Clinical Evaluation Report;
- ricerca bibliografica;
- appraisal della letteratura;
- report di validazione esterna;
- PMCF Plan;
- PMCF Evaluation Report.

Per prove su dati reali o in real-world conditions valutare:

- MDR;
- norme nazionali;
- comitato etico;
- consenso informato, ove richiesto;
- GDPR;
- autorizzazioni della struttura;
- assicurazione;
- registrazione dello studio.

---

## 16. Supervisione umana

La supervisione non può essere solo una frase nell'interfaccia.

### 16.1 Requisiti di prodotto

L'odontoiatra deve poter:

- capire che l'output è generato da AI;
- vedere lo scopo e i limiti;
- conoscere la versione;
- vedere confidenza e qualità;
- ignorare l'output;
- correggere il dente;
- eliminare il reperto;
- aggiungere un reperto;
- motivare il disaccordo;
- segnalare un errore;
- accedere all'immagine originale;
- completare la lettura senza AI;
- sapere quando il sistema non è affidabile.

### 16.2 Prevenzione dell'automation bias

- nessuna evidenziazione eccessivamente persuasiva;
- ordine di visualizzazione valutato con usability test;
- possibilità di lettura indipendente prima dell'output;
- formazione sui falsi negativi;
- nessuna conferma pre-selezionata;
- nessuna copia automatica nel referto;
- monitoraggio dei tassi di override;
- analisi di dipendenza eccessiva;
- feedback non usato automaticamente per training.

### 16.3 Decisione clinica

Il referto, la diagnosi e il trattamento devono essere attribuiti al professionista.

Il log deve distinguere:

- output AI;
- revisione umana;
- risultato finale;
- eventuale divergenza;
- autore;
- data e ora.

---

## 17. Logging e tracciabilità

### 17.1 Log minimi di inferenza

- tenant;
- struttura;
- ID pseudonimo paziente;
- ID immagine;
- hash input;
- data/ora;
- modello;
- versione pesi;
- versione runtime;
- preprocessing;
- soglie;
- configurazione;
- output;
- confidenza;
- qualità input;
- errori;
- latenza;
- utente che ha revisionato;
- conferma/override;
- versione UI/backend.

### 17.2 Protezione dei log

- integrità;
- accesso limitato;
- cifratura;
- sincronizzazione temporale;
- retention;
- backup;
- esportabilità;
- ricerca;
- segregazione tenant;
- prevenzione di alterazioni;
- audit degli accessi;
- minimizzazione dei dati sanitari.

### 17.3 Evidenza di versione

In ogni risultato deve essere possibile ricostruire esattamente:

- quale modello;
- quale codice;
- quale configurazione;
- quale dataset di validazione;
- quale documentazione;
- quale approvazione.

---

## 18. Change control e riaddestramento

### 18.1 Vietare l'online learning non controllato

La versione di produzione deve essere congelata.

Le correzioni degli odontoiatri:

- sono feedback;
- non diventano automaticamente ground truth;
- non aggiornano il modello in tempo reale;
- devono passare per review, adjudication e data governance.

### 18.2 Ogni nuova versione richiede

1. change request;
2. analisi impatto;
3. valutazione MDR;
4. valutazione AI Act;
5. aggiornamento risk file;
6. aggiornamento cybersecurity;
7. aggiornamento dataset card;
8. training documentato;
9. verifica;
10. validazione;
11. clinical evaluation update;
12. approvazione;
13. deployment controllato;
14. rollback plan;
15. post-release monitoring.

### 18.3 Modifica sostanziale

Una modifica può richiedere nuova valutazione di conformità quando cambia:

- scopo;
- patologie;
- popolazione;
- modalità;
- algoritmo;
- architettura;
- output;
- prestazioni;
- profilo di rischio;
- human oversight;
- comportamento adattivo;
- condizioni d'uso.

Non affidarsi solo al version number.

---

## 19. Cybersecurity

### 19.1 Controlli architetturali

- MFA per ruoli privilegiati;
- SSO/OIDC;
- RBAC e principio del minimo privilegio;
- segregazione tenant a livello applicativo e database;
- cifratura in transito e a riposo;
- gestione centralizzata dei segreti;
- KMS;
- rotazione chiavi;
- hardening container;
- image signing;
- SBOM;
- scansione vulnerabilità;
- patch management;
- WAF/API gateway;
- rate limiting;
- protezione upload DICOM;
- malware scanning;
- validazione formati;
- sicurezza MinIO;
- backup immutabili;
- disaster recovery;
- monitoring;
- alerting;
- penetration test;
- secure SDLC;
- SAST, DAST, SCA;
- gestione incidenti;
- business continuity.

### 19.2 Sicurezza ML

- firma e hash dei pesi;
- repository modelli protetto;
- controllo degli artefatti;
- prevenzione model substitution;
- controllo dataset poisoning;
- provenance;
- accesso limitato al training;
- validazione prima del deploy;
- monitoraggio drift;
- protezione API;
- adversarial testing proporzionato;
- sicurezza dei notebook;
- isolamento ambienti;
- divieto di download non autorizzato dei dati.

### 19.3 Sicurezza LLM e agenti

- prompt injection testing;
- allowlist degli strumenti;
- autorizzazioni per singolo tool;
- conferma umana per azioni sensibili;
- nessun accesso diretto indiscriminato al database;
- output validation;
- limiti di contesto;
- redazione dati;
- separazione tenant;
- protezione dei system prompt;
- audit delle tool call;
- rate limiting;
- kill switch;
- gestione hallucination;
- test di data exfiltration;
- protezione da indirect prompt injection nei documenti.

---

# PARTE V — GDPR E DATI SANITARI

## 20. Ruoli privacy

Definire contrattualmente:

- studio odontoiatrico come titolare per il trattamento assistenziale, nella configurazione più comune;
- DentalCare come responsabile del trattamento per l'erogazione SaaS, se opera su istruzioni;
- DentalCare come autonomo titolare per finalità proprie solo quando esiste una base chiara e indipendente;
- sub-responsabili per cloud, Retell, LLM, e-mail, SMS, monitoring;
- contitolarità solo se effettivamente ricorrono decisioni congiunte su finalità e mezzi.

Non usare formule standard non aderenti alla realtà.

---

## 21. DPIA DentalCare

La DPIA deve coprire almeno:

- descrizione dei flussi;
- finalità;
- categorie dati;
- interessati;
- fonti;
- destinatari;
- trasferimenti;
- tecnologie;
- necessità e proporzionalità;
- rischi;
- misure;
- consultazione del DPO;
- rischio residuo;
- riesame.

Scenari specifici:

- cartella clinica;
- immagini;
- AI radiologica;
- registrazioni vocali;
- trascrizioni;
- modelli linguistici;
- training;
- telemetria;
- log;
- ricerca;
- assistenza remota;
- multi-tenancy;
- backup.

---

## 22. Training sui dati dei pazienti

Prima di riutilizzare dati clinici per addestrare DentalCare:

- distinguere cura, validazione, ricerca e sviluppo prodotto;
- stabilire il ruolo privacy;
- identificare base giuridica ex artt. 6 e 9 GDPR;
- valutare normativa sanitaria e ricerca;
- informare gli interessati;
- rispettare limitazione della finalità;
- minimizzare;
- pseudonimizzare;
- valutare anonimizzazione reale;
- gestire diritti;
- definire retention;
- documentare accessi;
- impedire il ritorno dei dati a fornitori per loro training;
- valutare DPIA separata;
- approvare il progetto tramite governance.

La pseudonimizzazione non trasforma automaticamente i dati in anonimi.

---

## 23. Fornitori extra SEE

Per Retell, provider LLM, servizi di speech-to-text o cloud:

- verificare sede e data location;
- elenco sub-processors;
- DPA;
- Standard Contractual Clauses, se necessarie;
- Transfer Impact Assessment;
- misure supplementari;
- cifratura;
- controllo delle chiavi;
- retention;
- cancellazione;
- divieto di training;
- uso dei contenuti per abuse monitoring;
- accessi governativi;
- breach notification;
- audit;
- export;
- portabilità;
- terminazione.

Regola preferita:

> Nessun dato sanitario o identificativo deve essere trasmesso a un fornitore AI senza approvazione DPO, Security e Procurement.

---

# PARTE VI — FORNITORI E CATENA DEL VALORE

## 24. Due diligence obbligatoria

Per ogni fornitore raccogliere:

- descrizione servizio;
- ruolo AI Act;
- documentazione del modello;
- versione;
- condizioni di modifica;
- sicurezza;
- certificazioni;
- subfornitori;
- localizzazione dati;
- log;
- disponibilità;
- SLA;
- incidenti;
- continuità;
- data use;
- IP;
- licenze;
- export control;
- supporto regolatorio;
- diritto di audit;
- preavviso modifiche;
- piano di uscita.

### 24.1 Clausole contrattuali essenziali

- nessun training sui dati DentalCare;
- uso solo su istruzioni;
- separazione tenant;
- cancellazione verificabile;
- tempi di notifica incidenti;
- accesso a evidenze;
- cooperazione con autorità;
- supporto alla DPIA;
- supporto a richieste interessati;
- log esportabili;
- version freeze o change notice;
- disclosure dei sub-processors;
- requisiti di sicurezza;
- responsabilità;
- indennizzi;
- continuità;
- exit;
- restituzione dati;
- divieto di reidentificazione.

---

# PARTE VII — POST-MARKET E INCIDENTI

## 25. Post-market monitoring

Il piano deve definire:

- dati raccolti;
- indicatori;
- frequenza;
- soglie;
- responsabilità;
- segnalazioni;
- trend;
- reclami;
- drift;
- bias;
- performance;
- falsi negativi;
- falsi positivi;
- incidenti;
- cybersecurity;
- CAPA;
- comunicazioni;
- aggiornamenti.

### 25.1 KPI consigliati

- tasso di uso;
- tasso di override;
- errori confermati;
- errori per patologia;
- errori per device;
- immagini rifiutate;
- drift;
- tempi;
- indisponibilità;
- reclami;
- incidenti;
- accessi anomali;
- security events;
- distribuzione per centro;
- numero di casi fuori intended purpose.

---

## 26. Incident response integrato

Creare una matrice unica che colleghi:

- incidente AI Act;
- incidente grave MDR;
- data breach GDPR;
- incidente NIS2, se applicabile;
- problema di cybersecurity;
- reclamo cliente;
- non conformità QMS.

Flusso:

1. rilevazione;
2. triage;
3. contenimento;
4. preservazione evidenze;
5. valutazione clinica;
6. valutazione privacy;
7. valutazione sicurezza;
8. valutazione reporting;
9. notifica;
10. comunicazione clienti;
11. correzione;
12. CAPA;
13. verifica efficacia;
14. chiusura;
15. trend analysis.

Predisporre numeri e canali 24/7 per eventi gravi.

---

# PARTE VIII — COME PREPARARSI AI CONTROLLI

## 27. Autorità potenzialmente coinvolte in Italia

- **ACN**: autorità di vigilanza del mercato AI e punto di contatto unico; può svolgere attività ispettive e sanzionatorie;
- **AgID**: autorità di notifica e funzioni relative agli organismi di valutazione della conformità AI;
- **Garante per la protezione dei dati personali**: GDPR, dati sanitari, DPIA, data breach;
- **autorità competente sui dispositivi medici / Ministero della salute**: MDR;
- **organismo notificato**: valutazione QMS e fascicolo per il dispositivo;
- altre autorità in funzione del cliente o contesto.

---

## 28. Inspection Readiness Binder

Creare un repository controllato con indice e proprietari.

### Cartella 01 — Governance

- organigramma;
- deleghe;
- RACI;
- comitato AI;
- verbali;
- policy;
- budget;
- obiettivi;
- conflitti;
- escalation.

### Cartella 02 — Inventario e classificazione

- registro AI;
- qualification memo;
- MDR classification memo;
- provider/deployer memo;
- legal opinions;
- registro claim;
- perimetro versioni.

### Cartella 03 — QMS

- manuale qualità;
- SOP;
- moduli;
- training;
- audit;
- CAPA;
- management review.

### Cartella 04 — Risk management

- piano;
- hazard analysis;
- FMEA;
- risk controls;
- verification;
- residual risk;
- benefit-risk;
- produzione/post-market.

### Cartella 05 — Dati

- DMP;
- dataset cards;
- licenze;
- provenance;
- labeling;
- quality checks;
- split;
- bias;
- privacy.

### Cartella 06 — Sviluppo

- requisiti;
- design;
- architecture;
- code review;
- testing;
- traceability matrix;
- SBOM;
- release records.

### Cartella 07 — AI/ML

- model card;
- training configuration;
- hyperparameters;
- seed;
- environment;
- metrics;
- subgroup analysis;
- calibration;
- drift;
- limitations;
- reproducibility.

### Cartella 08 — Clinical

- CEP;
- CER;
- protocolli;
- evidenza;
- statistiche;
- studi;
- PMCF.

### Cartella 09 — Human oversight e usability

- HFE/usability;
- formative test;
- summative test;
- IFU;
- formazione;
- override;
- UI rationale.

### Cartella 10 — Cybersecurity

- threat model;
- security risk;
- penetration test;
- vulnerability management;
- incident response;
- backup/DR;
- access review.

### Cartella 11 — Privacy

- ROPA;
- DPIA;
- DPA;
- SCC/TIA;
- informative;
- data retention;
- diritti;
- data breach.

### Cartella 12 — Fornitori

- onboarding;
- questionnaire;
- contratti;
- SLA;
- audit;
- sub-processors;
- change notices.

### Cartella 13 — Trasparenza

- script Giulia;
- schermate;
- informative;
- versioni;
- accessibility;
- test;
- prova di rilascio.

### Cartella 14 — Post-market

- PMS;
- PMCF;
- reclami;
- incidenti;
- trend;
- CAPA;
- PSUR;
- field actions.

### Cartella 15 — Release e change

- change request;
- impact assessment;
- approvals;
- deployment evidence;
- rollback;
- release note;
- decommissioning.

---

## 29. Domande tipiche durante un controllo

DentalCare deve saper rispondere immediatamente a domande come:

1. Quali sistemi AI avete in produzione?
2. Qual è lo scopo di ciascun sistema?
3. Perché non è high-risk o perché lo è?
4. Perché il modulo radiologico è classe IIa e non IIb?
5. Quale versione è stata usata sul paziente X?
6. Quali dati sono stati usati per il training?
7. Avete il diritto di usare quei dati?
8. Come avete evitato leakage?
9. Quali sono sensitivity e false negative rate?
10. Come varia la performance tra dispositivi?
11. Quali popolazioni non sono validate?
12. Come viene informato il paziente?
13. Chi prende la decisione?
14. Come si esercita l'override?
15. Che cosa accade quando il modello non è sicuro?
16. Come monitorate il drift?
17. Avete modificato il modello dopo il rilascio?
18. Come approvate una nuova versione?
19. Quali fornitori vedono i dati?
20. I fornitori usano i dati per training?
21. Dove sono conservati i dati?
22. Quali trasferimenti extra SEE esistono?
23. Quali incidenti avete avuto?
24. Quali CAPA avete aperto?
25. Chi è formato?
26. Quali prove avete della formazione?
27. Quali claim sono autorizzati?
28. Come impedite l'uso off-label?
29. Come segregate i tenant?
30. Come ricostruite un'inferenza?

---

## 30. Comportamento durante l'ispezione

### Fare

- nominare un inspection coordinator;
- verificare identità e perimetro della richiesta;
- registrare documenti consegnati;
- fornire solo versioni controllate;
- rispondere in modo preciso;
- distinguere fatti e valutazioni;
- preservare evidenze;
- coinvolgere Legal/DPO/Regulatory;
- correggere rapidamente errori;
- cooperare;
- aprire CAPA.

### Non fare

- improvvisare;
- retrodatare;
- alterare log;
- eliminare dati;
- minimizzare incidenti;
- consegnare bozze non controllate come finali;
- attribuire responsabilità al fornitore senza contratto;
- dichiarare “non è dispositivo” senza memo;
- dichiarare prestazioni non dimostrate;
- occultare versioni;
- dare informazioni inesatte o fuorvianti.

---

# PARTE IX — SANZIONI E RISCHI

## 31. AI Act

Massimali europei:

- fino a **35 milioni di euro o 7%** del fatturato mondiale per pratiche vietate;
- fino a **15 milioni di euro o 3%** per diverse violazioni degli obblighi di provider, deployer e trasparenza;
- fino a **7,5 milioni di euro o 1%** per informazioni inesatte, incomplete o fuorvianti fornite alle autorità o agli organismi notificati;
- per PMI e startup si applica, nei casi previsti, il valore inferiore tra importo fisso e percentuale.

Le sanzioni effettive devono essere proporzionate e considerano gravità, durata, danni, cooperazione, misure adottate e dimensione dell'operatore.

## 32. Altri rischi

Oltre alle sanzioni AI Act:

- sanzioni GDPR;
- sospensione del trattamento;
- richiamo o ritiro del dispositivo;
- perdita della marcatura CE;
- responsabilità civile;
- responsabilità contrattuale;
- rischio clinico;
- danno reputazionale;
- esclusione da gare;
- perdita di assicurabilità;
- responsabilità professionale;
- procedimenti penali nei casi applicabili.

---

# PARTE X — RED FLAGS

## 33. Condotte da evitare

### 33.1 Commercializzare come “beta” su pazienti

Una beta clinica resta uso clinico. La parola beta non sostituisce MDR, autorizzazioni, validazione o vigilanza.

### 33.2 Scrivere “non sostituisce il medico” e basta

Il disclaimer è utile per la supervisione, ma non cancella la destinazione medica.

### 33.3 Fare claim più ampi dell'evidenza

Esempi vietati senza prove:

- “diagnosi automatica”;
- “individua tutte le patologie”;
- “zero falsi negativi”;
- “più accurato del dentista”;
- “adatto a qualsiasi radiografia”;
- “previene errori”;
- “certificato AI Act” senza base;
- “clinicamente validato” senza studio adeguato.

### 33.4 Addestrare con feedback grezzo

Il click del dentista non è automaticamente ground truth.

### 33.5 Aggiornare silenziosamente i modelli

Ogni aggiornamento deve essere controllato, approvato, tracciato e comunicato quando necessario.

### 33.6 Inviare dati sanitari a LLM pubblici

Deve essere tecnicamente bloccato e disciplinato.

### 33.7 Far valutare urgenze a Giulia senza percorso clinico

Un agente di prenotazione non deve trasformarsi informalmente in triage.

### 33.8 Consentire azioni autonome ad agenti

Nessuna cancellazione, prescrizione, modifica clinica o accesso massivo senza policy, autorizzazione e conferma.

---

# PARTE XI — ROADMAP

## 34. Piano entro il 2 agosto 2026

Priorità P0:

- [ ] nominare AI Compliance Owner;
- [ ] creare Registro AI;
- [ ] approvare AI Use Policy;
- [ ] formare il personale;
- [ ] introdurre disclosure di Giulia;
- [ ] introdurre fallback umano;
- [ ] bloccare funzioni cliniche non autorizzate;
- [ ] completare gap analysis fornitori;
- [ ] avviare DPIA;
- [ ] attivare incident intake;
- [ ] approvare claim provvisori;
- [ ] salvare prova delle modifiche.

---

## 35. Entro 30 giorni

- [ ] Comitato AI/Medical Device;
- [ ] RACI;
- [ ] classificazione di tutti i moduli;
- [ ] data flow map;
- [ ] ROPA aggiornato;
- [ ] inventario sub-processors;
- [ ] script e informative;
- [ ] registro formazione;
- [ ] policy log;
- [ ] kill switch;
- [ ] segregazione ambienti;
- [ ] registro claim;
- [ ] repository inspection binder.

---

## 36. Entro 60 giorni

- [ ] intended purpose del modulo imaging;
- [ ] MDR qualification memo;
- [ ] MDR classification memo;
- [ ] scelta organismo notificato;
- [ ] QMS implementation plan;
- [ ] DPIA completa;
- [ ] supplier remediation;
- [ ] data management plan;
- [ ] labeling SOP;
- [ ] cybersecurity threat model;
- [ ] clinical evaluation strategy;
- [ ] piano validazione esterna;
- [ ] SOP change/retraining.

---

## 37. Entro 90 giorni

- [ ] risk management file;
- [ ] software lifecycle plan;
- [ ] architecture controllata;
- [ ] traceability matrix;
- [ ] model card;
- [ ] dataset cards;
- [ ] bias analysis;
- [ ] validation protocol;
- [ ] usability plan;
- [ ] human oversight plan;
- [ ] logging specification;
- [ ] PMS plan;
- [ ] PMCF plan;
- [ ] incident SOP;
- [ ] penetration test;
- [ ] internal audit iniziale.

---

## 38. Entro 180 giorni

- [ ] QMS operativo;
- [ ] design history completo;
- [ ] validazione interna;
- [ ] validazione esterna;
- [ ] clinical evaluation draft;
- [ ] security remediation;
- [ ] supplier audit;
- [ ] management review;
- [ ] CAPA;
- [ ] pre-submission con organismo notificato;
- [ ] roadmap CE;
- [ ] piano AI Act high-risk 2028;
- [ ] simulazione ispezione.

---

## 39. Roadmap fino al 2 agosto 2028

### 2026

- governance;
- trasparenza;
- MDR classification;
- QMS;
- privacy;
- data governance;
- clinical strategy;
- supplier controls.

### 2027

- validazione clinica;
- conformity assessment;
- documentazione AI Act articoli 8-15;
- PMS/PMCF;
- audit;
- remediation;
- registrazioni;
- marcatura CE, se completata.

### Primo semestre 2028

- gap assessment finale AI Act;
- adeguamento a standard armonizzati/common specifications disponibili;
- verifica Digital Omnibus e atti di esecuzione;
- aggiornamento fascicolo;
- testing;
- declaration of conformity;
- registrazioni;
- training clienti;
- contractual rollout;
- inspection drill.

### Entro 2 agosto 2028

- piena conformità high-risk per il modulo product-embedded;
- QMS e fascicolo integrati MDR/AI Act;
- post-market operativo;
- reporting incidenti operativo;
- evidenze disponibili.

---

# PARTE XII — ORGANIZZAZIONE

## 40. RACI minimo

| Attività | Accountable | Responsible | Consulted |
|---|---|---|---|
| Programma AI Act | CEO | AI Compliance Owner | Legal, DPO, CTO |
| MDR | CEO | Regulatory/Quality | Clinical, ML, Legal |
| QMS | Head of Quality | Quality team | Tutte le funzioni |
| Privacy | Titolare/management | DPO/Privacy | Security, Product |
| Cybersecurity | CTO/CISO | Security | DPO, Quality |
| Clinical safety | Medical Director | Clinical Safety Officer | Dentisti |
| Data governance | CTO/Product | Data Steward | DPO, Clinical |
| Model development | CTO | ML Lead | Clinical, Quality |
| Release | CTO/Quality | Engineering | Regulatory, Security |
| Incidents | CEO/Quality | Incident Manager | DPO, Security, Clinical |
| Claims | CEO/Product | Marketing | Regulatory, Legal |

Ruoli consigliati:

- Person Responsible for Regulatory Compliance, quando richiesto dal MDR;
- Clinical Safety Officer;
- AI Compliance Owner;
- Data Steward;
- Security Officer;
- DPO;
- Quality Manager;
- Regulatory Affairs Manager.

---

# PARTE XIII — CHECKLIST RAPIDA

## 41. Semaforo di readiness

Attribuire:

- **Verde**: completo, approvato, evidenza disponibile;
- **Giallo**: parziale o in approvazione;
- **Rosso**: assente o non conforme;
- **N/A**: motivato.

| Area | Stato | Evidenza | Owner | Scadenza |
|---|---|---|---|---|
| Registro AI |  |  |  |  |
| Classificazione Giulia |  |  |  |  |
| Disclosure Giulia |  |  |  |  |
| AI literacy |  |  |  |  |
| AI Use Policy |  |  |  |  |
| DPIA |  |  |  |  |
| DPA fornitori |  |  |  |  |
| Intended purpose imaging |  |  |  |  |
| MDR classification |  |  |  |  |
| QMS |  |  |  |  |
| Risk management |  |  |  |  |
| Data governance |  |  |  |  |
| Clinical evaluation |  |  |  |  |
| Cybersecurity |  |  |  |  |
| Human oversight |  |  |  |  |
| Logging |  |  |  |  |
| Change control |  |  |  |  |
| PMS/PMCF |  |  |  |  |
| Incident management |  |  |  |  |
| Inspection binder |  |  |  |  |

---

## 42. Decisione di rilascio

Una release clinica è autorizzabile solo se tutte le risposte sono sì:

- [ ] Lo scopo previsto è approvato?
- [ ] La classificazione MDR è approvata?
- [ ] Il percorso CE richiesto è completato?
- [ ] Il QMS copre la release?
- [ ] I rischi sono accettabili?
- [ ] La validazione soddisfa i criteri?
- [ ] L'evidenza clinica è sufficiente?
- [ ] La DPIA è approvata?
- [ ] I fornitori sono conformi?
- [ ] La cybersecurity è approvata?
- [ ] Le istruzioni sono aggiornate?
- [ ] La supervisione umana è testata?
- [ ] I log sono attivi?
- [ ] Il post-market è operativo?
- [ ] Esiste rollback?
- [ ] Sono formati gli utenti?
- [ ] Marketing e contratti usano claim approvati?

In assenza di una risposta positiva, la release deve essere bloccata o limitata a un ambiente non clinico autorizzato.

---

# PARTE XIV — TEMPLATE DA PRODURRE

## 43. Elenco documentale prioritario

1. `AI_System_Inventory.xlsx` o `.md`
2. `AI_Act_Classification_Memo.md`
3. `MDR_Qualification_Classification_Memo.md`
4. `DentalCare_AI_Use_Policy.md`
5. `AI_Literacy_Training_Plan.md`
6. `Giulia_Transparency_Script.md`
7. `Patient_AI_Information_Notice.md`
8. `DPIA_DentalCare_AI.docx`
9. `Intended_Purpose_DentalCare_Imaging.md`
10. `Quality_Manual.md`
11. `Software_Development_Lifecycle_Plan.md`
12. `Risk_Management_Plan.md`
13. `Risk_Management_Report.md`
14. `Data_Management_Plan.md`
15. `Dataset_Card_Template.md`
16. `Annotation_SOP.md`
17. `Model_Card_Dentex_FDI.md`
18. `Model_Card_Dentex_Disease.md`
19. `Verification_Validation_Plan.md`
20. `Clinical_Evaluation_Plan.md`
21. `Clinical_Evaluation_Report.md`
22. `Human_Oversight_Plan.md`
23. `Usability_Engineering_Plan.md`
24. `Cybersecurity_Plan.md`
25. `SBOM.json`
26. `Logging_and_Traceability_Specification.md`
27. `Model_Change_and_Retraining_SOP.md`
28. `Post_Market_Surveillance_Plan.md`
29. `PMCF_Plan.md`
30. `AI_MDR_Incident_Response_SOP.md`
31. `Supplier_AI_Due_Diligence_Questionnaire.md`
32. `Regulatory_Claims_Register.xlsx`
33. `Release_Readiness_Checklist.md`
34. `Inspection_Readiness_Index.md`

---

# PARTE XV — PRIORITÀ SPECIFICHE PER DENTALCARE

## 44. Le dieci decisioni da prendere adesso

1. **Separare formalmente la piattaforma amministrativa dal dispositivo radiologico.**
2. **Stabilire che Giulia non svolge triage o consulenza clinica.**
3. **Introdurre la disclosure AI prima del 2 agosto 2026.**
4. **Congelare l'uso clinico dei modelli ONNX fino al percorso MDR.**
5. **Scrivere l'intended purpose prima di continuare ad aggiungere patologie.**
6. **Sottoporre la classificazione a Regulatory Affairs e organismo notificato.**
7. **Bloccare il riaddestramento automatico con dati di produzione.**
8. **Completare DPIA e contratti di tutti i fornitori AI.**
9. **Creare un QMS, non soltanto documenti tecnici GitHub.**
10. **Preparare evidenze verificabili, non dichiarazioni generiche.**

---

## 45. Target architecture di compliance

Separare almeno i seguenti domini:

### Dominio A — Core gestionale

- pazienti;
- agenda;
- cartella;
- autorizzazioni;
- documenti;
- audit.

### Dominio B — Assistente amministrativo AI

- voce/chat;
- intent;
- prenotazione;
- disclosure;
- fallback;
- log;
- vendor boundary.

### Dominio C — Medical Device AI

- ingestion immagini;
- quality gate;
- preprocessing;
- inference;
- visualizzazione;
- review dentista;
- clinical output;
- audit;
- version lock.

### Dominio D — MLOps regolamentato

- dataset registry;
- annotation;
- training;
- validation;
- model registry;
- approval;
- signed artifacts;
- deployment;
- rollback;
- monitoring.

### Dominio E — Compliance evidence

- QMS;
- risk;
- clinical;
- privacy;
- security;
- supplier;
- post-market;
- inspection.

Non consentire accessi diretti fra domini senza API controllate, autorizzazioni e logging.

---

# PARTE XVI — FONTI UFFICIALI

Consultate al 16 luglio 2026.

1. **Regolamento (UE) 2024/1689 — Artificial Intelligence Act**  
   https://eur-lex.europa.eu/eli/reg/2024/1689/oj

2. **Commissione europea — AI Act e timeline**  
   https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai

3. **AI Act Service Desk — timeline**  
   https://ai-act-service-desk.ec.europa.eu/en/ai-act/timeline/timeline-implementation-eu-ai-act

4. **Consiglio UE — approvazione finale Digital Omnibus, 29 giugno 2026**  
   https://www.consilium.europa.eu/en/press/press-releases/2026/06/29/artificial-intelligence-council-gives-final-green-light-to-simplify-and-streamline-rules/

5. **AI Act Service Desk — Articolo 4, AI literacy**  
   https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-4

6. **AI Act Service Desk — Articolo 50, trasparenza**  
   https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50

7. **AI Act Service Desk — Articolo 99, sanzioni**  
   https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-99

8. **MDCG 2025-6 — Interplay MDR/IVDR e AI Act**  
   https://health.ec.europa.eu/document/download/b78a17d7-e3cd-4943-851d-e02a2f22bbb4_en

9. **MDCG 2019-11 rev.1 — Qualification and Classification of Software**  
   https://health.ec.europa.eu/document/download/b45335c5-1679-4c71-a91c-fc7a4d37f12b_en

10. **MDCG 2020-1 — Clinical Evaluation of Medical Device Software**  
    https://health.ec.europa.eu/system/files/2020-09/md_mdcg_2020_1_guidance_clinic_eva_md_software_en_0.pdf

11. **Commissione europea — MDCG guidance repository**  
    https://health.ec.europa.eu/medical-devices-sector/new-regulations/guidance-mdcg-endorsed-documents-and-other-guidance_en

12. **Regolamento (UE) 2017/745 — MDR**  
    https://eur-lex.europa.eu/eli/reg/2017/745/oj

13. **Regolamento (UE) 2016/679 — GDPR**  
    https://eur-lex.europa.eu/eli/reg/2016/679/oj

14. **Legge italiana 23 settembre 2025, n. 132**  
    https://www.normattiva.it/atto/caricaDettaglioAtto?atto.codiceRedazionale=25G00143

15. **Articolo 7 della legge n. 132/2025 — AI in sanità**  
    https://www.gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.codiceRedazionale=25G00143&art.dataPubblicazioneGazzetta=2025-09-25&art.idArticolo=7

16. **Articolo 20 della legge n. 132/2025 — autorità nazionali**  
    https://www.gazzettaufficiale.it/atto/serie_generale/caricaArticolo?art.codiceRedazionale=25G00143&art.dataPubblicazioneGazzetta=2025-09-25&art.idArticolo=20

---

# 46. Nota finale

La strategia più efficace per evitare problemi non consiste nel “prepararsi quando arriva un controllo”, ma nel rendere ogni decisione:

- motivata;
- approvata;
- tracciabile;
- riproducibile;
- verificabile;
- coerente con il prodotto reale;
- supportata da dati;
- aggiornata nel tempo.

Per DentalCare la priorità non è produrre subito una grande quantità di documenti, ma costruire una catena di evidenze coerente:

> **scopo previsto → classificazione → rischi → requisiti → sviluppo → verifica → validazione clinica → supervisione umana → rilascio → monitoraggio → incidenti → miglioramento.**

Qualsiasi lacuna in questa catena è una potenziale non conformità.
