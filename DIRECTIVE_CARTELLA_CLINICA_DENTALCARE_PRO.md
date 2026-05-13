# Direttiva tecnica e funzionale per modifica Scheda Paziente - Cartella Clinica

**Progetto:** DentalCare Pro  
**Area applicativa:** Scheda paziente / Cartella clinica odontoiatrica  
**Frontend:** Angular  
**Obiettivo:** trasformare la tab `Cartella Clinica`, oggi vuota o in stato provvisorio, in una dashboard clinica realmente utilizzabile da dentista, assistente e personale autorizzato.

---

## 1. Obiettivo generale

La maschera della scheda paziente deve essere migliorata per rappresentare correttamente il funzionamento di un gestionale odontoiatrico.

La sezione **Cartella Clinica** non deve mostrare un messaggio generico come:

```text
Sezione in sviluppo
Seleziona "Panoramica" per vedere i dati disponibili
```

Deve invece diventare il centro operativo clinico del paziente, contenente almeno:

- riepilogo clinico;
- alert clinici;
- riepilogo anamnestico;
- odontogramma;
- diario clinico;
- diagnosi e problemi attivi;
- piano di cura;
- esami, immagini e documenti clinici;
- prescrizioni;
- azioni rapide per il personale sanitario.

---

## 2. Principio funzionale di base

Nel gestionale odontoiatrico devono essere mantenute distinte, ma collegate, le seguenti aree:

### 2.1 Anamnesi

L’**Anamnesi** è la sezione dedicata alla storia medica generale del paziente.

Deve contenere informazioni come:

- allergie;
- farmaci assunti;
- patologie pregresse o in corso;
- terapie;
- condizioni cardiovascolari;
- diabete;
- gravidanza;
- rischio emorragico;
- rischio endocardite;
- abitudini rilevanti, ad esempio fumo;
- eventuali dichiarazioni del paziente.

L’anamnesi deve restare una tab autonoma perché richiede una compilazione strutturata e completa.

### 2.2 Cartella Clinica

La **Cartella Clinica** è l’area operativa del dentista.

Deve contenere:

- valutazione odontoiatrica;
- odontogramma;
- diagnosi;
- diario clinico;
- trattamenti eseguiti;
- piano di cura;
- prescrizioni;
- immagini e referti;
- documenti clinici;
- sintesi dei rischi anamnestici rilevanti.

### 2.3 Relazione tra Anamnesi e Cartella Clinica

L’anamnesi appartiene concettualmente alla cartella clinica, ma a livello UI deve restare una sezione separata.

Dentro la **Cartella Clinica** deve però essere sempre visibile un **riepilogo anamnestico critico**, utile al dentista prima di effettuare trattamenti.

---

## 3. Struttura consigliata delle tab paziente

La navigazione attuale può essere mantenuta, ma si consiglia una delle seguenti strutture.

### Opzione A - Completa

```text
Panoramica | Cartella Clinica | Odontogramma | Anamnesi | Piani di cura | Preventivi | Documenti
```

### Opzione B - Compatta

```text
Panoramica | Cartella Clinica | Anamnesi | Preventivi | Documenti
```

Se viene mantenuta l’opzione compatta, dentro **Cartella Clinica** devono comunque comparire i blocchi relativi a:

- odontogramma;
- diario clinico;
- diagnosi;
- trattamenti;
- piano di cura;
- prescrizioni;
- esami e immagini.

---

## 4. Differenza tra Panoramica e Cartella Clinica

### 4.1 Panoramica

La tab **Panoramica** deve essere una sintesi generale del paziente, utile anche alla segreteria.

Deve mostrare preferibilmente:

- dati anagrafici;
- contatti;
- prossimo appuntamento;
- ultimo appuntamento;
- preventivi aperti;
- situazione amministrativa essenziale;
- richiami;
- documenti mancanti;
- note operative;
- alert generali non sensibili.

### 4.2 Cartella Clinica

La tab **Cartella Clinica** deve essere destinata principalmente al personale sanitario.

Deve mostrare preferibilmente:

- riepilogo clinico;
- alert clinici;
- riepilogo anamnestico;
- odontogramma;
- diario clinico;
- diagnosi;
- trattamenti;
- piano di cura;
- esami;
- prescrizioni;
- documenti clinici.

---

## 5. Miglioramento della testata paziente

Nella testata paziente evitare badge troppo diretti, stigmatizzanti o poco professionali.

Esempio da evitare:

```text
Obeso
```

Sostituire con formule più neutre e clinicamente utili, ad esempio:

```text
BMI elevato
```

oppure:

```text
Alert clinico
```

oppure:

```text
Anamnesi da verificare
```

Gli alert devono essere mostrati in modo professionale e non giudicante.

### 5.1 Esempi di alert da mostrare

- Allergie registrate
- Terapia anticoagulante
- Diabete
- Cardiopatia
- Pacemaker
- Gravidanza
- Rischio endocardite
- Anamnesi incompleta
- Farmaci non registrati
- BMI elevato

### 5.2 Regola sui dati mancanti

Non confondere mai l’assenza di dati con l’assenza di patologie.

Esempio corretto:

```text
Allergie: non registrate
```

Esempio da usare solo se il paziente ha dichiarato esplicitamente di non avere allergie:

```text
Allergie: nessuna allergia dichiarata
```

---

## 6. Nuova struttura della tab Cartella Clinica

La sezione **Cartella Clinica** deve essere implementata come dashboard clinica composta da card e sezioni ordinate.

Layout consigliato:

```text
Cartella Clinica

[Alert clinici]
Anamnesi da completare | Allergie non registrate | Farmaci non registrati

[Riepilogo clinico]
Ultima visita | Ultima diagnosi | Piano di cura attivo | Ultimo aggiornamento

[Riepilogo anamnestico]
Allergie | Farmaci | Patologie rilevanti | Ultimo aggiornamento
[Apri anamnesi]

[Odontogramma]
Mini anteprima o placeholder
[Apri odontogramma] [Nuovo rilievo]

[Diario clinico]
Lista cronologica note cliniche
[+ Nuova visita] [+ Nuova nota clinica]

[Diagnosi e problemi attivi]
Elenco problemi clinici attivi

[Piano di cura]
Stato piano di cura, prestazioni previste, collegamenti a preventivo e appuntamenti

[Esami e documenti clinici]
Radiografie | Foto | Referti | Consensi | Prescrizioni
```

---

## 7. Sezioni funzionali da implementare

### 7.1 Riepilogo clinico

Creare una card iniziale chiamata **Riepilogo clinico**.

Contenuto minimo:

- ultima visita;
- ultima diagnosi;
- piano di cura attivo;
- stato anamnesi;
- allergie;
- farmaci;
- patologie rilevanti;
- ultimo aggiornamento clinico.

Esempio:

```text
Riepilogo clinico

Ultima visita: non presente
Ultima diagnosi: non presente
Piano di cura attivo: no
Anamnesi: da completare
Allergie: non registrate
Farmaci: non registrati
Patologie rilevanti: non registrate
```

Se i dati non sono presenti, usare placeholder professionali:

```text
Non registrato
Non indicato
Da completare
Nessun dato disponibile
```

---

### 7.2 Alert clinici

Creare una sezione o card chiamata **Alert clinici**.

Gli alert devono essere mostrati come badge o chip.

Esempi:

```text
Anamnesi da completare
Allergie non registrate
Farmaci non registrati
BMI elevato
```

Regole:

- non mostrare alert allarmistici se non sono presenti dati certi;
- non mostrare patologie non verificate;
- usare uno stile neutro;
- usare colori coerenti:
  - info: grigio/azzurro;
  - warning: giallo/arancio;
  - critical: rosso solo per rischi clinici certi e rilevanti.

---

### 7.3 Riepilogo anamnestico

Anche se esiste una tab autonoma **Anamnesi**, nella Cartella Clinica deve esserci un box sintetico chiamato **Riepilogo anamnestico**.

Contenuto minimo:

- allergie;
- farmaci assunti;
- patologie rilevanti;
- terapie in corso;
- rischi clinici;
- data ultimo aggiornamento anamnesi;
- pulsante `Apri anamnesi`.

Esempio:

```text
Riepilogo anamnestico

Allergie: non registrate
Farmaci: non registrati
Patologie rilevanti: non registrate
Terapie in corso: non registrate
Ultimo aggiornamento: da completare

[Apri anamnesi]
```

---

### 7.4 Odontogramma

Creare una sezione centrale dedicata all’**Odontogramma**.

Funzioni minime:

- pulsante `Apri odontogramma`;
- pulsante `Nuovo rilievo`;
- stato sintetico dei denti;
- mini anteprima grafica o placeholder;
- collegamento alle diagnosi e ai trattamenti.

Esempio di stato vuoto:

```text
Odontogramma

Nessun odontogramma compilato per questo paziente.

[Apri odontogramma]
[Nuovo rilievo]
```

L’odontogramma deve essere considerato un elemento centrale della cartella dentistica.

---

### 7.5 Diario clinico

Creare una sezione chiamata **Diario clinico**.

Deve contenere l’elenco cronologico delle note cliniche, visite, diagnosi e trattamenti.

Campi minimi per ogni elemento del diario:

- data;
- operatore;
- tipo evento;
- descrizione;
- diagnosi, se presente;
- trattamento eseguito, se presente;
- eventuali note riservate;
- eventuale riferimento a documento, immagine o prescrizione.

Azioni consigliate:

```text
+ Nuova visita
+ Nuova nota clinica
+ Nuova diagnosi
+ Trattamento eseguito
```

Esempio stato vuoto:

```text
Nessuna nota clinica presente.
Registra la prima visita o aggiungi una nota clinica.
```

---

### 7.6 Diagnosi e problemi attivi

Creare una card chiamata **Diagnosi e problemi attivi**.

Esempi di problemi odontoiatrici:

- carie;
- parodontite;
- bruxismo;
- dolore;
- mobilità dentale;
- infezione;
- sensibilità;
- problemi ATM;
- lesioni mucose;
- urgenza odontoiatrica.

Stati possibili:

```text
Attivo
In osservazione
Risolto
Sospeso
```

Esempio stato vuoto:

```text
Nessuna diagnosi attiva registrata.
```

---

### 7.7 Piano di cura

Creare una sezione chiamata **Piano di cura**.

Contenuto minimo:

- piano attivo;
- prestazioni previste;
- priorità;
- stato delle cure;
- collegamento a preventivo;
- collegamento ad appuntamenti;
- avanzamento;
- note cliniche collegate.

Stati consigliati:

```text
Da iniziare
In corso
Completato
Sospeso
Annullato
```

Azioni:

```text
+ Crea piano di cura
Collega a preventivo
Collega ad appuntamento
```

Esempio stato vuoto:

```text
Nessun piano di cura attivo.
```

---

### 7.8 Esami, immagini e documenti clinici

Creare una sezione chiamata **Esami e documenti clinici**.

Categorie consigliate:

- radiografie;
- ortopanoramica;
- TAC / CBCT;
- fotografie intraorali;
- referti;
- consensi clinici;
- prescrizioni;
- documenti caricati.

Azioni:

```text
+ Carica documento
+ Carica immagine
+ Aggiungi referto
```

---

### 7.9 Prescrizioni

Creare una sezione o card chiamata **Prescrizioni**.

Campi minimi:

- farmaco;
- dosaggio;
- durata;
- istruzioni;
- data prescrizione;
- medico prescrittore;
- note.

Stato vuoto:

```text
Nessuna prescrizione registrata.
```

---

## 8. Gestione ruoli e permessi

La cartella clinica contiene dati sanitari. La UI deve considerare il ruolo dell’utente loggato.

Nel caso mostrato nella schermata, l’utente ha ruolo **Segreteria**. Questo ruolo non dovrebbe necessariamente vedere tutti i dettagli clinici.

### 8.1 Ruolo Segreteria

Può vedere:

- dati anagrafici;
- contatti;
- appuntamenti;
- preventivi;
- fatture;
- documenti amministrativi;
- stato generico dell’anamnesi;
- alert minimi non dettagliati;
- presenza o assenza di documenti clinici, senza dettagli sensibili se non autorizzata.

Non dovrebbe vedere, salvo autorizzazione specifica:

- diagnosi dettagliate;
- diario clinico completo;
- referti sanitari dettagliati;
- patologie sensibili;
- prescrizioni dettagliate;
- note cliniche riservate.

Esempio UI per Segreteria:

```text
Cartella clinica disponibile solo per personale sanitario autorizzato.
Puoi visualizzare appuntamenti, preventivi e documenti amministrativi.
```

Oppure mostrare una versione ridotta:

```text
Riepilogo operativo

Anamnesi: da completare
Documenti clinici: presenti
Piano di cura: presente
Prossimo appuntamento: 12/05/2026
```

### 8.2 Ruolo Dentista

Può vedere e modificare:

- cartella clinica completa;
- odontogramma;
- anamnesi completa;
- diagnosi;
- diario clinico;
- trattamenti;
- prescrizioni;
- piano di cura;
- esami e referti;
- documenti clinici.

### 8.3 Ruolo Assistente

Può vedere:

- cartella clinica parziale;
- odontogramma;
- esami e immagini;
- piano operativo;
- note non riservate.

Può eventualmente:

- caricare immagini;
- caricare documenti;
- preparare una scheda;
- inserire note operative.

Non dovrebbe poter validare diagnosi o modificare terapie senza permesso.

---

## 9. Requisiti UI/UX

### 9.1 Stile grafico

Mantenere lo stile attuale dell’applicazione:

- layout pulito;
- sidebar fissa;
- header paziente leggibile;
- card bianche;
- bordi arrotondati;
- colori coerenti con il tema DentalCare Pro;
- uso del verde/teal per azioni primarie;
- uso di giallo/arancione per alert da verificare;
- uso di rosso solo per rischi clinici importanti e certi.

### 9.2 Empty state

Evitare messaggi generici come:

```text
Sezione in sviluppo
```

Usare invece empty state utili:

```text
Nessuna nota clinica presente.
Registra la prima visita del paziente.
```

oppure:

```text
Nessun odontogramma compilato.
Apri l’odontogramma per iniziare la valutazione dentale.
```

### 9.3 Pulsanti principali

Nella Cartella Clinica inserire pulsanti rapidi coerenti con il ruolo utente:

```text
+ Nuova visita
+ Nota clinica
+ Diagnosi
+ Trattamento
+ Prescrizione
Apri odontogramma
Apri anamnesi
Crea piano di cura
Carica documento
```

Per la segreteria mostrare solo le azioni consentite.

---

## 10. Componentizzazione Angular consigliata

Creare o riutilizzare componenti separati. Evitare componenti monolitici troppo grandi.

Componenti consigliati:

```text
patient-header.component
patient-tabs.component
clinical-record.component
clinical-summary-card.component
clinical-alerts.component
anamnesis-summary-card.component
odontogram-card.component
clinical-diary.component
diagnosis-active-list.component
treatment-plan-card.component
clinical-documents-card.component
prescriptions-card.component
role-restricted-panel.component
```

### 10.1 Responsabilità dei componenti

| Componente | Responsabilità |
|---|---|
| `clinical-record.component` | Container principale della tab Cartella Clinica |
| `clinical-summary-card.component` | Mostra riepilogo clinico |
| `clinical-alerts.component` | Mostra badge/chip di alert clinici |
| `anamnesis-summary-card.component` | Mostra sintesi anamnestica e link alla tab Anamnesi |
| `odontogram-card.component` | Mostra stato odontogramma e azioni rapide |
| `clinical-diary.component` | Mostra diario clinico e azioni di inserimento |
| `diagnosis-active-list.component` | Mostra problemi e diagnosi attive |
| `treatment-plan-card.component` | Mostra piano di cura attivo |
| `clinical-documents-card.component` | Mostra esami, immagini e documenti clinici |
| `prescriptions-card.component` | Mostra prescrizioni |
| `role-restricted-panel.component` | Gestisce messaggi e riduzioni UI per ruoli non autorizzati |

---

## 11. Modello dati minimo lato frontend

Prevedere un modello dati compatibile con questo schema logico.

```ts
export interface PatientClinicalRecord {
  patientId: string;
  clinicalSummary: ClinicalSummary;
  clinicalAlerts: ClinicalAlert[];
  anamnesisSummary: AnamnesisSummary;
  odontogramSummary: OdontogramSummary;
  diaryEntries: ClinicalDiaryEntry[];
  activeDiagnoses: Diagnosis[];
  treatmentPlans: TreatmentPlan[];
  prescriptions: Prescription[];
  clinicalDocuments: ClinicalDocument[];
}

export interface ClinicalSummary {
  lastVisitDate?: string;
  lastDiagnosis?: string;
  activeTreatmentPlan?: boolean;
  anamnesisStatus: 'complete' | 'incomplete' | 'missing' | 'expired';
  lastClinicalUpdate?: string;
}

export interface ClinicalAlert {
  id: string;
  type: 'info' | 'warning' | 'critical';
  label: string;
  category: 'anamnesis' | 'allergy' | 'therapy' | 'pathology' | 'administrative';
  visibleToRoles: UserRole[];
}

export type UserRole = 'DENTIST' | 'ASSISTANT' | 'SECRETARY' | 'ADMIN';

export interface AnamnesisSummary {
  allergiesStatus: 'not_recorded' | 'none_declared' | 'present';
  allergies?: string[];
  medicationsStatus: 'not_recorded' | 'none_declared' | 'present';
  medications?: string[];
  relevantPathologiesStatus: 'not_recorded' | 'none_declared' | 'present';
  relevantPathologies?: string[];
  therapiesStatus?: 'not_recorded' | 'none_declared' | 'present';
  therapies?: string[];
  riskFactors?: string[];
  lastUpdatedAt?: string;
}

export interface OdontogramSummary {
  exists: boolean;
  lastUpdatedAt?: string;
  teethWithFindings?: number;
  missingTeeth?: number;
  plannedTreatments?: number;
}

export interface ClinicalDiaryEntry {
  id: string;
  date: string;
  operatorName: string;
  type: 'visit' | 'note' | 'diagnosis' | 'treatment' | 'follow_up';
  description: string;
  diagnosis?: string;
  treatment?: string;
  confidential?: boolean;
}

export interface Diagnosis {
  id: string;
  label: string;
  toothNumber?: string;
  status: 'active' | 'under_observation' | 'resolved' | 'suspended';
  severity?: 'low' | 'medium' | 'high';
  createdAt: string;
}

export interface TreatmentPlan {
  id: string;
  title: string;
  status: 'not_started' | 'in_progress' | 'completed' | 'suspended' | 'cancelled';
  priority?: 'low' | 'medium' | 'high';
  linkedQuoteId?: string;
  linkedAppointmentIds?: string[];
  progressPercentage?: number;
}

export interface Prescription {
  id: string;
  drugName: string;
  dosage: string;
  duration: string;
  instructions?: string;
  prescribedAt: string;
  prescriberName: string;
  notes?: string;
}

export interface ClinicalDocument {
  id: string;
  title: string;
  type: 'xray' | 'panoramic_xray' | 'cbct' | 'intraoral_photo' | 'report' | 'consent' | 'prescription' | 'other';
  uploadedAt: string;
  uploadedBy: string;
  restricted?: boolean;
}
```

---

## 12. Servizio Angular consigliato

Prevedere un servizio dedicato, ad esempio:

```text
clinical-record.service.ts
```

Responsabilità:

- recuperare la cartella clinica del paziente;
- recuperare solo i dati visibili in base al ruolo;
- esporre metodi per aggiungere note, diagnosi, prescrizioni e documenti;
- gestire fallback e stato vuoto.

Esempio struttura:

```ts
@Injectable({ providedIn: 'root' })
export class ClinicalRecordService {
  constructor(private http: HttpClient) {}

  getClinicalRecord(patientId: string): Observable<PatientClinicalRecord> {
    return this.http.get<PatientClinicalRecord>(`/api/patients/${patientId}/clinical-record`);
  }

  addDiaryEntry(patientId: string, payload: Partial<ClinicalDiaryEntry>): Observable<ClinicalDiaryEntry> {
    return this.http.post<ClinicalDiaryEntry>(`/api/patients/${patientId}/clinical-record/diary`, payload);
  }

  addDiagnosis(patientId: string, payload: Partial<Diagnosis>): Observable<Diagnosis> {
    return this.http.post<Diagnosis>(`/api/patients/${patientId}/clinical-record/diagnoses`, payload);
  }

  addPrescription(patientId: string, payload: Partial<Prescription>): Observable<Prescription> {
    return this.http.post<Prescription>(`/api/patients/${patientId}/clinical-record/prescriptions`, payload);
  }
}
```

Se le API backend non sono ancora disponibili, usare mock coerenti ma isolati in un file dedicato, ad esempio:

```text
clinical-record.mock.ts
```

Evitare di inserire dati mock direttamente nel template.

---

## 13. Rotte/API backend suggerite

Se il backend deve essere adeguato, prevedere endpoint REST simili ai seguenti.

```http
GET    /api/patients/{patientId}/clinical-record
GET    /api/patients/{patientId}/clinical-record/summary
GET    /api/patients/{patientId}/clinical-record/anamnesis-summary
GET    /api/patients/{patientId}/clinical-record/odontogram
GET    /api/patients/{patientId}/clinical-record/diary
POST   /api/patients/{patientId}/clinical-record/diary
GET    /api/patients/{patientId}/clinical-record/diagnoses
POST   /api/patients/{patientId}/clinical-record/diagnoses
GET    /api/patients/{patientId}/clinical-record/treatment-plans
POST   /api/patients/{patientId}/clinical-record/treatment-plans
GET    /api/patients/{patientId}/clinical-record/prescriptions
POST   /api/patients/{patientId}/clinical-record/prescriptions
GET    /api/patients/{patientId}/clinical-record/documents
POST   /api/patients/{patientId}/clinical-record/documents
```

Gli endpoint devono applicare controlli di autorizzazione lato backend, non solo lato frontend.

---

## 14. Sicurezza, privacy e audit

La Cartella Clinica contiene dati sanitari. Implementare almeno i seguenti principi:

- visibilità per ruolo;
- permessi di lettura;
- permessi di modifica;
- audit delle modifiche;
- separazione tra dati amministrativi e dati clinici;
- non mostrare dettagli sanitari alla segreteria se non necessari;
- non basarsi solo sul frontend per proteggere i dati;
- predisporre log di creazione/modifica/cancellazione di dati clinici;
- distinguere note cliniche ordinarie da note riservate.

### 14.1 Regole minime di autorizzazione

| Funzione | Dentista | Assistente | Segreteria | Admin |
|---|---:|---:|---:|---:|
| Vedere riepilogo operativo | Sì | Sì | Sì | Sì |
| Vedere anamnesi completa | Sì | Parziale/secondo permesso | No/limitato | Secondo policy |
| Vedere diario clinico | Sì | Parziale | No | Secondo policy |
| Inserire diagnosi | Sì | No | No | No/secondo policy |
| Inserire trattamento | Sì | Parziale/bozza | No | No/secondo policy |
| Caricare documenti | Sì | Sì | Solo amministrativi | Sì |
| Vedere prescrizioni | Sì | Parziale | No | Secondo policy |
| Gestire preventivi | Sì | Sì/limitato | Sì | Sì |
| Gestire appuntamenti | Sì | Sì | Sì | Sì |

---

## 15. Comportamento per ruolo nella UI

### 15.1 Se utente = Segreteria

Mostrare una versione limitata della tab Cartella Clinica oppure un messaggio di accesso limitato.

Esempio:

```text
Accesso clinico limitato

Il tuo ruolo consente la gestione amministrativa e operativa del paziente.
I dettagli clinici sono disponibili solo al personale sanitario autorizzato.

Puoi visualizzare:
- stato generale della scheda;
- anamnesi da completare o completata;
- presenza di documenti clinici;
- appuntamenti collegati;
- preventivi collegati.
```

### 15.2 Se utente = Dentista

Mostrare l’intera dashboard clinica con tutte le azioni abilitate.

### 15.3 Se utente = Assistente

Mostrare la dashboard clinica parziale, con azioni limitate.

---

## 16. Requisiti di implementazione per Claude Code

Claude Code deve:

1. Analizzare la struttura Angular esistente.
2. Individuare il componente della scheda paziente.
3. Individuare la gestione delle tab paziente.
4. Sostituire lo stato provvisorio della tab `Cartella Clinica` con una dashboard clinica.
5. Creare componenti separati se coerente con l’architettura esistente.
6. Non rompere le tab già presenti.
7. Non modificare inutilmente rotte, layout generale o sidebar.
8. Mantenere lo stile grafico esistente.
9. Usare dati reali se già disponibili dai servizi esistenti.
10. Usare mock isolati solo se il backend non espone ancora le informazioni richieste.
11. Gestire correttamente ruoli e permessi almeno a livello UI.
12. Predisporre la struttura per l’integrazione backend.
13. Sostituire badge clinici stigmatizzanti con badge neutri.
14. Inserire empty state professionali.
15. Garantire build Angular senza errori TypeScript.

---

## 17. File Angular da cercare/modificare

Claude Code deve cercare nel progetto file riconducibili a:

```text
patient
patients
scheda-paziente
patient-detail
patient-profile
clinical-record
anamnesis
medical-record
cartella-clinica
```

Possibili file da modificare o creare:

```text
src/app/features/patients/**
src/app/pages/patients/**
src/app/components/patients/**
src/app/models/**
src/app/services/**
```

Non assumere nomi esatti: verificare prima la struttura reale del progetto.

---

## 18. Proposta di struttura file

Se compatibile con il progetto, creare una struttura simile:

```text
src/app/features/patients/components/clinical-record/
  clinical-record.component.ts
  clinical-record.component.html
  clinical-record.component.scss

src/app/features/patients/components/clinical-summary-card/
  clinical-summary-card.component.ts
  clinical-summary-card.component.html
  clinical-summary-card.component.scss

src/app/features/patients/components/clinical-alerts/
  clinical-alerts.component.ts
  clinical-alerts.component.html
  clinical-alerts.component.scss

src/app/features/patients/components/anamnesis-summary-card/
  anamnesis-summary-card.component.ts
  anamnesis-summary-card.component.html
  anamnesis-summary-card.component.scss

src/app/features/patients/components/odontogram-card/
  odontogram-card.component.ts
  odontogram-card.component.html
  odontogram-card.component.scss

src/app/features/patients/components/clinical-diary/
  clinical-diary.component.ts
  clinical-diary.component.html
  clinical-diary.component.scss

src/app/features/patients/components/diagnosis-active-list/
  diagnosis-active-list.component.ts
  diagnosis-active-list.component.html
  diagnosis-active-list.component.scss

src/app/features/patients/components/treatment-plan-card/
  treatment-plan-card.component.ts
  treatment-plan-card.component.html
  treatment-plan-card.component.scss

src/app/features/patients/components/clinical-documents-card/
  clinical-documents-card.component.ts
  clinical-documents-card.component.html
  clinical-documents-card.component.scss

src/app/features/patients/components/prescriptions-card/
  prescriptions-card.component.ts
  prescriptions-card.component.html
  prescriptions-card.component.scss

src/app/features/patients/models/clinical-record.model.ts
src/app/features/patients/services/clinical-record.service.ts
src/app/features/patients/mocks/clinical-record.mock.ts
```

Se il progetto usa un’altra struttura, adattarsi allo standard esistente.

---

## 19. Layout visuale consigliato

### 19.1 Desktop

Usare una griglia responsive:

```text
Riga 1:
[Alert clinici - larghezza piena]

Riga 2:
[Riepilogo clinico - 2/3] [Riepilogo anamnestico - 1/3]

Riga 3:
[Odontogramma - 1/2] [Piano di cura - 1/2]

Riga 4:
[Diario clinico - 2/3] [Diagnosi attive - 1/3]

Riga 5:
[Esami e documenti - 1/2] [Prescrizioni - 1/2]
```

### 19.2 Mobile/tablet

Impilare le card verticalmente.

---

## 20. Test manuali da effettuare

Dopo la modifica verificare:

1. apertura della scheda paziente;
2. caricamento della tab Panoramica;
3. caricamento della tab Cartella Clinica;
4. assenza del messaggio “Sezione in sviluppo”;
5. visualizzazione di empty state utili;
6. funzionamento pulsanti principali;
7. comportamento con utente Segreteria;
8. comportamento con utente Dentista;
9. comportamento con dati clinici mancanti;
10. comportamento con dati clinici presenti;
11. responsive layout;
12. assenza di errori in console browser;
13. build Angular completata senza errori.

Comandi indicativi:

```bash
npm install
npm run build
npm run test
npm start
```

Adattare i comandi agli script presenti nel `package.json`.

---

## 21. Criteri di accettazione

La modifica è accettabile se:

- la tab **Cartella Clinica** non mostra più “Sezione in sviluppo”;
- la Cartella Clinica mostra una dashboard clinica strutturata;
- è presente un riepilogo anamnestico sintetico;
- l’anamnesi resta anche come tab separata;
- sono presenti sezioni per odontogramma, diario clinico, diagnosi, piano di cura, esami/documenti e prescrizioni;
- gli stati vuoti sono informativi e professionali;
- gli alert clinici sono neutri e non stigmatizzanti;
- la visualizzazione tiene conto del ruolo utente;
- la segreteria non vede dettagli clinici sensibili non necessari;
- il dentista vede la cartella clinica completa;
- la UI mantiene lo stile grafico esistente dell’applicazione;
- le nuove sezioni sono componentizzate e facilmente estendibili;
- il codice TypeScript è tipizzato;
- la build Angular non produce errori;
- non vengono introdotte regressioni nella navigazione paziente.

---

## 22. Prompt operativo da dare a Claude Code

Usare il seguente prompt dentro Claude Code.

```text
Analizza il progetto Angular DentalCare Pro e applica le modifiche descritte in questo file.

Obiettivo: migliorare la scheda paziente, in particolare la tab Cartella Clinica, sostituendo lo stato provvisorio con una dashboard clinica odontoiatrica completa.

Prima di modificare il codice:
1. individua il componente della scheda paziente;
2. individua dove sono gestite le tab Panoramica, Cartella Clinica, Anamnesi, Preventivi e Documenti;
3. individua eventuali modelli e servizi già esistenti per pazienti, anamnesi, appuntamenti, preventivi e documenti;
4. rispetta la struttura e lo stile già presenti nel progetto.

Implementa nella tab Cartella Clinica:
- Alert clinici;
- Riepilogo clinico;
- Riepilogo anamnestico;
- Odontogramma;
- Diario clinico;
- Diagnosi e problemi attivi;
- Piano di cura;
- Esami e documenti clinici;
- Prescrizioni;
- Empty state professionali;
- Permessi differenziati per ruolo Segreteria, Dentista e Assistente.

Regole importanti:
- non eliminare la tab Anamnesi;
- dentro Cartella Clinica mostra solo un riepilogo anamnestico;
- non mostrare dati clinici dettagliati alla Segreteria se non autorizzata;
- sostituisci badge come “Obeso” con formule più neutre come “BMI elevato” o “Anamnesi da verificare”;
- non confondere dati non registrati con assenza di patologie;
- usa mock isolati solo se le API backend non sono disponibili;
- non rompere la navigazione esistente;
- mantieni lo stile DentalCare Pro;
- assicurati che il progetto compili senza errori.

Alla fine fornisci:
1. elenco file modificati/creati;
2. riepilogo delle modifiche;
3. eventuali API backend mancanti;
4. eventuali punti rimasti mockati;
5. comandi usati per verificare build/test.
```

---

## 23. Nota finale

Non eliminare la tab **Anamnesi**.

L’anamnesi deve rimanere autonoma perché richiede una compilazione strutturata e completa.

Dentro la **Cartella Clinica** va mostrato solo un riepilogo critico, utile al dentista prima di effettuare trattamenti.

La **Cartella Clinica** deve diventare il punto centrale della gestione clinica odontoiatrica del paziente, mentre la **Panoramica** deve restare una sintesi generale e operativa, utile anche alla segreteria.
