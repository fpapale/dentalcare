# Spec: Copilot vocale “Hands-Free” da poltrona (#39)

**Data:** 2026-07-22

**Proposta originale:** `directives/proposte-modifiche.md` §39

**Stato:** Approvato e pianificato; sviluppo non avviato

---

## Obiettivo

Aggiungere la voce come canale di ingresso e uscita del Copilot esistente. La frase pronunciata dopo “Ehi Giulia” diventa un normale messaggio della chat Copilot; risposta, cronologia, contesto paziente, autorizzazioni, conferme e audit restano quelli del Copilot.

Non viene creato un secondo agente vocale né una cronologia parallela.

## Decisioni approvate

| Tema | Decisione |
|---|---|
| Disponibilità | Pannello Copilot globale, utilizzabile da tutte le schermate autorizzate |
| Attivazione | Hotword “Ehi Giulia” disattivabile + pulsante microfono manuale |
| Destinazione | Trascrizione e risposta nella normale sessione chat Copilot |
| Invio | Immediato per domande/navigazione; revisione obbligatoria per dettature cliniche |
| Sintesi | Toggle rapido nel Copilot; configurazione completa in Impostazioni |
| Lingue | UI, riconoscimento vocale e sintesi configurabili separatamente |
| Output predefinito | “Risposte brevi”, con dati sensibili completi mostrati a schermo |
| Preferenze | Policy dello studio sul server; voce/volume/modalità della postazione in locale |
| Paziente | Solo paziente già selezionato; cambio paziente vocale escluso dall'MVP |

## Esperienza utente

### Pannello globale

`AppComponent` ospita un `CopilotVoicePanelComponent` comprimibile, visibile solo ai ruoli che possono usare il Copilot. Il pannello non cambia rotta e permette al medico di restare su anamnesi, odontogramma o documenti.

Stati espliciti:

```text
DISABLED → ARMED → LISTENING → REVIEW? → SENDING → SPEAKING
               ↘ ERROR / CANCELLED ↗
```

- **DISABLED:** microfono non acquisito.
- **ARMED:** wake word locale in attesa; indicatore persistente.
- **LISTENING:** acquisizione della singola frase dopo hotword o click.
- **REVIEW:** trascrizione clinica in attesa di correzione/conferma.
- **SENDING:** normale richiesta streaming alla chat.
- **SPEAKING:** sintesi della risposta; interrompibile immediatamente.

Il pannello mostra trascrizione, paziente corrente, sessione utilizzata, controllo `Leggi le risposte`, mute/stop e link alla chat completa.

### Flusso domanda o navigazione

1. Hotword o click sul microfono.
2. Indicatore `In ascolto` e acquisizione di una sola frase.
3. Trascrizione visibile nel pannello.
4. Invio immediato tramite lo stesso servizio della chat.
5. Messaggio utente e risposta persistiti nella sessione Copilot.
6. Lettura della risposta se la sintesi è abilitata.

### Flusso dettatura clinica

1. Il router riconosce un intento di dettatura (`DRAFT_CLINICAL_NOTE` o equivalente).
2. La trascrizione entra in stato `REVIEW`, senza chiamare tool di scrittura.
3. Il medico può correggere, confermare o annullare.
4. Solo dopo conferma il testo viene inviato alla chat come richiesta di preparazione della bozza.
5. L'eventuale salvataggio clinico conserva l'ulteriore anteprima/conferma già prevista dal Copilot.

La conferma della trascrizione e la conferma dell'azione clinica sono due gate distinti.

## Architettura

```text
AppComponent
  └─ CopilotVoicePanelComponent
       ├─ VoiceOrchestratorService (state machine)
       ├─ WakeWordAdapter
       ├─ SpeechRecognitionAdapter
       ├─ SpeechSynthesisAdapter
       ├─ CopilotConversationService
       └─ CopilotContextService
                │
                ▼
       POST /api/chat/stream (esistente)
                │
                ▼
       ChatService / tool layer / audit (esistenti)
```

### Conversazione condivisa

La logica oggi contenuta in `SegretariaComponent.sendMessage()` va estratta in `CopilotConversationService`. Pagina chat e pannello globale consumeranno lo stesso stato conversazione e lo stesso metodo di invio. Questo evita due sessioni concorrenti e garantisce che ciò che viene detto compaia immediatamente nella chat completa.

Responsabilità del servizio:

- sessione corrente e messaggi;
- invio streaming e cancellazione;
- caricamento/apertura/creazione sessioni;
- contesto UI al momento dell'invio;
- evento `assistantCompleted` utilizzato dalla sintesi;
- serializzazione delle richieste: una sola richiesta attiva per conversazione.

### Adapter vocali

Le API di voce non devono essere chiamate direttamente dai componenti. Tre interfacce rendono sostituibile il motore:

```typescript
interface WakeWordAdapter {
  arm(): Promise<void>;
  disarm(): void;
  detected$: Observable<void>;
}

interface SpeechRecognitionAdapter {
  listen(locale: string, signal: AbortSignal): Observable<RecognitionEvent>;
}

interface SpeechSynthesisAdapter {
  listVoices(locale?: string): Observable<VoiceDescriptor[]>;
  speak(text: string, options: SynthesisOptions, signal: AbortSignal): Promise<void>;
  stop(): void;
}
```

Il prototipo può usare adapter browser/locali. Il pilota clinico deve poter sostituire STT/TTS con un provider approvato senza modificare chat e UI.

## Classificazione prima dell'invio

Per decidere se inviare o richiedere revisione non ci si affida solo a un LLM remoto. Un classificatore locale conservativo intercetta formule configurate come “detta nota”, “scrivi in cartella”, “aggiungi all'anamnesi”, “prescrivi”, “salva”. Se esiste dubbio, prevale `REVIEW`.

Il backend continua comunque a classificare l'azione effettiva e applicare i gate. La classificazione frontend migliora la UX, ma non è un controllo di sicurezza.

## Sintesi vocale

Modalità:

- `off` — nessuna lettura;
- `brief` — default raccomandato; testo ridotto e privo di dettagli non necessari;
- `full` — risposta completa, se consentita dalla policy dello studio.

La risposta visualizzata in chat resta completa. Per `brief`, il backend deve restituire un campo separato `speechText` o un evento SSE dedicato: non si deve troncare arbitrariamente il Markdown nel browser. Il prompt impone che `speechText` non contenga tabelle, URL, markup o identificativi non necessari.

La sintesi parte solo all'evento di completamento, non token per token. Una nuova attivazione, il pulsante stop o “Giulia, annulla” interrompono immediatamente la riproduzione.

## Impostazioni

### Policy studio, persistita server-side

Nuova risorsa `clinic_voice_settings`, una riga per clinica:

| Campo | Default | Scopo |
|---|---:|---|
| `enabled` | `false` | Abilitazione funzionalità per lo studio |
| `wake_word_allowed` | `false` | Consente l'ascolto locale della hotword |
| `allowed_stt_locales` | `["it-IT"]` | Lingue selezionabili per riconoscimento |
| `allowed_tts_locales` | `["it-IT"]` | Lingue selezionabili per sintesi |
| `default_speech_mode` | `brief` | `off`, `brief`, `full` |
| `allow_full_sensitive_speech` | `false` | Lettura completa di risposte sensibili |
| `provider` | `prototype` | Adapter/provider configurato dal deploy |
| `updated_at`, `updated_by` | — | Tracciabilità configurazione |

Endpoint:

```text
GET /api/settings/voice
PUT /api/settings/voice     (solo admin/tenant admin)
GET /api/settings/voice/catalog
```

Il catalogo restituisce capacità reali del provider e interseca le lingue consentite; non si salvano nomi di voce arbitrari inviati dal client.

### Preferenze postazione/utente, locali

Estensione backward-compatible di `AppSettings`:

```typescript
voiceInputLocale: string;
voiceOutputLocale: string;
voiceId: string | null;
voiceSpeechMode: 'off' | 'brief' | 'full';
voiceRate: number;
voiceVolume: number;
voiceWakeWordEnabled: boolean;
```

Sono conservate nel `localStorage` già utilizzato dall'app perché dipendono da microfono, browser e postazione. La policy server ha sempre precedenza: una preferenza locale non può abilitare ciò che lo studio ha disabilitato.

La lingua UI (`locale`) resta distinta da input e output vocali. Al primo utilizzo le due lingue vocali ereditano la UI, poi diventano indipendenti.

## Modifica del contratto chat

La richiesta aggiunge metadati opzionali, senza rompere i client esistenti:

```json
{
  "message": "Apri l'ultima panoramica",
  "inputMode": "voice",
  "voice": {
    "inputLocale": "it-IT",
    "speechMode": "brief"
  }
}
```

Lo streaming aggiunge, prima di `done`:

```text
event: speech
data: {"text":"Ho aperto l'ultima panoramica.","locale":"it-IT","sensitive":false}
```

Il testo integrale continua a essere emesso con gli eventi `token`. In assenza dell'evento `speech`, la UI non sintetizza automaticamente il testo integrale.

## Contesto e sicurezza

- `patientId` resta preso da `CopilotContextService` al momento dell'invio.
- Il pannello mostra nome abbreviato del paziente e richiede contesto paziente per comandi clinici.
- Tenant, ruolo e autorizzazioni derivano esclusivamente dal JWT/backend.
- Cambiare schermata mentre è in corso una dettatura non cambia il contesto catturato all'inizio; il pannello segnala la variazione e richiede nuova conferma.
- Audio non persistito per default e mai inserito nei log.
- Trascrizione salvata solo come normale messaggio chat dopo invio/conferma; una bozza annullata resta locale e viene eliminata.
- Audit aggiunge `input_mode=voice`, locale, classe di revisione e conferma, ma non duplica il contenuto clinico.
- Permesso microfono richiesto con gesto esplicito; nessun tentativo ripetuto dopo rifiuto.

## Gestione errori e degradazione

- microfono negato/non disponibile: testo e chat restano completamente utilizzabili;
- wake word non supportata: resta il push-to-talk;
- STT non disponibile: messaggio visibile e nessun invio parziale;
- TTS non disponibile o voce rimossa: fallback su una voce compatibile, poi modalità `off`;
- perdita rete: trascrizione non clinica mantenuta come bozza locale; mai accodata automaticamente una scrittura clinica;
- risposta Copilot fallita: nessuna sintesi di messaggi tecnici o stack trace.

## Accessibilità

La voce è sempre opzionale. Tutti gli stati sono rappresentati anche visivamente e testualmente, i controlli sono utilizzabili da tastiera e lo stato non dipende solo dal colore. L'utente può interrompere ascolto e sintesi senza usare la voce.

## Metriche del pilota

Solo metriche tecniche prive di contenuto clinico:

- attivazioni manuali/hotword;
- false attivazioni dichiarate;
- latenza STT e first-token;
- richieste annullate o corrette;
- fallback di voce/provider;
- comandi riusciti per classe di intento.

## Fuori perimetro MVP

- cambio paziente tramite voce;
- ascolto remoto o persistente;
- salvataggio clinico senza doppio gate;
- firma, finalizzazione, prescrizione o eliminazione solo vocali;
- profili vocali biometrici;
- supporto offline completo;
- lettura automatica di dati sanitari completi.

## Criteri di accettazione

1. Messaggi vocali e digitati compaiono nella stessa sessione e nello stesso ordine.
2. Nessuna domanda/navigazione richiede conferma preliminare; ogni dettatura clinica entra in `REVIEW`.
3. Ogni scrittura clinica mantiene anche il gate del Copilot dopo la revisione della trascrizione.
4. Il toggle TTS nel pannello ha effetto immediato e persiste sulla postazione.
5. Voce e lingue sono selezionabili solo dal catalogo consentito dalla policy studio.
6. Con voce disabilitata o senza permesso microfono, la chat esistente non cambia comportamento.
7. Nessun audio è persistito e nessun dato sanitario compare nei log tecnici.
8. Il contesto paziente non può cambiare silenziosamente durante una richiesta vocale.
