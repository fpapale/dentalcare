# SegretarIA — Documento funzionale

## 1. Scopo del servizio

**SegretarIA** è il sistema di segreteria artificiale dello studio medico/dentistico. Il servizio nasce da un agente vocale Retell.io già operativo, capace di ricevere telefonate, interpretare le richieste del paziente e interagire con un flusso n8n per la gestione dell'agenda.

L'evoluzione proposta consiste nell'aggiungere una **console chat AI multitenant**, utilizzabile da medici, operatori sanitari, segreteria reale e personale amministrativo. La console consente agli utenti autorizzati di interrogare l'agente AI su agenda, pazienti, appuntamenti, piani di cura, preventivi e attività operative, nel rispetto dei ruoli e dei permessi assegnati a ciascun tenant.

## 2. Obiettivi principali

1. Fornire una maschera unica, semplice e professionale per dialogare con SegretarIA.
2. Consentire a ogni medico o segretaria reale di ottenere risposte operative tramite chat.
3. Integrare la chat AI con il sistema già esistente composto da Retell.io, n8n e database gestionale.
4. Garantire isolamento dati tra tenant diversi.
5. Garantire che ogni utente visualizzi solo le informazioni coerenti con il proprio ruolo.
6. Ridurre il carico operativo della segreteria reale.
7. Aumentare la velocità di risposta su agenda, pazienti, appuntamenti, preventivi e piani di cura.

## 3. Attori del sistema

### 3.1 Paziente

Il paziente interagisce principalmente tramite telefono. La chiamata viene gestita dall'agente Retell.io, che raccoglie la richiesta e attiva il flusso n8n.

Esempi di richieste:

- Prenotare un appuntamento.
- Spostare un appuntamento.
- Cancellare un appuntamento.
- Chiedere informazioni generali sugli orari dello studio.
- Richiedere conferma di una visita.

### 3.2 Segretaria reale

La segretaria reale usa la console SegretarIA per velocizzare le attività quotidiane.

Esempi di richieste:

- “Mostrami gli appuntamenti di oggi.”
- “Chi ha chiamato questa mattina?”
- “Quali appuntamenti sono da confermare?”
- “Trova il paziente Mario Rossi.”
- “Fammi il riepilogo delle richieste arrivate da Retell.”
- “Prepara una risposta per il paziente che vuole spostare l'appuntamento.”

### 3.3 Medico

Il medico usa la console per accedere rapidamente a informazioni cliniche e operative autorizzate.

Esempi di richieste:

- “Quali pazienti ho oggi?”
- “Mostrami il piano di cura del prossimo paziente.”
- “Quali trattamenti sono ancora da completare per Laura Bianchi?”
- “Riepilogami i preventivi accettati da questo paziente.”
- “Quali pazienti hanno trattamenti in corso questa settimana?”

### 3.4 Amministratore di tenant

L'amministratore gestisce utenti, ruoli, configurazioni dello studio e permessi.

Esempi di attività:

- Creare utenti.
- Assegnare ruoli.
- Configurare orari dello studio.
- Collegare agenti Retell.io e flussi n8n.
- Verificare log e audit.

### 3.5 Super admin piattaforma

Il super admin gestisce la piattaforma SaaS nel suo complesso, ma non dovrebbe accedere ai dati clinici dei tenant salvo procedure tecniche autorizzate e tracciate.

## 4. Ambito funzionale della console SegretarIA

La console deve consentire all'utente di:

1. Scrivere domande in linguaggio naturale.
2. Ricevere risposte contestuali e operative.
3. Visualizzare dati strutturati in card, tabelle o riepiloghi.
4. Lanciare azioni operative autorizzate.
5. Consultare lo storico delle interazioni AI.
6. Accedere rapidamente ad agenda, pazienti e attività aperte.
7. Visualizzare il livello di attendibilità o la fonte dei dati quando disponibile.
8. Sapere quando una richiesta non può essere eseguita per limiti di permesso.

## 5. Funzionalità principali

### 5.1 Chat operativa AI

La chat è il cuore della maschera. L'utente può scrivere richieste come:

- “Che appuntamenti ha il dottor Verdi oggi?”
- “Trova il primo slot libero per una pulizia dentale.”
- “Riepiloga le chiamate non gestite.”
- “Mostrami i preventivi in attesa di accettazione.”
- “Quali pazienti hanno piani di cura in corso?”

La risposta può contenere:

- Testo sintetico.
- Tabelle.
- Card paziente.
- Link interni alla scheda paziente.
- Azioni suggerite.
- Messaggi di blocco per permessi insufficienti.

### 5.2 Contesto di lavoro

La maschera deve permettere di impostare o riconoscere automaticamente il contesto:

- Tenant/studio attivo.
- Utente autenticato.
- Ruolo corrente.
- Medico di riferimento.
- Paziente selezionato.
- Data o intervallo temporale.
- Canale di origine della richiesta: chat interna, chiamata Retell, attività n8n.

### 5.3 Ricerca paziente

L'utente autorizzato deve poter cercare un paziente tramite:

- Nome e cognome.
- Numero di telefono.
- Email.
- Codice fiscale.
- Data di nascita.

La ricerca deve rispettare il tenant e il ruolo dell'utente. Un utente del tenant A non deve poter vedere pazienti del tenant B.

### 5.4 Agenda e appuntamenti

La console deve consentire:

- Consultazione appuntamenti giornalieri.
- Consultazione disponibilità.
- Ricerca slot liberi.
- Proposta di nuovi appuntamenti.
- Modifica appuntamenti esistenti, se autorizzata.
- Cancellazione o annullamento appuntamenti, se autorizzata.
- Riepilogo appuntamenti da confermare.

### 5.5 Piani di cura

Per i ruoli autorizzati, la console deve mostrare:

- Piano di cura attivo.
- Stato del piano.
- Trattamenti pianificati.
- Trattamenti completati.
- Trattamenti ancora da eseguire.
- Note cliniche, solo se il ruolo lo consente.

### 5.6 Preventivi

La console deve consentire:

- Visualizzazione preventivi del paziente.
- Stato preventivo: bozza, inviato, accettato, rifiutato, scaduto.
- Totale preventivo.
- Collegamento al piano di cura.
- Riepilogo delle righe del preventivo.
- Preparazione di un messaggio da inviare al paziente.

La modifica economica dei preventivi deve essere consentita solo a ruoli abilitati.

### 5.7 Chiamate Retell.io

La console deve mostrare le informazioni generate dall'agente vocale:

- Data e ora chiamata.
- Paziente riconosciuto o non riconosciuto.
- Intent della chiamata.
- Trascrizione.
- Esito della chiamata.
- Azione n8n avviata.
- Eventuale necessità di intervento umano.

### 5.8 Attività e follow-up

SegretarIA deve produrre una lista di attività operative:

- Richiamare paziente.
- Confermare appuntamento.
- Verificare disponibilità medico.
- Inviare preventivo.
- Controllare richiesta non completata.
- Gestire conflitto agenda.

## 6. Regole di autorizzazione funzionale

Ogni risposta deve essere filtrata secondo tre dimensioni:

1. **Tenant**: lo studio/clinica di appartenenza.
2. **Ruolo**: medico, segretaria, amministrativo, amministratore, ecc.
3. **Contesto operativo**: paziente, agenda, medico, area clinica, area economica.

Esempi:

| Ruolo | Può vedere agenda | Può vedere dati paziente | Può vedere note cliniche | Può vedere preventivi | Può modificare agenda |
|---|---:|---:|---:|---:|---:|
| Medico | Sì | Sì | Sì | Sì, se pertinente | Limitato |
| Igienista | Sì | Sì | Limitato | No o limitato | Limitato |
| Segretaria | Sì | Sì | No o mascherato | Sì | Sì |
| Amministrazione | Limitato | Limitato | No | Sì | No o limitato |
| Admin tenant | Sì | Sì | Configurabile | Sì | Sì |
| AI telefonica | Solo tramite tool dedicati | Solo dati minimi | No | No | Sì, se previsto dal flusso |

## 7. Casi d'uso principali

### 7.1 Riepilogo agenda del giorno

**Utente:** Medico  
**Richiesta:** “Fammi vedere i pazienti di oggi.”

**Risposta attesa:**

- Lista appuntamenti del medico.
- Orari.
- Nome paziente.
- Tipo prestazione.
- Eventuale nota operativa.
- Link alla scheda paziente.

### 7.2 Ricerca appuntamento libero

**Utente:** Segretaria  
**Richiesta:** “Trova uno slot per igiene la prossima settimana.”

**Risposta attesa:**

- Slot disponibili.
- Medico o igienista associato.
- Durata prevista.
- Azione suggerita: “prenota”.

### 7.3 Riepilogo piano di cura

**Utente:** Medico  
**Richiesta:** “Riepilogami il piano di cura di Mario Rossi.”

**Risposta attesa:**

- Piano di cura attivo.
- Trattamenti pianificati.
- Trattamenti completati.
- Trattamenti ancora da fare.
- Preventivi collegati.

### 7.4 Riepilogo chiamate da Retell

**Utente:** Segretaria  
**Richiesta:** “Cosa è successo nelle chiamate di stamattina?”

**Risposta attesa:**

- Elenco chiamate.
- Intent riconosciuto.
- Esito.
- Appuntamenti creati/modificati.
- Chiamate da controllare manualmente.

### 7.5 Blocco per permessi insufficienti

**Utente:** Amministrativo  
**Richiesta:** “Mostrami le note cliniche del paziente.”

**Risposta attesa:**

> Non posso mostrare le note cliniche con il tuo ruolo attuale. Posso però mostrarti dati amministrativi autorizzati, come appuntamenti, preventivi e recapiti del paziente.

## 8. Requisiti della maschera

### 8.1 Layout generale

La maschera deve avere:

1. Header superiore standard con logo SegretarIA.
2. Indicazione dello studio/tenant attivo.
3. Indicazione dell'utente collegato e del ruolo.
4. Menu laterale con sezioni principali.
5. Area centrale chat.
6. Pannello laterale contestuale.
7. Barra di input con suggerimenti rapidi.
8. Sezione log/attività recenti.

### 8.2 Header standard

L'header deve contenere:

- Logo standard SegretarIA.
- Nome prodotto: “SegretarIA”.
- Sottotitolo: “Assistente AI per studio medico/dentistico”.
- Tenant attivo.
- Utente corrente.
- Ruolo corrente.
- Stato integrazioni: Retell, n8n, Agenda.

### 8.3 Area chat

La chat deve contenere:

- Messaggi utente.
- Risposte AI.
- Card dati.
- Tabelle sintetiche.
- Azioni rapide.
- Avvisi di sicurezza o permessi.

### 8.4 Pannello contestuale

Il pannello contestuale deve mostrare:

- Paziente selezionato.
- Prossimo appuntamento.
- Piano di cura attivo.
- Preventivi aperti.
- Ultima chiamata Retell.
- Attività da completare.

### 8.5 Azioni rapide

Azioni suggerite:

- Cerca paziente.
- Agenda di oggi.
- Slot disponibili.
- Chiamate da controllare.
- Preventivi in attesa.
- Piani di cura attivi.
- Appuntamenti da confermare.

## 9. Integrazioni previste

### 9.1 Retell.io

Retell.io gestisce la componente vocale:

- Ricezione chiamate.
- Comprensione intent.
- Raccolta dati paziente.
- Passaggio parametri a n8n.
- Produzione trascrizione e riepilogo.

### 9.2 n8n

n8n orchestri i flussi operativi:

- Check disponibilità agenda.
- Prenotazione appuntamento.
- Modifica appuntamento.
- Cancellazione appuntamento.
- Notifiche.
- Aggiornamento database.
- Logging eventi.

### 9.3 Database gestionale

Il database contiene:

- Tenant/cliniche.
- Utenti e ruoli.
- Pazienti.
- Provider/medici/operatori.
- Agenda.
- Piani di cura.
- Trattamenti.
- Preventivi.
- Chiamate.
- Audit log.

### 9.4 Motore AI chat

Il motore AI chat non deve interrogare liberamente il database. Deve usare tool/API controllate dal backend.

## 10. Requisiti non funzionali

### 10.1 Sicurezza

- Autenticazione obbligatoria.
- Autorizzazione per tenant e ruolo.
- Audit di ogni richiesta AI.
- Log delle azioni eseguite.
- Mascheramento dati sensibili quando necessario.
- Separazione tra dati clinici, amministrativi ed economici.

### 10.2 Privacy

- Minimizzazione dei dati mostrati.
- Accesso solo per necessità operativa.
- Tracciamento degli accessi ai dati paziente.
- Conservazione controllata delle trascrizioni.
- Possibilità di anonimizzazione o oscuramento dati.

### 10.3 Affidabilità

- Risposte basate su dati aggiornati.
- Conferma prima delle azioni modificative importanti.
- Messaggi chiari in caso di errore.
- Fallback alla segreteria reale.

### 10.4 Usabilità

- Interfaccia chiara.
- Linguaggio naturale.
- Azioni rapide.
- Layout leggibile anche durante attività di studio.
- Differenziazione visiva tra risposta informativa e azione modificativa.

## 11. Stati principali

### 11.1 Stato richiesta AI

- Ricevuta.
- In elaborazione.
- In attesa di conferma.
- Completata.
- Non autorizzata.
- Fallita.
- Escalata a operatore umano.

### 11.2 Stato chiamata Retell

- Ricevuta.
- Paziente identificato.
- Paziente non identificato.
- Intent riconosciuto.
- Azione completata.
- Azione non completata.
- Da revisionare.

### 11.3 Stato attività

- Aperta.
- In carico.
- Completata.
- Annullata.
- Scaduta.

## 12. Output attesi dalla prima versione MVP

La prima versione deve permettere:

1. Login utente.
2. Selezione automatica tenant.
3. Visualizzazione ruolo corrente.
4. Chat AI con richieste testuali.
5. Query su agenda, pazienti, piani di cura e preventivi.
6. Visualizzazione delle ultime chiamate Retell.
7. Azioni rapide non distruttive.
8. Blocco coerente delle richieste non autorizzate.
9. Audit log delle richieste.

## 13. Evoluzioni successive

1. Prenotazione appuntamenti direttamente dalla chat.
2. Modifica appuntamenti con conferma.
3. Generazione messaggi WhatsApp/SMS/email.
4. Creazione preventivo assistita da AI.
5. Riepilogo clinico pre-visita per il medico.
6. RAG su documentazione dello studio.
7. Cruscotto performance chiamate Retell.
8. Analisi tempi di risposta e saturazione agenda.
9. Supporto multi-sede.
10. Integrazione con sistemi di pagamento.

## 14. Principio guida

SegretarIA deve comportarsi come una **collaboratrice digitale controllata**, non come un agente libero. Deve poter aiutare, riassumere, cercare, proporre e preparare azioni, ma l'accesso ai dati e le modifiche operative devono essere sempre governati da permessi, policy e audit.
