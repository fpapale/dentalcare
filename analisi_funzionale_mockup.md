# DentalCare Pro — Analisi Funzionale Completa dai Mockup

> Documento generato il 05/05/2026 a partire dall'analisi visiva di tutti i mockup presenti in `stitch_screens/`.

---

## Indice

1. [Architettura generale](#1-architettura-generale)
2. [Moduli funzionali](#2-moduli-funzionali)
   - 2.1 [Dashboard](#21-dashboard)
   - 2.2 [Agenda](#22-agenda)
   - 2.3 [Pazienti e Anagrafica](#23-pazienti-e-anagrafica)
   - 2.4 [Cartella Clinica](#24-cartella-clinica)
   - 2.5 [Anamnesi](#25-anamnesi)
   - 2.6 [Odontogramma](#26-odontogramma)
   - 2.7 [Piano di Cura](#27-piano-di-cura)
   - 2.8 [Storico Clinico e Timeline](#28-storico-clinico-e-timeline)
   - 2.9 [Documenti e Radiografie](#29-documenti-e-radiografie)
   - 2.10 [Visualizzatore Radiografico](#210-visualizzatore-radiografico)
   - 2.11 [Gestione Preventivi](#211-gestione-preventivi)
   - 2.12 [Fatturazione](#212-fatturazione)
   - 2.13 [Gestione Richiami](#213-gestione-richiami)
   - 2.14 [Comunicazioni e Template](#214-comunicazioni-e-template)
   - 2.15 [Magazzino e Inventario](#215-magazzino-e-inventario)
   - 2.16 [Ordini d'Acquisto](#216-ordini-dacquisto)
   - 2.17 [Listino Prestazioni](#217-listino-prestazioni)
   - 2.18 [SegretarIA — Console AI](#218-segretaria--console-ai)
3. [Incoerenze rilevate](#3-incoerenze-rilevate)
4. [Funzionalità mancanti](#4-funzionalità-mancanti)

---

## 1. Architettura generale

Il prodotto è un **Practice Management System (PMS) dentistico SaaS**, multitenant, con supporto a più ruoli utente (Medico, Segreteria, Amministratore, Igienista). È composto da:

- **Frontend Angular** — interfaccia web desktop-first con design system "DentalPro Clinical Calm" (teal primario `#005c55`, tipografia Inter)
- **Backend Spring Boot** — API REST multitenant con isolamento dati per clinica
- **SegretarIA** — agente AI integrato, accessibile via console chat e via agente vocale Retell.io per le telefonate in entrata
- **Integrazioni esterne** — TeamSystem (fatturazione), n8n (automazioni), fornitori (Henry Schein Dental, Straumann, Dentsply Sirona)

La navigazione principale è verticale (sidebar sinistra), con voci contestuali al ruolo dell'utente loggato. La barra superiore mostra logo, ricerca globale, notifiche, orologio e avatar utente.

---

## 2. Moduli funzionali

### 2.1 Dashboard

**Scopo:** Panoramica operativa giornaliera per il medico o la segreteria.

**Contenuto visibile:**
- KPI in evidenza: numero pazienti del giorno, percentuale preventivi chiusi, task completati (es. `12/15`)
- **Agenda giornaliera compatta**: tabella con orario, paziente, trattamento, poltrona e stato (badge colorati: IN CORSO, IN ATTESA, CANCELLATO, PREVISTO)
- **Grafico occupazione poltrone**: indicatore circolare con percentuale di saturazione e messaggio testuale (es. "Disponibili urgenze ore 11:15")
- **Prossimi arrivi**: lista con avatar paziente, orario, alert clinici in evidenza (es. "Allergia Penicillina")
- **Promemoria**: lista di azioni pendenti testuali (es. "Inviare fatture fine mese", "Controllare scorte anestetico", "Verifica consensi informati")

**Ruoli:** Medico, Segreteria, Amministratore

---

### 2.2 Agenda

**Scopo:** Gestione e visualizzazione degli appuntamenti per poltrona.

**Vista principale — Giornaliera per Poltrona:**
- Colonne per poltrona, ciascuna con nome e specializzazione (es. Poltrona 1 – Igiene & Prevenzione, Poltrona 2 – Conservativa, Poltrona 3 – Chirurgia)
- Scorrimento verticale per fasce orarie (da 08:00 in poi)
- Blocchi appuntamento colorati con: nome paziente, tipo prestazione, orario inizio/fine, icona di stato
- Linea rossa sull'ora corrente
- Toggle viste: Mese / Sett. / Giorno

**Filtri laterali:**
- Filtro per medico (checkbox per ogni operatore)
- Bottone "Mio Calendario" per vista personale
- Ricerca globale per paziente o prestazione nella barra superiore

**Azioni rapide:**
- Pulsante "+ Nuovo Appuntamento" (header)
- Pulsante "Emergenza" (rosso, prominente nella sidebar) per inserimento rapido urgenze

**Modal Nuovo Appuntamento:**
- Ricerca paziente per nome/cognome/CF con link "Nuova Anagrafica"
- Selezione tipo prestazione (chip rapidi: Prima Visita, Igiene Orale, Controllo) + dropdown prestazione specifica con durata stimata
- Selezione medico con avatar e specializzazione
- Selezione poltrona operativa (dropdown)
- Mini calendario integrato per navigazione data
- Griglia slot disponibili mattina/pomeriggio con indicazione durata appuntamento e orario di fine previsto
- Pulsanti: Annulla / Conferma Prenotazione

---

### 2.3 Pazienti e Anagrafica

**Scopo:** Ricerca, creazione e gestione dell'elenco pazienti.

**Elenco Pazienti:**
- Lista card con: avatar, nome, stato badge (Attivo / In Attesa / Archiviato), età, CF, telefono, data e tipo ultimo appuntamento
- Filtri: Tutti / Attivi / Archiviati + filtro avanzato + ordinamento
- Pulsante "+ Nuovo Paziente"
- Link "Vedi Dettagli →" per ogni paziente

**Form Nuovo Paziente:**
- Dati Anagrafici: Nome, Cognome, Data di Nascita, Codice Fiscale
- Contatti: Telefono (+39), Email, Indirizzo/Città/CAP

**Form Modifica Dati Anagrafici:**
- Dati Personali: Nome, Cognome, Data di Nascita, Genere, Codice Fiscale
- Recapiti & Contatti: Email, Telefono/Cellulare, Indirizzo, Città, CAP
- **Privacy & Consensi** (sezione dedicata):
  - Consenso Trattamento Dati (GDPR) — toggle on/off, link "Vedi Atto", data ultimo aggiornamento
  - Comunicazioni & Marketing — toggle on/off
  - Badge "Consenso Attivo" visibile nell'header della sezione

**Header paziente persistente** (visibile in ogni schermata del paziente):
- Avatar, nome, ID paziente, data di nascita/età, telefono, email
- Badge allergia in evidenza (rosso, es. "Allergia Penicillina – Rischio Shock Anafilattico")
- Pulsante modifica allergia

---

### 2.4 Cartella Clinica

**Scopo:** Vista riepilogativa clinica del paziente, punto di accesso a tutti i dati clinici.

**Navigazione rapida** (icone grandi):
- Anamnesi
- Odontogramma
- Imaging & RX
- Piani di Cura

**Timeline Trattamenti:**
- Lista cronologica delle sedute con: data, tipo prestazione, note cliniche brevi, badge medico, badge "1 RX allegata" se presente
- Link "Vedi tutto" per storico completo
- Stato seduta indicato da pallino colorato (verde = completato, grigio = storico)

**Sidebar Riassunto Clinico** (pannello destro, sempre visibile):
- Allergie Note (badge rosso con nome farmaco)
- Farmaci in Uso (nome, dosaggio, posologia)
- Patologie Pregresse (con note di controllo)
- Pulsante "Aggiorna Anamnesi"

---

### 2.5 Anamnesi

**Scopo:** Raccolta e aggiornamento della storia medica del paziente.

**Sezioni:**

**Medical Anamnesis / Generale:**
- Allergie & Reazioni (toggle + dettaglio tipo reazione, farmaco, note)
- Farmaci Attuali (toggle + nome farmaco, dosaggio, controindicazioni note)
- Alert visivo se allergie critiche presenti (banner rosso con nome allergia)
- Pulsante "Firma & Accetta" per conferma paziente
- Data/ora ultima modifica

**Interventi Chirurgici Pregressi:**
- Toggle abilitazione + campo descrizione libera

**Sintomi Attuali & Motivo della Visita:**
- Toggle + campo note libere

**Abitudini Viziate** (sezione dedicata):
- Fumo (toggle + dettaglio quantità)
- Consumo Alcol (toggle + frequenza)
- Bruxismo (toggle + campo note)
- Altre abitudini parafunzionali

**Informazioni Cliniche Aggiuntive:**
- Gruppo sanguigno
- Ipertensione (toggle + nota "lieve controllata")
- Altri parametri configurabili

---

### 2.6 Odontogramma

**Scopo:** Rappresentazione grafica interattiva dello stato dentale del paziente.

**Caratteristiche:**
- Schema dentale secondo notazione FDI (Federazione Dentaria Internazionale)
- Ogni dente rappresentato graficamente con stato clinico colorato:
  - Carie: rosso `#DC2626`
  - Otturazione/Composito: blu `#2563EB`
  - Devitalizzato: viola `#7C3AED`
  - Impianto: verde `#16A34A`
  - Corona: marrone `#B45309`
  - Dente mancante: grigio `#6B7280`
- Mockup disponibile in versione **mobile** (navigazione contestuale al paziente)
- Accessibile dalla navigazione rapida della cartella clinica

---

### 2.7 Piano di Cura

**Scopo:** Definizione, visualizzazione e monitoraggio del piano terapeutico per il paziente.

**Caratteristiche rilevabili:**
- Accesso dalla navigazione rapida della cartella clinica
- Associato alla schermata "Storico Clinico" con pulsante "Piano di Cura" prominente nella sidebar
- I mockup specifici del piano di cura dettagliato non risultano leggibili nella risoluzione disponibile — si raccomanda di acquisire versioni ad alta risoluzione

---

### 2.8 Storico Clinico e Timeline

**Scopo:** Vista cronologica completa della storia clinica del paziente.

**Layout a due colonne:**

**Colonna sinistra — Storico Interventi:**
- Interventi chirurgici/ospedalieri pregressi (es. Appendicectomia, Estrazioni)
- Fonte (es. "Chirurgia addominale")
- Pulsante "+ Aggiungi Precedente"

**Colonna sinistra in basso — Informazioni Cliniche:**
- Gruppo sanguigno
- Fumo (Sì/No)
- Ipertensione (livello)

**Colonna destra — Cronologia Visite:**
- Tab: Tutti / Refert / Interventi
- Cards per ogni visita con: tipo prestazione, data, stato (COMPLETATO), note cliniche dettagliate, materiali usati (es. "Filtek Supreme XTE"), numero elemento dentale
- Thumbnail RX inline dove disponibile con nome file e dimensione
- Pulsante "+" per aggiungere nuova voce

**Header paziente persistente** con: nome, ID, data nascita/età, telefono, email, alert allergia modificabile, tab di navigazione (Pazienti / Agenda / Referti).

**Sidebar sinistra:**
- Navigazione interna paziente: Dashboard, Anamnesi, Odontogramma, Surgical History, Timeline, Documents
- Pulsante "Piano di Cura" (verde, prominente)

---

### 2.9 Documenti e Radiografie

**Scopo:** Archiviazione e gestione di documenti amministrativi e clinici del paziente.

**Tab:**
- Documenti Amministrativi: lista con nome file, data, tipo (Consent, Estimate…), uploader, azioni (visualizza, scarica, elimina)
- Radiografie e Imaging: accesso alle immagini diagnostiche

**Upload nuovo documento:**
- Selezione template predefinito (dropdown)
- Categoria (Clinical, Administrative…)
- Data
- Note aggiuntive
- Caricamento file drag & drop (PDF, JPG, PNG, max 10MB)
- Anteprima caricamento in corso
- Pulsante "Salva e Archivia"

**Formati supportati:** PDF, DICOM, JPG/PNG

---

### 2.10 Visualizzatore Radiografico

**Scopo:** Visualizzazione clinica e annotazione di immagini radiografiche.

**Funzionalità:**
- Visualizzazione full-screen dell'immagine (es. OPT panoramica)
- Controlli immagine: Luminosità (slider), Contrasto (slider)
- Strumenti: Invert, Sharpen
- Pannello laterale sinistro: Adjustments, Metadata, History, Annotations
- Strumenti di navigazione immagine (zoom in/out, pan, misurazioni)
- Indicatore risoluzione (es. "R: 2048 L: 1024") e stato "Ready"
- Informazioni paziente (nome, DOB) e data acquisizione nell'header
- Azioni: Share, Export, Close
- Pulsante "Save Changes"

---

### 2.11 Gestione Preventivi

**Scopo:** Creazione, gestione e invio di preventivi al paziente.

**Lista preventivi (per paziente):**
- Cards con: codice preventivo (es. PRV-2023-089), titolo descrittivo, stato badge (Accettato / Bozza / Inviato), data, importo totale
- Pulsante "+ Nuovo Preventivo"
- Ricerca preventivi

**Editor preventivo (pannello destro):**
- Codice e titolo preventivo
- Azioni: Stampa PDF, Invia al Paziente
- Ricerca prestazione da listino (campo + pulsante "Sfoglia Listino")
- Tabella voci: Dente, Prestazione, Qtà, Prezzo Unit., Sconto %, Totale
- Riepilogo: Subtotale, Sconto Globale (%), Totale in evidenza
- Note / Condizioni di pagamento (campo libero, es. "Pagamento rateale in 3 tranches")
- Firma Paziente (campo) + Spazio Pubblico
- Azioni finali: Salva Bozza, Scarica Firmato

**Stati preventivo:** Bozza → Inviato → Accettato

---

### 2.12 Fatturazione

**Scopo:** Gestione del ciclo passivo/attivo delle fatture con sincronizzazione contabile.

**KPI dashboard fatturazione:**
- Fatturato mensile (es. €45.200, trend +12% vs mese scorso)
- Pagamenti in sospeso (es. €8.450, con alert "15 fatture scadute")
- Stato sync TeamSystem (es. "Last synced: 10 mins ago", 98% sincronizzato)

**Lista fatture:**
- Colonne: Data, Numero Fattura, Paziente, Importo, Stato (Paid / Overdue / Pending), TS Sync (icona stato), Azioni
- Filtri: per data, per stato
- Ricerca per paziente o numero fattura
- Pulsanti: Export Report, Create Invoice
- Paginazione (es. "245 entries, pagina 1/25")

**Integrazione TeamSystem:** sincronizzazione bidirezionale, visibile per ogni fattura

---

### 2.13 Gestione Richiami

**Scopo:** Pianificazione e monitoraggio dei richiami periodici per igiene e follow-up.

**KPI:**
- Scadenze del mese (es. 124, di cui 32 scaduti da contattare — alert rosso)
- Richiami effettuati (es. 86, +12% rispetto mese scorso)
- Tasso conversione in appuntamento (es. 45%, con barra di avanzamento)

**Lista pazienti da contattare:**
- Colonne: Paziente (avatar + nome), Ultima Igiene (data), Trascorsi (mesi), Stato Richiamo (badge: Da Contattare / Contattato / Prenotato), Ultima Nota, Azioni
- Filtri: Prossimi 30 giorni, Tutti gli Operatori
- Azioni per paziente: chiama (icona), invia email, invia SMS, stampa

**Pulsante "+ Nuovo Appuntamento"** per conversione diretta dal richiamo.

---

### 2.14 Comunicazioni e Template

**Scopo:** Invio di notifiche ai pazienti (Email/SMS) e gestione dei template di comunicazione.

**Gestione Richiami / Invio:**
- Lista pazienti con stato scadenza, checkbox selezione multipla
- Filtro per scadenza (es. "Questo Mese")
- Selezione canale: Email o SMS (toggle)
- Pulsante "Invia Selezionate" / "Invia Notifiche Selezionate"
- **Anteprima notifica in tempo reale** (pannello destro):
  - Mockup smartphone per SMS con testo personalizzato
  - Preview email con: mittente (nome clinica), destinatario, oggetto, corpo completo con variabili sostituite (nome paziente, data ultima visita, CTA prenotazione)
  - Selezione template dal dropdown

**Libreria Template:**
- Lista template con: nome, canale (badge Email/SMS), anteprima testo, data ultima modifica
- Tab filtro: Tutti / Email / SMS
- Pulsante "+ Nuovo Template"

**Editor Template:**
- Nome template
- Canale (toggle Email / SMS)
- Oggetto (solo Email)
- Inserimento variabili dinamiche: `{Nome Paziente}`, `{Data Appuntamento}`, `{Ora Appuntamento}`, `{Nome Medico}`, `{Data Ultima Visita}`, `{Altro Motivo}`
- Corpo del messaggio con contatore caratteri (es. "124/160 caratteri (1 SMS)")
- Indicatore formato (Email Standard)
- **Anteprima in tempo reale** con dati simulati evidenziati

**Template predefiniti rilevati:**
- Promemoria Appuntamento (SMS)
- Recall Igiene Semestrale (Email)
- Preventivo Dettagliato (Email)
- Auguri Compleanno (SMS)
- Richiamo Igiene Orale (SMS)

---

### 2.15 Magazzino e Inventario

**Scopo:** Gestione delle scorte di materiali clinici e consumabili.

**KPI Warehouse:**
- Prodotti totali (es. 1.248, su 12 categorie)
- Alert scorte basse (es. 14 prodotti sotto la soglia minima — evidenziato in rosso)
- Ordini in attesa (es. 5, attesi questa settimana)
- Spesa mensile (es. $4.250, -12% vs mese scorso)

**Inventory List / Inventory Overview:**
- Colonne: Nome prodotto, Categoria, SKU, Stock attuale, Stock minimo, Prezzo unitario, Fornitore, Azioni
- Alert visivo per prodotti sotto soglia (punto rosso o badge "0 boxes")
- Categorie: Consumabili, Anestetici, Restaurativi, Strumenti, Impianti
- Filtri per categoria e stato
- Export lista
- Pulsante "+ Add Stock" / "+ Add New Item"
- Azioni per prodotto: modifica, riordina

**Receiving Dock:**
- Lista consegne in attesa con fornitore, data attesa, numero articoli
- Dettaglio ordine: voce per voce con quantità attesa, quantità ricevuta, numero lotto (scannerizzabile), data scadenza
- Pulsanti: Save Draft, Confirm Receipt, Print Packing Slip

---

### 2.16 Ordini d'Acquisto

**Scopo:** Gestione degli ordini ai fornitori e tracciamento consegne.

**KPI:**
- Totale ordini (es. 248)
- Consegne in attesa (es. 12)
- Spesa mensile (es. €4.250)

**Lista ordini:**
- Colonne: Order ID, Fornitore (es. Henry Schein Dental, Straumann Group, Dentsply Sirona), Data, Importo totale, Stato (Delivered / Sent / Draft / Cancelled)
- Pulsante "+ Nuova Ordine" / "+ New Purchase Order"

**Creazione Ordine:**
- Prodotto con immagine, SKU interno, prezzo unitario standard
- Alert scorte (es. "8 bags left in stock")
- Selezione fornitore (dropdown)
- Quantità da ordinare (stepper +/-) con quantità di riordino consigliata
- Note ordine (campo libero per istruzioni al ricevimento)
- Riepilogo ordine: subtotale, tasse stimate, totale
- Azioni: Save as Draft, Send Order

---

### 2.17 Listino Prestazioni

**Scopo:** Configurazione del catalogo prestazioni e dei prezzi dello studio.

**Struttura rilevabile:**
- Totale voci (es. 34 prestazioni catalogate)
- Raggruppamento per categoria:
  - Igiene & Prevenzione (45 voci)
  - Conservativa (112 voci)
  - Protesi & Impianti (85 voci)
- Filtri per categoria
- Navigazione: Listino Prezzi + Configurazione

**Nota:** il mockup è parzialmente troncato, la parte destra del dettaglio non è visibile.

---

### 2.18 SegretarIA — Console AI

**Scopo:** Interfaccia di dialogo in linguaggio naturale per il personale dello studio, integrata con i dati gestionali.

**Caratteristiche:**
- Intestazione: "Console AI Operativa" con indicatore di stato AI (icona verificata)
- Contesto mostrato in header: Studio, nome clinica, città, ruolo utente (es. "Segretaria")
- Campo input in basso: "Chiedi a SegretarIA cosa vuoi sapere..."
- Resettare conversazione (icona in alto a destra)

**Comportamento dell'agente:**
- Risponde in linguaggio naturale con dati strutturati (tabelle inline con Ora / Paziente / Prestazione)
- Indica la fonte ("SEGRETARIA AI • ORA") e contestualizza la risposta (es. specifica lo studio, il medico, il numero di visite confermate vs in attesa)
- Suggerisce azioni successive tramite **chip di risposta rapida** nella parte bassa (es. "Chi ha chiamato oggi?", "Stato preventivo Sig. Rossi", "Resoconto chiamate perse", "Prossimo slot disponibile")

**Integrazione:**
- Connesso all'agente vocale Retell.io per la gestione telefonate in entrata
- Filtra le risposte in base al ruolo dell'utente loggato (multitenant + RBAC)

---

## 3. Incoerenze rilevate

Le seguenti incoerenze emergono dal confronto tra i mockup e andrebbero risolte prima dello sviluppo o durante la fase di design review.

### 3.1 Nome prodotto non uniforme (CRITICO)

Il nome del prodotto cambia tra mockup diversi senza una logica apparente:

| Mockup | Nome mostrato |
|--------|---------------|
| Dashboard, Agenda, Cartella Clinica | **DentalCare Pro** |
| Gestione Preventivi | **DentalPro PMS** |
| Storico Clinico | **DentalCare Pro – Patient Management** |
| Warehouse | **DentalPro** / **DentalCore Ops** / **ClinicalOS** |
| Fatturazione | **DENTACLINC** |
| Documenti | **DENTALOS CLINICAL** / **CLINICAL CENTRAL** |
| Dashboard Paziente | **DentaFlow Pro** |
| Creazione Ordine | **DentalCore Ops** |
| Invio Richiami | **Dr. Dental System** |
| Template | **Clinical Studio** |

**Raccomandazione:** scegliere un unico nome prodotto e applicarlo sistematicamente a tutti gli schermi.

### 3.2 Lingua mista (ALTO)

Diversi schermi mostrano etichette e label in inglese invece che in italiano:

- "Warehouse Management", "Inventory Overview", "Receive Goods", "Purchase Management"
- "Billing & Invoices", "Financial Management", "Patient Header"
- "Clinical Records", "Surgical History", "Treatment Plan"

**Raccomandazione:** definire la lingua target del prodotto (italiano per il mercato domestico) e allineare tutti i mockup.

### 3.3 Navigazione laterale incoerente (ALTO)

Le voci del menu cambiano da schermata a schermata:

- "Pazienti" vs "Anagrafica Pazienti" vs "Patient Files"
- "Cartelle Cliniche" vs "Clinical Records" vs "Cartella Clinica"
- "Contabilità" vs "Fatturazione" vs "Billing & Invoices"
- "Magazzino" vs "Warehouse" vs "Inventory"
- In alcuni mockup compaiono voci non presenti in altri (es. "Amministrazione", "Richiami Igiene", "Comunicazioni", "Marketing", "Template")

**Raccomandazione:** definire un'information architecture fissa con un set canonico di voci di menu per ciascun ruolo.

### 3.4 Inconsistenza viewport (MEDIO)

- Il mockup **Odontogramma** è in formato mobile
- Il mockup **Nuovo Paziente** è in formato mobile
- Tutti gli altri mockup sono desktop

**Raccomandazione:** allineare i due mockup mobile alla versione desktop, oppure produrre esplicitamente una serie di mockup mobile separata se la responsive è in scope.

### 3.5 Doppia versione Magazzino (MEDIO)

Esistono due schemi visivi distinti per il magazzino ("Warehouse Management" e "Inventory Overview") con layout e stile leggermente differenti. Non è chiaro se siano la stessa schermata in due iterazioni o due viste diverse dello stesso modulo.

**Raccomandazione:** consolidare in un unico design o documentare esplicitamente le due viste (es. "Vista Lista" vs "Vista Overview").

### 3.6 Piano di Cura illeggibile (MEDIO)

I due mockup "Piano di Cura Dettagliato" sono ridotti a dimensioni non leggibili — non è possibile valutarne il contenuto né verificarne la coerenza con gli altri schermi clinici.

**Raccomandazione:** acquisire o ricreare i mockup del Piano di Cura ad alta risoluzione, poiché è un modulo centrale del prodotto.

### 3.7 Listino Prestazioni troncato (BASSO)

Il mockup "Gestione Prestazioni" è visibile solo nella colonna sinistra (sidebar + contatori categorie). La parte destra — che dovrebbe mostrare il dettaglio del listino — è fuori campo.

**Raccomandazione:** acquisire lo screenshot completo o ricreare il mockup a schermo intero.

### 3.8 Incoerenza stile fatturazione (BASSO)

La schermata "Fatturazione" ha uno stile visivo sensibilmente diverso dagli altri moduli (palette più chiara, layout header differente, lingua inglese). Sembra un mockup importato da un altro progetto.

**Raccomandazione:** riallineare al design system "DentalPro Clinical Calm" (teal primario, Inter, stessa struttura header).

---

## 4. Funzionalità mancanti

Le seguenti funzionalità sono comunemente attese in un PMS dentistico completo e non sono rilevabili nei mockup disponibili.

### 4.1 Schermata di Login e Gestione Accessi (CRITICO)

Nessun mockup mostra il flusso di autenticazione (login, recupero password, MFA). È necessario per qualsiasi prodotto SaaS.

### 4.2 Impostazioni Studio e Configurazione Multitenant (CRITICO)

La voce "Impostazioni" è presente nella sidebar di molti schermi ma non esiste nessun mockup dedicato. Manca la UI per:
- Dati della clinica (nome, indirizzo, P.IVA, logo)
- Gestione operatori e ruoli
- Configurazione poltrone e sale operatorie
- Orari di apertura dello studio
- Configurazione del modulo SegretarIA

### 4.3 Agenda — Gestione Disponibilità e Blocchi (ALTO)

Nell'agenda non è presente una funzionalità per:
- Bloccare fasce orarie (riunioni, formazione, pause)
- Gestire ferie e assenze del medico
- Impostare orari ricorrenti per poltrona/operatore

### 4.4 Appuntamenti Ricorrenti (ALTO)

Nessuna UI per la gestione di cicli terapeutici multi-seduta (es. 8 sedute di ortodonzia ogni 3 settimane). Cruciale per specialità come ortodonzia, implantologia e fisioterapia cranio-mandibolare.

### 4.5 Piano di Pagamento e Gestione Rateale (ALTO)

Nel preventivo si menziona il pagamento rateale ma non esiste un modulo dedicato per:
- Definire le tranches (importo, data scadenza)
- Tracciare i pagamenti ricevuti vs attesi
- Inviare promemoria automatici per le scadenze di pagamento

### 4.6 Automazioni e Regole di Recall (ALTO)

Il modulo richiami mostra la gestione manuale ma manca la configurazione di regole automatiche, ad esempio:
- "6 mesi dopo un'igiene → invia SMS automatico"
- "3 giorni prima di un appuntamento → invia promemoria email"
- "Dopo accettazione preventivo → invia email di conferma"

### 4.7 Reportistica e Analytics (ALTO)

Nessun mockup mostra un modulo report/statistiche avanzato. In un PMS dentistico sono essenziali:
- Produzione per medico / periodo
- Prestazioni più erogate
- Tasso di no-show e cancellazioni
- Andamento del fatturato per categoria di cura
- Efficienza di occupazione delle poltrone

### 4.8 Gestione Consensi Digitali (MEDIO)

Il consenso GDPR è gestito come toggle nell'anagrafica, ma manca un modulo dedicato per:
- Firma digitale del paziente su tablet/schermo
- Archiviazione con validità legale
- Template consensi specifici per trattamento (es. consenso anestesia, consenso radiologico)
- Storico versioni dei consensi firmati

### 4.9 Portale Paziente / Prenotazione Online (MEDIO)

SegretarIA si occupa delle telefonate in entrata, ma non esiste un mockup del lato paziente per la prenotazione autonoma online (link/QR code → form prenotazione → conferma via email/SMS).

### 4.10 Integrazione DICOM / Software Radiologico (MEDIO)

Il viewer radiografico è presente, ma non esiste una UI per configurare l'integrazione con software di acquisizione RX (es. Romexis, SIDEXIS, Carestream). Manca il flusso di importazione automatica delle immagini.

### 4.11 Notifiche Interne e Task per lo Staff (MEDIO)

La dashboard mostra una "Promemoria" testuale, ma manca un vero sistema di notifiche interne/task per il team (es. assegnare un'azione a un collega, marcare come completata, ricevere alert in-app).

### 4.12 Sterilizzazione e Tracciabilità Strumenti (MEDIO)

Nessun modulo per la gestione dei cicli di sterilizzazione degli strumenti, richiesto dalle normative sanitarie (UNI EN ISO 17665). In particolare:
- Tracciabilità del ciclo autoclave per seduta/paziente
- Registro sterilizzazioni con data, operatore, parametri
- Alert scadenza manutenzione autoclavi

### 4.13 Gestione Lista d'Attesa (BASSO)

Non esiste una UI dedicata per la lista d'attesa (pazienti in coda per uno slot disponibile con priorità e notifica automatica alla cancellazione).

### 4.14 Integrazione Cassa / POS (BASSO)

La fatturazione è presente ma non c'è un mockup per il registro di cassa, incasso diretto e gestione dei metodi di pagamento (contante, carta, bonifico) con stampa dello scontrino fiscale/ricevuta.

### 4.15 App Mobile per il Medico (BASSO)

L'odontogramma è l'unico mockup mobile disponibile. In contesti clinici il medico spesso usa un tablet al letto/poltrona del paziente. Manca una strategia mobile documentata con i mockup relativi.

---

*Fine documento — versione 1.0*
