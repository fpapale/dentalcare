# DentalCare Pro — Manuale Utente

> Versione 1.0 · Maggio 2026

---

## Indice

1. [Introduzione](#1-introduzione)
2. [Accesso e navigazione](#2-accesso-e-navigazione)
3. [Dashboard](#3-dashboard)
4. [Pazienti](#4-pazienti)
   - [Lista pazienti](#41-lista-pazienti)
   - [Nuovo paziente](#42-nuovo-paziente)
   - [Scheda paziente](#43-scheda-paziente)
   - [Anamnesi](#44-anamnesi)
   - [Odontogramma](#45-odontogramma)
   - [Piani di cura](#46-piani-di-cura)
5. [Agenda](#5-agenda)
   - [Viste calendario](#51-viste-calendario)
   - [Nuovo appuntamento](#52-nuovo-appuntamento)
6. [Preventivi](#6-preventivi)
7. [Fatturazione](#7-fatturazione)
8. [Richiami](#8-richiami)
9. [Magazzino](#9-magazzino)
10. [SegretarIA](#10-segretaria)
11. [Impostazioni](#11-impostazioni)
12. [Glossario stati](#12-glossario-stati)

---

## 1. Introduzione

**DentalCare Pro** è una piattaforma cloud completa per la gestione di studi dentistici italiani. Permette di gestire l'intera operatività dello studio:

- Anagrafica pazienti e cartella clinica digitale
- Agenda appuntamenti multi-poltrona
- Preventivi e piani di cura
- Fatturazione elettronica
- Richiami e recall automatici
- Magazzino e gestione fornitori
- Segretaria AI (AI-DEN) per la gestione intelligente delle comunicazioni

Il sistema è accessibile da qualsiasi browser moderno su desktop, tablet e smartphone.

---

## 2. Accesso e navigazione

### Primo accesso

Aprire il browser e navigare all'indirizzo fornito dal responsabile IT dello studio.
Inserire le credenziali ricevute via email al momento dell'attivazione.

### Interfaccia principale

L'interfaccia è suddivisa in tre aree:

```
┌──────────┬────────────────────────────┬───────────────┐
│  MENU    │   CONTENUTO PRINCIPALE     │  PANNELLO     │
│ LATERALE │                            │  KPI (opz.)   │
└──────────┴────────────────────────────┴───────────────┘
```

**Menu laterale** (sinistra): accesso rapido a tutte le sezioni.

| Icona | Sezione |
|-------|---------|
| 🏠 | Dashboard |
| 💬 | SegretarIA |
| 📅 | Agenda |
| 👥 | Pazienti |
| 📋 | Preventivi |
| 🧾 | Fatturazione |
| 🔔 | Richiami |
| 📦 | Magazzino |
| ⚙️ | Impostazioni |

**Header** (in alto): mostra il nome dello studio e il selettore operatore.

### Cambio operatore

In alto a destra è disponibile un menu a tendina per selezionare l'operatore attivo:

- **Segreteria** — visione completa di tutti i dati
- **Dottore / Igienista** — visione filtrata sui propri appuntamenti e preventivi

Il cambio operatore non richiede logout: è sufficiente selezionare il nome dal menu.

### Navigazione mobile

Su smartphone il menu laterale è accessibile tramite il pulsante ≡ in alto a sinistra. La barra di navigazione rapida è disponibile in basso nella schermata.

---

## 3. Dashboard

La Dashboard è la schermata iniziale e offre una panoramica immediata dell'attività dello studio.

### Occupazione giornaliera

Mostra la percentuale di occupazione delle poltrone per la giornata corrente, calcolata come:

> (appuntamenti completati + confermati) / totale slot disponibili × 100

Un indicatore circolare cambia colore in base al valore:
- **Verde** — sotto il 40%
- **Giallo** — 40–70%
- **Arancione** — 70–90%
- **Rosso** — oltre il 90%

### Piani di cura

Grafico a barre che mostra la distribuzione degli stati dei piani di cura attivi:
- **Bozza** (grigio)
- **Proposto** (blu)
- **Accettato** (verde)
- **Rifiutato** (rosso)

### Prossimi appuntamenti

Lista degli appuntamenti futuri della giornata, ordinati cronologicamente. Ogni riga mostra paziente, orario, trattamento, professionista e stato.

### Allerte cliniche

Evidenzia i pazienti con allerte anamnestiche registrate (allergie alla penicillina, al lattice, all'anestetico, ipertensione, diabete, anticoagulanti, bifosfonati). Fino a 3 allerte in evidenza per attirare l'attenzione prima della visita.

> **Nota:** La dashboard si aggiorna automaticamente al cambio operatore. Il medico vede solo i propri appuntamenti; la segreteria vede tutto lo studio.

---

## 4. Pazienti

### 4.1 Lista pazienti

La sezione Pazienti mostra l'elenco completo dei pazienti dello studio.

**Ricerca:** digitare il nome (o cognome) nella barra di ricerca in alto — la lista si aggiorna in tempo reale.

**Filtri rapidi:**
| Tab | Descrizione |
|-----|-------------|
| Tutti | Tutti i pazienti registrati |
| Attivi | Pazienti con appuntamenti recenti |
| Archiviati | Pazienti non più seguiti |

**Informazioni mostrate per ogni paziente:**
- Avatar con iniziali (colore determinato automaticamente)
- Nome completo
- Età
- Telefono
- Email

Cliccare su un paziente per aprire la scheda dettaglio.

---

### 4.2 Nuovo paziente

Per registrare un nuovo paziente premere il pulsante **+ Nuovo paziente** e seguire i tre step del wizard:

#### Step 1 — Dati anagrafici
| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Cognome | ✓ | |
| Nome | ✓ | |
| Data di nascita | ✓ | |
| Sesso | — | M / F |
| Codice fiscale | — | 16 caratteri |

#### Step 2 — Contatti
| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Telefono | ✓ | |
| Email | — | |
| Indirizzo | — | |
| Città | — | |
| CAP | — | |
| Provincia | — | |

#### Step 3 — Dati clinici
| Campo | Note |
|-------|-------|
| Note cliniche | Testo libero, visibile in scheda |
| Allergie | Checkbox: penicillina, lattice, anestetico |

Premere **Salva** nell'ultimo step per creare il paziente e tornare alla lista.

---

### 4.3 Scheda paziente

La scheda paziente è il centro di tutte le informazioni cliniche e amministrative. È organizzata in tab:

```
Anagrafica | Cartella | Anamnesi | Odontogramma | Piani di cura | Preventivi | Documenti
```

#### Tab Anagrafica

Mostra i dati demografici e di contatto del paziente. Premere **Modifica** per aggiornare qualsiasi campo.

**Foto paziente:**
- Premere il cerchio con le iniziali per aprire il pannello foto
- Scattare con **Webcam** oppure caricare un **file** (JPG/PNG)
- La foto viene ritagliata automaticamente a 400×400 pixel
- Premere **Rimuovi foto** per tornare alle iniziali

**Indicatori clinici** (visibili nella card riassuntiva):
- 🔴 Allergia alla penicillina
- 🔴 Allergia al lattice
- 🔴 Allergia all'anestetico
- 🟠 Ipertensione
- 🟠 Diabete
- 🟠 Patologie cardiache
- 🟡 Fumatore
- 🟡 Anticoagulanti
- 🟡 Bifosfonati

Questi indicatori vengono mostrati anche nell'agenda come allerta al momento dell'appuntamento.

**Storico appuntamenti:** in fondo alla tab Anagrafica è presente lo storico di tutti gli appuntamenti del paziente. È possibile modificare lo stato direttamente dalla lista tramite il menu a tendina su ogni riga.

---

### 4.4 Anamnesi

La tab **Anamnesi** raccoglie la storia medica dettagliata del paziente tramite categorie configurabili.

**Compilazione:**
1. Premere **Modifica anamnesi**
2. Espandere le categorie desiderate cliccando sul titolo
3. Selezionare le voci applicabili con i checkbox
4. Aggiungere note specifiche per ogni voce nel campo testo sottostante
5. Selezionare il **gruppo sanguigno** dal menu a tendina (A+, A-, B+, B-, AB+, AB-, O+, O-)
6. Aggiungere note generali nell'apposito campo
7. Premere **Salva**

**Lettura rapida:**
- Ogni categoria mostra il numero di voci selezionate
- Le voci marcate come **allerta** (configurabili in Impostazioni) compaiono nel badge rosso della categoria
- La data dell'ultima compilazione è visibile in alto

> Le categorie e le voci anamnestiche si configurano in **Impostazioni → Anagrafiche → Catalogo anamnesi**.

---

### 4.5 Odontogramma

La tab **Odontogramma** permette di registrare le condizioni cliniche di ogni dente tramite una mappa interattiva.

#### Navigazione
- **Denti permanenti** / **Denti decidui** — switcher in alto per alternare tra arcata adulta e pediatrica
- I denti sono numerati secondo la notazione **FDI** (es. 11, 21, 36…)

#### Registrare una condizione

1. Cliccare sulla **superficie** del dente (occlusale, vestibolare, linguale, mesiale, distale)
2. Si apre un menu contestuale con le condizioni disponibili:

| Condizione | Colore | Descrizione |
|------------|--------|-------------|
| Sano | Bianco | Dente in buona salute |
| Carie | Rosso | Lesione cariosa |
| Otturazione | Blu | Otturazione presente |
| Corona | Arancione | Corona protesica |
| Mancante | Grigio | Dente assente |
| Estratto | Grigio scuro | Estrazione effettuata |
| Impianto | Verde | Impianto osseointegrato |
| Pilastro bridge | Viola | Dente pilastro di bridge |
| Elemento bridge | Viola chiaro | Elemento intermedio |
| Devitalizzato | Viola | Trattamento canalare |
| Da estrarre | Rosso scuro | Estrazione pianificata |

3. Selezionare la condizione — la superficie cambia colore immediatamente
4. Premere **Salva** per persistere le modifiche

#### Pianifica trattamento dall'odontogramma

Il pulsante **Pianifica** apre una procedura guidata per creare un piano di cura direttamente dall'odontogramma:

1. Il sistema rileva automaticamente le condizioni che richiedono trattamento (carie, da estrarre, ecc.)
2. Per ogni dente con condizione critica vengono suggeriti i servizi appropriati
3. È possibile aggiungere/rimuovere righe e selezionare servizi da quelli configurati
4. Scegliere se **creare un nuovo piano** o **aggiungere a un piano esistente**
5. Premere **Crea piano** per generare il piano di cura

---

### 4.6 Piani di cura

La tab **Piani di cura** mostra tutti i piani terapeutici del paziente.

**Informazioni per ogni piano:**
- Nome del piano
- Stato: Bozza / Proposto / Accettato / Completato / Rifiutato
- Barra di avanzamento (% elementi completati)
- Data di creazione

**Azioni disponibili:**
| Azione | Come |
|--------|------|
| Crea nuovo piano | Pulsante **+ Nuovo piano** |
| Rinomina piano | Icona matita → modifica inline → invio |
| Apri dettaglio | Click sulla riga o icona freccia |
| Elimina piano | Icona cestino → conferma |

**Dettaglio piano di cura:**

Aprendo un piano si accede alla lista delle prestazioni pianificate con:
- Dente (notazione FDI)
- Prestazione
- Stato: da_fare / schedulato / in_corso / completato / saltato
- Professionista assegnato
- Note
- Pulsante **Prenota** per creare direttamente un appuntamento per quella prestazione

---

## 5. Agenda

### 5.1 Viste calendario

L'agenda offre quattro modalità di visualizzazione selezionabili dalla barra in alto:

#### Vista Giorno
Griglia oraria dalle **08:00 alle 18:00**, suddivisa in **3 poltrone** (colonne).
- Ogni appuntamento mostra paziente, prestazione e stato
- La riga dell'ora corrente è evidenziata
- Cliccando su uno slot libero si può creare un nuovo appuntamento

#### Vista Settimana
Panoramica dei 7 giorni della settimana. Per ogni giorno:
- Numero di appuntamenti
- Barra di occupazione colorata (verde → giallo → arancione → rosso)
- Cliccando sul giorno si passa alla vista Giorno

#### Vista Mese
Calendario mensile con:
- Percentuale di occupazione per ogni giorno lavorativo
- Colore del giorno proporzionale all'occupazione
- Click sul giorno per aprire la vista Giorno di quella data

#### Vista Prossimi
Lista cronologica degli appuntamenti futuri, con tutti i dettagli in formato lista.

#### Navigazione temporale

| Pulsante | Funzione |
|----------|---------|
| **◀ ▶** | Giorno/settimana/mese precedente o successivo |
| **Oggi** | Torna alla data odierna |
| Mini calendario | Click su qualsiasi giorno per saltare direttamente |

#### Filtro per professionista

Il menu a tendina in alto a destra permette di filtrare gli appuntamenti per professionista. Di default mostra tutti.

#### Codici colore appuntamenti

| Colore | Stato |
|--------|-------|
| 🟢 Verde | In corso |
| 🔵 Blu | Confermato |
| 🟡 Giallo | Schedulato |
| 🔴 Rosso | Annullato / No show |
| ⬜ Grigio | Completato |

---

### 5.2 Nuovo appuntamento

Premere **+ Nuovo appuntamento** (o cliccare su uno slot libero nella vista Giorno).

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Paziente | ✓ | Ricerca autocomplete (min. 2 caratteri) |
| Data | ✓ | Non è possibile selezionare giorni festivi o weekend |
| Ora | ✓ | |
| Durata | ✓ | 15, 30, 45, 60, 90, 120 minuti |
| Professionista | ✓ | |
| Poltrona | ✓ | Poltrona 1, 2 o 3 |
| Prestazione | — | Lista servizi configurati |
| Note | — | Testo libero |
| Invia promemoria | — | Checkbox per invio notifica al paziente |

**Ricerca paziente:** digitare almeno 2 caratteri — il sistema suggerisce fino a 8 risultati. Selezionare il paziente dalla lista.

**Da piano di cura:** se l'appuntamento viene creato dal dettaglio di un piano di cura, paziente, prestazione e durata vengono pre-compilati automaticamente.

Premere **Salva** per creare l'appuntamento e tornare all'agenda.

---

## 6. Preventivi

La sezione Preventivi gestisce i preventivi/offerte economiche ai pazienti.

### Lista preventivi

**Filtri per stato:**

| Tab | Descrizione |
|-----|-------------|
| Tutti | Tutti i preventivi |
| Bozza | In compilazione |
| Inviato | Inviato al paziente, in attesa |
| Accettato | Approvato dal paziente |
| Rifiutato | Non accettato |
| Scaduto | Oltre la data di validità |

**Ricerca:** per numero preventivo o nome paziente.

**KPI in evidenza:**
- Totale accettato (importo)
- Totale in attesa (importo)
- Numero preventivi per stato

> **Ruolo operatore:** Dentisti e igienisti vedono solo i propri preventivi. La segreteria vede tutti.

---

### Nuovo preventivo

Premere **+ Nuovo preventivo** e compilare:

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Paziente | ✓ | Ricerca autocomplete |
| Titolo | — | Descrizione sintetica |
| Piano di cura collegato | — | Per importare prestazioni |
| Note | — | Visibili nel documento |
| Valido fino al | — | Data di scadenza |

---

### Dettaglio preventivo

#### Voci di preventivo

Ogni riga rappresenta una prestazione offerta:

| Colonna | Descrizione |
|---------|-------------|
| Prestazione | Servizio (con prezzo default) |
| Dente | Notazione FDI (opzionale) |
| Quantità | Numero di unità |
| Prezzo unitario | Modificabile dal default |
| Sconto | Percentuale o importo |
| IVA | Aliquota applicabile |
| Totale | Calcolato automaticamente |

**Aggiungere una voce:** pulsante **+ Aggiungi voce** → selezionare prestazione → prezzo viene pre-compilato → confermare.

**Importare da piano di cura:** pulsante **Importa da piano** → seleziona le prestazioni del piano da includere → confermare.

#### Gestione stati

```
BOZZA → INVIATO → ACCETTATO
                → RIFIUTATO
        SCADUTO (automatico)
```

Premere il pulsante dello stato per avanzare nel flusso. Un preventivo **Accettato** può essere convertito in fattura dalla sezione Fatturazione.

---

## 7. Fatturazione

### Lista fatture

**Filtri per stato:**

| Tab | Descrizione |
|-----|-------------|
| Tutti | Tutti i documenti |
| Bozza | In compilazione |
| Emessa | Documento emesso |
| Pagata | Pagamento ricevuto |
| Annullata | Documento annullato |

**KPI in evidenza:**
- Totale emesso
- Totale incassato
- Documenti in bozza

---

### Nuovo documento

Premere **+ Nuova fattura** e compilare:

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Preventivo di riferimento | ✓ | Solo preventivi **Accettati** |
| Tipo documento | ✓ | Fattura / Ricevuta / Parcella / Nota credito |
| Intestatario | ✓ | Studio o singolo professionista |
| Data scadenza | — | |
| Metodo di pagamento | — | Contanti / Bonifico / Carta / ecc. |
| Note | — | |

Il documento viene pre-compilato con le voci del preventivo selezionato.

---

### Dettaglio fattura

#### Voci del documento

Struttura simile al preventivo con colonne: prestazione, dente, quantità, prezzo, sconto, IVA, totale.

**Totali calcolati automaticamente:**
- Subtotale (imponibile)
- IVA totale
- **Totale documento**

#### Azioni disponibili

| Azione | Note |
|--------|-------|
| **Modifica** | Solo se in stato Bozza |
| **Emetti** | Passa da Bozza a Emessa |
| **Segna come pagata** | Da Emessa a Pagata |
| **Annulla** | Annulla il documento |
| **Stampa** | Apre la finestra di stampa del browser |
| **Invia email** | Apre il client email con oggetto e testo pre-compilati |
| **Elimina** | Solo se in stato Bozza |

---

## 8. Richiami

La sezione Richiami gestisce il follow-up dei pazienti per controlli periodici e trattamenti da completare.

### Lista richiami

Ogni richiamo mostra:
- Nome paziente
- Tipo di richiamo
- Data prevista
- Priorità (🔴 Alta / 🟡 Media / 🟢 Bassa)
- Stato

**Stati richiamo:**

| Stato | Colore | Descrizione |
|-------|--------|-------------|
| Da contattare | Rosso | Nessun contatto ancora effettuato |
| Contattato | Giallo | Tentativo di contatto effettuato |
| In attesa | Blu | In attesa di risposta |
| Confermato | Verde | Appuntamento confermato |
| Chiuso | Grigio | Richiamo completato |
| Annullato | Strikethrough | Richiamo cancellato |

**Filtri disponibili:**
- Per stato
- Per priorità

**Pannello KPI** (destra):
- Conteggio per stato
- Lista urgenti: i 5 richiami ad alta priorità da contattare

---

### Nuovo richiamo

Premere **+ Nuovo richiamo** e compilare:

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Paziente | ✓ | Ricerca autocomplete |
| Tipo richiamo | ✓ | Es. Controllo semestrale, Igiene, ecc. |
| Data prevista | ✓ | |
| Priorità | — | Alta / Media / Bassa |
| Note | — | |

---

### Registrare un contatto

Per ogni richiamo è possibile registrare i tentativi di contatto:

1. Aprire il menu del richiamo → **Registra contatto**
2. Compilare:
   - **Tipo contatto:** Telefono / SMS / Email / WhatsApp
   - **Esito:** Risposto / Non risposto / Messaggio lasciato / Confermato / Rifiutato
   - **Note:** testo libero
3. Salvare

La cronologia di tutti i contatti è visibile nel pannello **Storico contatti** del richiamo.

---

### Genera richiami automatici

Il pulsante **Genera richiami** crea automaticamente richiami per i pazienti che non hanno un controllo recente registrato, basandosi sull'intervallo configurato in Impostazioni (default: 6 mesi).

---

## 9. Magazzino

La sezione Magazzino gestisce i prodotti, le scorte e i fornitori dello studio.

### Tab Prodotti

Mostra l'elenco di tutti i materiali e prodotti con le scorte correnti.

**Indicatori livello scorte:**

| Colore | Stato | Condizione |
|--------|-------|------------|
| 🔴 Critico | Sotto il minimo | Scorta < quantità minima |
| 🟡 Basso | Quasi esaurito | Scorta < 2× quantità minima |
| 🟢 OK | Scorta sufficiente | Scorta ≥ 2× quantità minima |

**Filtri:**
- Ricerca per nome prodotto
- Filtro per categoria

**Nuovo prodotto:** pulsante **+ Nuovo prodotto**

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Nome | ✓ | |
| Unità di misura | ✓ | Default: pz |
| Categoria | — | |
| Fornitore | — | |
| SKU / Codice | — | |
| Quantità minima | — | Soglia allerta scorta critica |
| Quantità riordino | — | Quantità suggerita per ordine |
| Costo unitario | — | |
| Descrizione | — | |

---

### Tab Movimenti

Storico di tutti i movimenti di magazzino: carico, scarico, rettifica, rientro.

**Tipi di movimento:**

| Tipo | Descrizione |
|------|-------------|
| Carico | Ricevimento merce da fornitore |
| Scarico | Consumo interno |
| Rettifica | Correzione inventario |
| Rientro | Restituzione a fornitore |

**Nuovo movimento:** pulsante **+ Movimento**

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Prodotto | ✓ | |
| Tipo | ✓ | Carico / Scarico / Rettifica / Rientro |
| Quantità | ✓ | |
| Costo unitario | — | Solo per carichi |
| Documento di riferimento | — | Es. numero DDT |
| Note | — | |

---

### Tab Fornitori

Lista dei fornitori con dati di contatto.

**Nuovo fornitore:** pulsante **+ Nuovo fornitore**

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Nome | ✓ | Ragione sociale |
| Referente | — | |
| Telefono | — | |
| Email | — | |
| Note | — | |

---

## 10. SegretarIA

La sezione **SegretarIA** è l'assistente AI dello studio (AI-DEN), che automatizza le comunicazioni con i pazienti e supporta il personale amministrativo.

### Chat

Interfaccia conversazionale per interagire con l'assistente:

- Digitare la domanda nel campo in basso e premere **Invio** o il pulsante di invio
- L'assistente risponde con testo e, quando pertinente, con tabelle dati (es. lista appuntamenti, pazienti)
- **Prompt rapidi** nella barra laterale: domande preconfigurate per le richieste più frequenti

**Esempi di domande:**
- "Chi ha chiamato oggi?"
- "Mostrami gli appuntamenti di domani"
- "Quali pazienti sono in attesa di richiamo?"

### Chiamate

Log delle chiamate in entrata e uscita con:
- Numero o nome
- Snippet della conversazione
- Orario
- Stato gestione

### Attività

Lista di attività pendenti suggerite dall'assistente con eventuali note di approfondimento e flag di urgenza.

---

## 11. Impostazioni

La sezione Impostazioni configura tutti i parametri dello studio. È suddivisa in tab tematiche.

### Studio

Dati identificativi della clinica:

| Campo | Descrizione |
|-------|-------------|
| Nome studio | Ragione sociale |
| Indirizzo | Sede operativa |
| Telefono | |
| Email | |
| Partita IVA | |
| Dati professionali | Specializzazioni, albo, ecc. |
| Dati fatturazione | IBAN, SDI, PEC |

---

### Professionisti

Gestione dei professionisti associati allo studio.

**Aggiungere un professionista:** pulsante **+ Nuovo professionista**

| Campo | Obbligatorio | Note |
|-------|:---:|-------|
| Cognome e Nome | ✓ | |
| Ruolo | ✓ | Dentista / Igienista / Ortodontista / Chirurgo / Assistente / Amministratore / Altro |
| Telefono | — | |
| Email | — | |
| Partita IVA | — | Per fatturazione come libero professionista |
| Codice fiscale | — | |
| Numero iscrizione albo | — | |
| Indirizzo fatturazione | — | |
| PEC | — | |
| IBAN | — | |
| Codice SDI | — | |
| Prefisso fatture | — | |

**Foto professionista:** come per i pazienti, è possibile caricare una foto tramite webcam o file.

---

### Anagrafiche

#### Sedi

Gestione delle sedi operative dello studio (per studi multi-sede).

#### Catalogo anamnesi

Configurazione delle categorie e voci del questionario anamnestico:

1. **Creare una categoria:** pulsante **+ Categoria** → inserire nome
2. **Aggiungere voci:** aprire la categoria → **+ Voce** → inserire nome e selezionare se è una **voce allerta** (visibile come badge rosso nella scheda paziente)

> Le voci allerta vengono mostrate nell'agenda al momento degli appuntamenti per avvisare il professionista.

---

### Agenda

| Impostazione | Descrizione |
|--------------|-------------|
| Durata slot appuntamento | Granularità minima (15, 20, 30 minuti) |
| Orario inizio | Apertura mattutina (default 08:00) |
| Orario fine | Chiusura serale (default 18:00) |
| Giorni lavorativi | Checkbox da Lunedì a Domenica |

---

### Preventivi

| Impostazione | Descrizione |
|--------------|-------------|
| Validità default | Giorni di validità standard dei preventivi |
| Prefisso numero | Es. "PRV-" → PRV-2026-001 |
| Aliquota IVA default | IVA pre-selezionata per le nuove voci |

---

### Fatturazione

| Impostazione | Descrizione |
|--------------|-------------|
| Prefisso numero fattura | Es. "FT-" → FT-2026-001 |
| Metodo pagamento default | Pre-selezionato per le nuove fatture |
| Giorni scadenza default | Scadenza standard dalla data di emissione |

---

### Richiami

| Impostazione | Descrizione |
|--------------|-------------|
| Intervallo richiamo | Mesi tra un controllo e il successivo (default: 6) |
| Intervallo secondario | Intervallo per pazienti ad alto rischio |
| Template messaggio | Testo predefinito per SMS/email di richiamo |

---

### Sistema

| Impostazione | Descrizione |
|--------------|-------------|
| Lingua / Locale | Italiano / English / Deutsch / Français |

> Il cambio lingua richiede il ricaricamento della pagina.

---

## 12. Glossario stati

### Appuntamenti

| Stato | Descrizione |
|-------|-------------|
| `schedulato` | Appuntamento registrato, non ancora confermato |
| `confermato` | Confermato dal paziente o dalla segreteria |
| `in_corso` | Paziente in studio |
| `completato` | Visita terminata |
| `annullato` | Disdetto |
| `no_show` | Paziente non presentato |

### Preventivi

| Stato | Descrizione |
|-------|-------------|
| `bozza` | In compilazione, non visibile al paziente |
| `inviato` | Inviato al paziente, in attesa di risposta |
| `accettato` | Approvato — può generare fattura |
| `rifiutato` | Non accettato dal paziente |
| `scaduto` | Superata la data di validità |

### Fatture

| Stato | Descrizione |
|-------|-------------|
| `bozza` | In compilazione, modificabile |
| `emessa` | Documento emesso, non modificabile |
| `pagata` | Pagamento ricevuto |
| `annullata` | Documento annullato |

### Piani di cura

| Stato | Descrizione |
|-------|-------------|
| `bozza` | In definizione |
| `proposto` | Presentato al paziente |
| `accettato` | Approvato dal paziente |
| `completato` | Tutti gli elementi eseguiti |
| `rifiutato` | Non accettato |

### Richiami

| Stato | Descrizione |
|-------|-------------|
| `da_contattare` | Nessun contatto ancora effettuato |
| `contattato` | Almeno un tentativo registrato |
| `in_attesa` | In attesa di conferma dal paziente |
| `confermato` | Appuntamento di follow-up confermato |
| `chiuso` | Richiamo completato |
| `annullato` | Richiamo cancellato |

---

*DentalCare Pro © 2026 — Tutti i diritti riservati*
*Per assistenza: supporto@dentalcarepro.it*
