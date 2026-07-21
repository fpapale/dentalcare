# Modello probatorio per un audit trail clinico

> **Questo è lo stato-obiettivo completo (stella polare).** Per il taglio operativo *cosa entra nel Gate 1 (MVP) vs cosa è differito*, vedi [`audit-trail-tier1-mvp.md`](audit-trail-tier1-mvp.md). Preso alla lettera per il go-live, questo modello tira dentro terze parti (QTSP eIDAS) fuori dai tempi della Fase 1: il companion isola il minimo legale.

Un **modello probatorio per un audit trail clinico** non consiste semplicemente nel “salvare i log”. È un insieme coordinato di:

- registrazioni tecniche;
- identificazione certa degli operatori;
- versionamento dei dati clinici;
- garanzie di integrità e data certa;
- procedure organizzative;
- modalità controllate di estrazione della prova.

L’obiettivo è poter dimostrare, anche anni dopo:

> **chi ha fatto cosa, quando, su quale paziente, con quale autorizzazione, per quale finalità e senza che le registrazioni siano state alterate.**

Per DentalCare lo imposterei nel modo seguente.

## 1. Definire gli eventi che producono prova

Il sistema deve registrare automaticamente almeno:

| Categoria | Eventi |
|---|---|
| Autenticazione | login, logout, MFA, login fallito, sessione scaduta |
| Consultazione | apertura paziente, anamnesi, odontogramma, radiografia, referto |
| Modifica clinica | creazione, correzione, integrazione, firma, annullamento |
| Documenti | caricamento, download, stampa, esportazione, condivisione |
| Consensi | acquisizione, modifica, revoca, oscuramento |
| Autorizzazioni | ruolo assegnato, delega, modifica dei permessi |
| Emergenza | accesso “break glass”, motivazione e successiva verifica |
| Amministrazione | accessi degli amministratori, backup, restore, esportazioni massive |
| Intelligenza artificiale | elaborazione AI, modello utilizzato, risultato, validazione del medico |

La consultazione deve essere registrata, non soltanto creazione, modifica e cancellazione. Il Garante ha ribadito nel 2026 che i sistemi sanitari devono tracciare automaticamente accessi e operazioni, compresa la consultazione, e prevedere alert per comportamenti anomali.

Riferimento: [Garante per la protezione dei dati personali – provvedimento Doc-Web 10262049](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10262049)

## 2. Stabilire il contenuto minimo di ogni evento

Un evento probatorio dovrebbe contenere almeno:

```json
{
  "event_id": "019b4e5d-...",
  "event_type": "CLINICAL_RECORD_UPDATE",
  "occurred_at_utc": "2026-07-21T07:43:18.432Z",
  "recorded_at_utc": "2026-07-21T07:43:18.447Z",

  "tenant_id": "studio-roma-01",

  "actor": {
    "user_id": "usr-2841",
    "professional_id": "dentist-391",
    "role": "DENTIST",
    "authentication_level": "MFA",
    "session_id": "sess-...",
    "device_id": "workstation-03",
    "ip_address": "10.0.0.45"
  },

  "patient": {
    "patient_reference": "pat-pseudo-91af2"
  },

  "clinical_context": {
    "encounter_id": "enc-55219",
    "appointment_id": "app-23110",
    "care_relationship": "ASSIGNED_DENTIST"
  },

  "resource": {
    "type": "ODONTOGRAM",
    "resource_id": "odo-9211",
    "version_before": 7,
    "version_after": 8
  },

  "operation": {
    "action": "UPDATE",
    "purpose": "PATIENT_CARE",
    "result": "SUCCESS",
    "reason": "Aggiornamento diagnosi elemento 46"
  },

  "authorization": {
    "decision": "PERMIT",
    "policy_id": "clinical-access-policy",
    "policy_version": "3.2"
  },

  "integrity": {
    "before_hash": "sha256:...",
    "after_hash": "sha256:...",
    "previous_event_hash": "sha256:...",
    "event_hash": "sha256:..."
  },

  "correlation_id": "trace-...",
  "application_version": "dentalcare-2.4.1"
}
```

Il Garante richiede almeno identificativo dell’operatore, data e ora, postazione utilizzata, paziente interessato e tipo di operazione.

Riferimento: [Garante per la protezione dei dati personali – provvedimento Doc-Web 10262049](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10262049)

ISO 27789:2021 indica come nucleo minimo l’identificazione univoca dell’utente e del paziente, la funzione eseguita e il relativo momento temporale. Raccomanda inoltre di utilizzare riferimenti alle informazioni cliniche, evitando di duplicare inutilmente nel log l’intero contenuto sanitario.

Riferimento: [ISO 27789:2021 – Health informatics — Audit trails for electronic health records](https://www.iso.org/standard/75313.html)

### Regola importante

Nel log non salverei frasi come:

> “Il paziente ha una lesione periapicale…”

Salverei invece:

- identificativo del documento;
- versione;
- hash della versione;
- tipo di modifica;
- eventuale codice del campo modificato.

Il contenuto clinico completo resta nel repository clinico versionato.

## 3. Rendere immodificabile la storia clinica

Una cartella clinica non dovrebbe mai funzionare con una semplice operazione SQL:

```sql
UPDATE clinical_record ...
```

che sovrascrive definitivamente il valore precedente.

Occorre adottare il **versionamento append-only**:

```text
Versione 1 → Versione 2 → Versione 3 → Versione 4
```

Ogni correzione deve:

1. conservare la versione precedente;
2. creare una nuova versione;
3. indicare autore, data e motivo;
4. collegare la nuova versione alla precedente;
5. produrre un evento di audit;
6. ricalcolare l’hash del documento.

La cancellazione clinica dovrebbe normalmente diventare un’operazione di:

- annullamento logico;
- revoca;
- rettifica;
- oscuramento;
- nuova versione sostitutiva.

Non una cancellazione fisica invisibile.

## 4. Proteggere crittograficamente gli eventi

### Catena di hash

Ogni evento contiene l’hash dell’evento precedente:

```text
Evento 1 → hash A
Evento 2 contiene hash A → hash B
Evento 3 contiene hash B → hash C
```

L’hash deve essere calcolato su una rappresentazione canonica dell’evento, ad esempio JSON Canonicalization Scheme, utilizzando un algoritmo attuale come SHA-256 o superiore.

Se qualcuno modifica o elimina un evento storico, la catena non risulta più verificabile.

### Archiviazione separata

Gli eventi dovrebbero essere inviati a un sistema distinto dal database applicativo:

```text
DentalCare
    │
    ├── Database clinico versionato
    │
    └── Transactional outbox
             │
             ▼
       Audit Evidence Service
             │
             ├── archivio append-only
             ├── object storage con retention lock
             ├── SIEM e alert
             └── servizio di sigillo e timestamp
```

Raccomandazioni:

- nessun comando `UPDATE` o `DELETE` sui log;
- account applicativo autorizzato soltanto all’inserimento;
- amministratori tecnici separati dagli auditor;
- copie in almeno due domini di sicurezza;
- object lock/WORM;
- backup cifrati;
- verifica periodica degli hash.

Per gli amministratori di sistema, il Garante richiede access log completi, inalterabili e verificabili, comprensivi di riferimenti temporali e descrizione dell’evento.

Riferimento: [Garante per la protezione dei dati personali – amministratori di sistema, Doc-Web 1577499](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/1577499)

## 5. Attribuire realmente l’azione a una persona

Scrivere nel log `user_id = 123` non è sufficiente.

Il sistema deve poter dimostrare che quell’utenza apparteneva effettivamente a quella persona nel momento dell’azione. Occorre quindi conservare:

- identità anagrafica e professionale associata all’account;
- ruolo ricoperto in quel momento;
- studio o organizzazione di appartenenza;
- periodo di validità dell’account;
- metodo di autenticazione;
- esito MFA;
- identificativo della sessione;
- deleghe attive;
- relazione di cura con il paziente;
- policy autorizzativa applicata.

Gli identificativi degli utenti non devono essere riutilizzati dopo la disattivazione.

### Separazione dei ruoli DentalCare

Nel modello DentalCare:

- la segretaria può vedere dati anagrafici e appuntamenti;
- il medico accede ai dati clinici dei pazienti assegnati;
- il manutentore del tenant non dovrebbe vedere automaticamente i dati clinici;
- l’amministratore tecnico deve operare con account nominativo privilegiato e attività tracciate.

Il log deve registrare non solo il ruolo, ma anche **perché la policy ha consentito l’accesso**:

```json
{
  "decision": "PERMIT",
  "rule": "doctor_assigned_to_patient",
  "appointment_id": "app-23110"
}
```

## 6. Rendere opponibili data e integrità

Il solo orologio del server non fornisce la massima forza probatoria.

Suggerisco due livelli.

### Livello operativo

- tutti i sistemi sincronizzati con fonti temporali affidabili;
- registrazione UTC con millisecondi;
- controllo e alert sullo scostamento dell’orologio;
- memorizzazione sia dell’ora dell’evento sia dell’ora di acquisizione;
- conservazione delle configurazioni e degli eventi di sincronizzazione.

### Livello probatorio forte

A intervalli regolari, per esempio ogni ora o ogni giorno:

1. si calcola l’hash di tutti gli eventi del periodo;
2. si produce una radice Merkle o un manifest;
3. il manifest viene sigillato elettronicamente dall’organizzazione;
4. viene applicata una validazione temporale qualificata;
5. il pacchetto viene trasferito in conservazione.

Una validazione temporale elettronica qualificata gode della presunzione di accuratezza della data e dell’ora e di integrità dei dati associati.

Un sigillo elettronico qualificato beneficia invece della presunzione di integrità e correttezza dell’origine dei dati.

Riferimenti:

- [Regolamento eIDAS – testo consolidato](https://eur-lex.europa.eu/legal-content/en/TXT/?uri=CELEX%3A02014R0910-20241018)
- [Regolamento (UE) n. 910/2014](https://eur-lex.europa.eu/eli/reg/2014/910/oj/eng)

Questo è molto più utile, sul piano probatorio, del limitarsi a scrivere una data nel database.

## 7. Creare il “pacchetto di prova”

Quando si verifica un reclamo, un contenzioso o un’ispezione, non si dovrebbe esportare una schermata o un CSV isolato.

Occorre generare un **Evidence Package** contenente:

```text
EVIDENCE-2026-000184/
│
├── manifest.json
├── manifest.pdf
├── audit-events.jsonl
├── audit-events.csv
├── clinical-document-v7.pdf
├── clinical-document-v8.pdf
├── authorization-policy-v3.2.json
├── user-role-history.json
├── hash-verification-report.pdf
├── qualified-seal.p7s
├── qualified-timestamp.tsr
├── chain-of-custody.json
└── verification-instructions.txt
```

Il `manifest.json` dovrebbe indicare:

- motivo dell’estrazione;
- perimetro temporale;
- paziente e documenti interessati;
- query utilizzata;
- operatore che ha richiesto l’estrazione;
- operatore che l’ha eseguita;
- data e ora;
- versione del software di estrazione;
- hash di ogni file;
- sigillo e validazione temporale del pacchetto;
- eventuali esclusioni o anomalie.

ISO/IEC 27037 tratta identificazione, raccolta, acquisizione e preservazione delle evidenze digitali potenzialmente utilizzabili come prova.

Riferimento: [ISO/IEC 27037:2012](https://www.iso.org/standard/44381.html)

## 8. Mantenere la catena di custodia

Ogni trasferimento della prova deve essere registrato:

| Data e ora | Operatore | Operazione | Motivo | Hash prima/dopo |
|---|---|---|---|---|
| 21/07/2026 10:04 | Privacy Officer | Creazione pacchetto | Reclamo paziente | verificato |
| 21/07/2026 10:10 | DPO | Presa in carico | Valutazione | invariato |
| 22/07/2026 09:15 | Legale | Copia acquisita | Contenzioso | invariato |

Nessuno dovrebbe poter esportare una prova senza:

- ticket o pratica associata;
- motivazione;
- autorizzazione;
- logging dell’esportazione;
- verifica dell’integrità;
- eventuale doppia approvazione per esportazioni massive.

## 9. Prevedere audit e alert automatici

Il sistema dovrebbe rilevare almeno:

- accessi a molti pazienti in poco tempo;
- accessi notturni o fuori turno;
- pazienti senza appuntamento o relazione di cura;
- accessi a persone note o colleghi;
- esportazioni massive;
- ripetuti accessi negati;
- uso frequente del “break glass”;
- consultazioni da postazioni insolite;
- amministratori che accedono direttamente al database;
- modifiche cliniche effettuate molto tempo dopo la visita;
- firme apposte dopo modifiche non validate.

Il Garante ha espressamente richiamato l’esigenza di alert relativi al numero, alla tipologia e all’ambito temporale degli accessi.

Riferimento: [Garante per la protezione dei dati personali – provvedimento Doc-Web 10262049](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10262049)

## 10. Conservazione dei log

Non esiste un unico termine valido per tutti i log.

Per i dossier sanitari, il Garante indica un periodo non inferiore a **24 mesi** per i log degli accessi e delle operazioni.

Per gli accessi degli amministratori di sistema il minimo indicato dal relativo provvedimento è invece di **sei mesi**.

Riferimenti:

- [Garante per la protezione dei dati personali – provvedimento Doc-Web 10262049](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10262049)
- [Garante per la protezione dei dati personali – amministratori di sistema, Doc-Web 1577499](https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/1577499)

Per un vero modello probatorio DentalCare, tuttavia, distinguerei:

| Tipo | Politica consigliata |
|---|---|
| Log tecnici generici | periodo definito dalla sicurezza e dal GDPR |
| Log di accesso al dossier | almeno il minimo previsto dal Garante |
| Eventi relativi a modifiche cliniche | collegati alla durata della documentazione clinica |
| Manifest firmati e timestampati | conservati con il documento cui si riferiscono |
| Log AI clinicamente rilevanti | conservati con il risultato clinico validato |

La durata definitiva deve essere formalizzata in una retention policy approvata da titolare, DPO e consulente legale, evitando sia cancellazioni premature sia conservazioni indiscriminate.

## 11. Estensione per l’intelligenza artificiale

Per ogni risultato AI clinicamente rilevante registrerei:

```json
{
  "event_type": "AI_CLINICAL_INFERENCE",
  "model": {
    "name": "dentex_disease_v1",
    "version": "1.0.0",
    "onnx_hash": "sha256:..."
  },
  "input": {
    "image_id": "img-...",
    "image_hash": "sha256:..."
  },
  "output": {
    "result_id": "ai-result-...",
    "result_hash": "sha256:...",
    "confidence": 0.87
  },
  "human_review": {
    "status": "CONFIRMED_WITH_CHANGES",
    "reviewer_id": "dentist-391",
    "reviewed_at": "2026-07-21T08:02:10Z"
  }
}
```

La diagnosi definitiva dovrebbe essere una nuova evidenza distinta dal risultato AI, attribuita e firmata dal professionista.

In questo modo è possibile dimostrare:

- cosa ha prodotto il modello;
- con quale versione;
- su quale immagine;
- cosa ha modificato o confermato il dentista;
- quale risultato è entrato effettivamente nella cartella.

## 12. Il modello documentale da predisporre

Il modello probatorio dovrebbe essere formalizzato in almeno questi documenti:

1. **Politica di audit trail clinico**.
2. **Catalogo degli eventi tracciati**.
3. **Schema dati dell’audit event**.
4. **Matrice ruoli, autorizzazioni e finalità**.
5. **Procedura di sigillatura e validazione temporale**.
6. **Procedura di estrazione del pacchetto probatorio**.
7. **Procedura di catena di custodia**.
8. **Piano di conservazione e cancellazione**.
9. **Piano di controllo periodico e gestione degli alert**.
10. **Registro delle verifiche di integrità**.

Il CAD attribuisce particolare rilevanza probatoria a identificazione dell’autore, sicurezza, integrità e immodificabilità del documento informatico; negli altri casi il valore viene valutato in giudizio proprio sulla base di tali caratteristiche.

Riferimento: [Codice dell’Amministrazione Digitale – D.Lgs. 82/2005, art. 20](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:2005-03-07;82~art20=)

## Sintesi architetturale

Per DentalCare adotterei questo principio:

> **Database clinico versionato + audit log append-only + hash chain + manifest periodici sigillati e timestampati + procedura documentata di estrazione e verifica.**

La blockchain non è necessaria: un’architettura WORM, hash concatenati, sigillo elettronico qualificato, validazione temporale qualificata e conservazione correttamente governata è normalmente più semplice, controllabile e difendibile.
