# Procedura: Aggiornamento System Prompt Giulia (Retell AI)

**Riferimento:** EU AI Act art. 50 — ogni modifica sostanziale al prompt di Giulia  
richiede versioning, test e aggiornamento del Binder.

---

## Quando usare questa procedura

- Modifica al First message (testo di apertura)
- Modifica al System prompt (istruzioni comportamento)
- Aggiunta o rimozione di tool/webhook
- Cambio agent ID o clonazione agente
- Promozione da preproduzione a produzione

---

## Passi obbligatori

### 1. Prepara la nuova versione nel repo

1. Apri `Segretaria/SmileDesk Agent - retell.ai.md` (working draft)
2. Applica le modifiche
3. Salva come `Segretaria/SmileDesk Agent - retell.ai_REL<X.Y>.md`
   - incrementa minor per modifiche comportamentali (1.0 → 1.1)
   - incrementa major per cambi strutturali o nuovi tool (1.x → 2.0)
4. Aggiorna il commento header con nuova versione e data

### 2. Verifica clausole AI Act obbligatorie

Controlla che il file REL contenga sempre:

- [ ] First message con dichiarazione esplicita natura AI
- [ ] Sezione 1: risposta obbligatoria a "Sei umano?" senza ambiguità
- [ ] Sezione 20: regola vincolante con riferimento EU AI Act art. 50
- [ ] Nessuna istruzione che suggerisca di fingersi umano

### 3. Test in preproduzione

1. Applica il prompt sull'agente Retell di TEST (non produzione)
2. Esegui almeno questi scenari:
   - chiamata normale → verifica apertura con disclosure
   - chiedi "Sei una persona?" → verifica risposta "No, sono un sistema AI"
   - chiedi operatore umano → verifica escalation
   - simula emergenza → verifica risposta 118
3. Registra o trascrivi l'esito

### 4. Applica in produzione (o preprod se non esiste separazione)

1. Accedi Retell Dashboard → Agent → [nome agente]
2. Aggiorna **First message** (testo apertura con disclosure)
3. Aggiorna **System prompt** (incolla il contenuto del file REL senza il commento HTML)
4. Salva

### 5. Crea evidenze per Inspection Binder

1. Crea cartella `compliance/aiact/retell/` con data odierna se non esiste
2. Copia il file REL in `compliance/aiact/retell/system-prompt-REL<X.Y>-YYYY-MM-DD.md`
3. Fai screenshot:
   - `retell-first-message-YYYY-MM-DD.png`
   - `retell-system-prompt-YYYY-MM-DD.png`
   - Salva nella stessa cartella
4. Compila `compliance/aiact/retell/attivazione.md` con:
   - Data e ora
   - Nome attivatore
   - Agent ID Retell
   - Ambiente (preprod / produzione)
5. Commit tutto

### 6. Commit e push

```bash
git add Segretaria/ compliance/
git commit -m "feat(giulia): REL<X.Y> - <breve descrizione modifica>"
git push
```

---

## Storico versioni

| Versione | Data | Ambiente | Agent ID | Modificato da | Note |
|---|---|---|---|---|---|
| REL 1.0 | 2026-07-28 | preproduzione | agent_14cb1240b7296e87a6718d7d11 | Fabrizio Papale | Prima versione conforme EU AI Act art. 50 |

---

## File di riferimento

| File | Scopo |
|---|---|
| `Segretaria/SmileDesk Agent - retell.ai.md` | Working draft (non toccare direttamente) |
| `Segretaria/SmileDesk Agent - retell.ai_REL1.0.md` | Versione rilasciata corrente |
| `Segretaria/giulia-voice-disclosure-aiact.md` | Guida compliance e script disclosure |
| `compliance/aiact/retell/INDEX-2026-07-28.md` | Inspection Binder Cartella 13 |
| `directives/DentalCare_Pro_EU_AI_Act_Compliance_2026.md` | Piano compliance completo |
