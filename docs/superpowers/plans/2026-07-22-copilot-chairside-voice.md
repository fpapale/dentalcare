# Copilot vocale “Hands-Free” — Piano di intervento (#39)

**Goal:** aggiungere al Copilot esistente input vocale con hotword/push-to-talk, trascrizione nella chat condivisa e sintesi configurabile, mantenendo i gate clinici.

**Spec:** `docs/superpowers/specs/2026-07-22-copilot-chairside-voice-design.md`

**Stato:** incluso nella Fase 1 generale del progetto; pianificato, non avviato

## Vincoli globali

- Nessun secondo agente o endpoint di business parallelo al Copilot.
- Nessun audio persistito per default.
- Hotword locale; fallback obbligatorio push-to-talk.
- Dettatura clinica: revisione trascrizione + successivo gate dell'azione.
- Policy server-side prevale sulle preferenze locali.
- Nessuna regressione per chat testuale, sessioni, SSE e contesto paziente.
- Il provider vocale resta dietro adapter; nessuna dipendenza vendor nei componenti.

## Sequenza e stima

| Blocco | Contenuto | Stima |
|---|---|---:|
| A | Refactoring conversazione Copilot condivisa | 2-3 giorni |
| B | Policy e impostazioni vocali | 2-3 giorni |
| C | Push-to-talk + STT + pannello globale | 3-4 giorni |
| D | Sintesi vocale e risposta breve | 2-3 giorni |
| E | Hotword locale | 3-5 giorni |
| F | Gate dettatura clinica, audit e hardening | 3-5 giorni |
| G | Pilota e calibrazione in poltrona | 3-5 giorni |

Totale MVP: **43-69 giornate-agente**, pari a **circa 4-5 settimane calendario con tre agenti dedicati**, includendo collaudo reale e margine d'integrazione.

## Allocazione sui tre agenti

| Blocco | Backend | Frontend | Test/QA | Parallelizzazione |
|---|---:|---:|---:|---|
| A — Conversazione condivisa | 1-2 gg | 2-3 gg | 1-2 gg | FE guida; QA prepara regressione chat |
| B — Policy e impostazioni | 2-3 gg | 2-3 gg | 1-2 gg | BE e FE in parallelo dopo il contratto DTO |
| C — Push-to-talk e STT | 1-2 gg | 3-4 gg | 2-3 gg | QA avvia E2E appena disponibile il vertical slice |
| D — TTS | 1-2 gg | 2-3 gg | 1-2 gg | parallelo allo spike hotword |
| E — Hotword locale | 1 gg | 3-5 gg | 2-4 gg | dipende dallo spike su hardware/browser |
| F — Gate clinici e hardening | 3-4 gg | 2-3 gg | 3-4 gg | richiede audit, autorizzazioni e chiusura #20 |
| G — Pilota controllato | 1-2 gg | 1-2 gg | 3-5 gg | QA guida; BE/FE correggono e calibrano |
| Margine integrazione/rischio | 1-2 gg | 2-3 gg | 2-3 gg | assorbito durante alpha, beta e pilota |
| **Totale per agente** | **11-18 gg** | **17-26 gg** | **15-25 gg** | **43-69 gg-agente complessivi** |

La durata calendario è governata soprattutto dal frontend/hotword e dal pilota. La stima presuppone tre agenti attivi in parallelo, disponibilità della postazione e del microfono target, decisione tempestiva sul provider STT/TTS e nessuna attesa DPO/contrattuale inclusa.

## Posizione nell'ordine generale della Fase 1

1. Completare audit append-only (#18) e autorizzazioni server-side (#24).
2. Chiudere #20 e stabilizzare il contratto delle azioni Copilot.
3. Realizzare A-B dietro feature flag, in parallelo alle restanti attività cliniche della Fase 1.
4. Realizzare C-E e validare lettura/navigazione solo con dati fittizi.
5. Realizzare F dopo finalizzazione/addendum e i gate clinici applicabili.
6. Eseguire G dopo DPIA/valutazione fornitore; abilitare al go-live solo con criteri verdi.

Il go-live generale non dipende obbligatoriamente dall'attivazione della voce: se il pilota non supera i gate, #39 resta installata ma disabilitata tramite policy, senza bloccare le altre funzioni della Fase 1.

---

## Blocco A — Conversazione Copilot condivisa

**Obiettivo:** pagina chat e pannello vocale usano un'unica sessione/stato.

**File principali:**

- nuovo `frontend/src/app/core/services/copilot-conversation.service.ts`
- modifica `frontend/src/app/features/segretaria/segretaria.component.ts`
- modifica `frontend/src/app/core/services/chat.service.ts`
- test del nuovo service

**Attività:**

- [ ] Estrarre da `SegretariaComponent` messaggi, sessione corrente, invio streaming e cancellazione.
- [ ] Esporre signals read-only e comandi `send`, `cancel`, `newChat`, `openSession`.
- [ ] Catturare un'istantanea di `ChatUiContext` all'inizio della richiesta.
- [ ] Impedire due invii concorrenti nella stessa conversazione.
- [ ] Aggiungere evento `assistantCompleted` distinto dai token intermedi.
- [ ] Migrare la pagina Copilot al servizio senza cambiamenti visivi/funzionali.

**Test:** sessione unica, ordinamento messaggi, cancellazione stream, errore SSE, contesto immutabile, nessuna doppia richiesta.

**Gate:** build frontend verde e suite manuale della chat testuale invariata.

---

## Blocco B — Policy studio e preferenze della postazione

**Obiettivo:** amministratore governa la feature; utente/postazione sceglie voce e modalità entro la policy.

**Backend:**

- nuova migration Flyway `V26__clinic_voice_settings.sql` (numero da verificare al momento dell'esecuzione);
- nuovi DTO `VoiceSettingsDto`, `UpdateVoiceSettingsRequest`, `VoiceCatalogDto`;
- nuovo `VoiceSettingsService`;
- estensione `ClinicSettingsController` o controller dedicato `/api/settings/voice`;
- test controller/service e isolamento tenant.

**Frontend:**

- nuovo `voice-settings.service.ts` e modelli;
- estensione backward-compatible di `AppSettings` e `DEFAULT_SETTINGS`;
- nuova sezione `Impostazioni → AI → Assistente vocale`;
- selettori separati per lingua input, lingua output e voce;
- pulsante `Prova voce` e stato capacità browser/provider.

**Attività:**

- [ ] Creare tabella per-clinic con default disabilitato.
- [ ] Autorizzare PUT solo ad admin/tenant admin; GET agli utenti Copilot.
- [ ] Implementare catalogo normalizzato di lingue/voci.
- [ ] Intersecare preferenze locali con policy a ogni bootstrap/login.
- [ ] Gestire voce salvata ma non più disponibile.
- [ ] Non confondere `locale` UI con locale STT/TTS.

**Test:** cross-tenant, ruolo non admin, default sicuri, migrazione preferenze vecchie, catalogo vuoto/fallback.

---

## Blocco C — Pannello globale e push-to-talk

**Obiettivo:** primo vertical slice utilizzabile senza hotword.

**Nuovi file frontend:**

- `core/voice/voice-orchestrator.service.ts`
- `core/voice/speech-recognition.adapter.ts`
- `core/voice/browser-speech-recognition.adapter.ts` (prototipo)
- `shared/copilot-voice-panel/copilot-voice-panel.component.ts/.html/.css`

**Modifiche:**

- `app.ts` / `app.html` per montare il pannello globale;
- `chat.service.ts` per metadati opzionali `inputMode` e `voice`;
- contratto `ChatRequest` backend con campi opzionali compatibili.

**Attività:**

- [ ] Implementare state machine, AbortController e cleanup su logout/destroy.
- [ ] Richiedere il permesso microfono solo da gesto esplicito.
- [ ] Acquisire una frase, mostrare testo e inviare come normale messaggio chat.
- [ ] Visualizzare il paziente catturato all'inizio dell'ascolto.
- [ ] Bloccare comandi clinici senza paziente corrente.
- [ ] Rendere microfono, stop, errori e fallback accessibili.

**Test:** permesso negato, nessun microfono, frase vuota, doppio click, cambio rotta/paziente, logout durante ascolto, errore rete.

**Gate:** una domanda pronunciata compare nella chat completa e nella cronologia dopo reload.

---

## Blocco D — Sintesi vocale

**Obiettivo:** toggle rapido e lettura configurabile della risposta finale.

**Nuovi file:**

- `core/voice/speech-synthesis.adapter.ts`
- `core/voice/browser-speech-synthesis.adapter.ts` (prototipo)

**Backend/contratto:**

- evento SSE `speech` con payload JSON;
- generazione `speechText` breve separata dalla risposta Markdown;
- validazione locale/modalità contro policy server-side.

**Attività:**

- [ ] Aggiungere toggle `Leggi le risposte` nel pannello.
- [ ] Sintetizzare solo dopo completamento, mai token per token.
- [ ] Implementare modalità `off`, `brief`, `full`.
- [ ] Interrompere TTS su stop, nuova hotword, logout o navigazione sensibile.
- [ ] Evitare fallback automatico al testo completo se manca `speech`.
- [ ] Gestire voce/lingua non disponibili.

**Test:** toggle immediato, persistenza locale, stop, evento mancante/malformato, risposta d'errore, testo sensibile con full vietato.

---

## Blocco E — Hotword “Ehi Giulia”

**Obiettivo:** attivazione hands-free locale, governata dalla policy.

**File:**

- `core/voice/wake-word.adapter.ts`
- implementazione locale scelta dopo spike tecnico;
- configurazione asset/modello wake word, senza audio verso il backend.

**Attività:**

- [ ] Eseguire spike comparativo su browser supportati e hardware poltrona.
- [ ] Selezionare motore locale e documentarne licenza/dimensione/CPU.
- [ ] Armare solo dopo opt-in esplicito e policy `wakeWordAllowed`.
- [ ] Mostrare indicatore persistente quando il rilevatore è armato.
- [ ] Disarmare su logout, tab nascosta secondo policy, errore o mute.
- [ ] Misurare false attivazioni con rumore di aspiratore/turbina e conversazioni.

**Gate:** nessun audio remoto prima della hotword; push-to-talk resta funzionante se il motore non è supportato.

---

## Blocco F — Dettatura clinica, audit e hardening

**Obiettivo:** applicare i due gate e rendere verificabile il canale voce.

**Attività:**

- [ ] Implementare classificatore conservativo frontend per ingresso in `REVIEW`.
- [ ] Aggiungere classificazione backend autoritativa per intent/azione.
- [ ] Mostrare editor della trascrizione con conferma/annulla.
- [ ] Conservare separatamente conferma trascrizione e conferma azione.
- [ ] Estendere audit con `input_mode`, locale e stato dei gate, senza duplicare PHI.
- [ ] Chiudere/verificare #20 prima di abilitare qualsiasi scrittura vocale.
- [ ] Aggiungere rate limit, timeout, limiti durata e protezione replay.
- [ ] Verificare che bozze annullate e audio non finiscano in log/storage.

**Test avversi:** frase ambigua, falsa hotword, paziente cambiato, sessione scaduta, ruolo insufficiente, conferma riferita a bozza precedente, retry dopo rete persa.

**Gate:** 100% delle dettature cliniche passa da `REVIEW`; 100% delle scritture mantiene il gate Copilot.

---

## Blocco G — Pilota controllato

**Obiettivo:** decidere il go/no-go su dati misurati nell'ambiente reale.

- [ ] Predisporre una sola postazione autorizzata e microfono direzionale.
- [ ] Eseguire DPIA/valutazione fornitore prima di pazienti reali.
- [ ] Collaudare prima con dati fittizi e rumori reali.
- [ ] Raccogliere solo metriche tecniche prive di contenuto.
- [ ] Verificare ≥95% successo sui comandi chiusi concordati.
- [ ] Verificare zero esecuzioni su paziente/tenant errato.
- [ ] Misurare latenza, false attivazioni, correzioni e annullamenti.
- [ ] Formalizzare rollback: `enabled=false` disattiva voce senza deploy.

## Ordine di rilascio

1. **Release tecnica:** A + B, nessuna voce attiva.
2. **Alpha interna:** C, solo push-to-talk e letture/navigazione.
3. **Beta controllata:** D + E, sintesi breve e hotword.
4. **Pilota clinico:** F + G, dopo gate compliance e #20.

## Verifica finale

- backend: test service/controller/security + `mvn test`;
- frontend: test unitari adapter/orchestrator/conversation + build produzione;
- E2E: stessa sessione voce/testo, reload cronologia, contesto paziente, toggle e policy;
- test manuale: Chrome/Edge target, microfono target, rumore reale;
- sicurezza: tenant/ruolo, log PHI, permessi microfono, cancellazione/timeout;
- documentazione: manuale utente, configurazione deploy, DPIA/runbook di disattivazione.
