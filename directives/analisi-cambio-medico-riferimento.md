# Analisi impatto — Cambio medico di riferimento (FIX #2)

Data: 2026-07-01. Origine: modifica `primary_provider_id` dalla Panoramica anagrafica
([paziente-detail.saveAnagrafica](../frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.ts) →
`PatientService.update`, campo `primary_provider_id`).

## Modello di visibilità (confermato)

In [PatientService](../backend/src/main/java/com/dentalcare/service/PatientService.java) sia
`findAll` sia `findById` applicano, quando `providerId != null` (ruolo dottore/igienista):

```
AND (pat.primary_provider_id = :providerId
     OR EXISTS (SELECT 1 FROM <schema>.appointments a
                WHERE a.patient_id = ... AND a.provider_id = :providerId
                  AND a.clinic_id = ...))
```

Quindi un dottore vede un paziente **solo se** ne è medico di riferimento **oppure** ha almeno
un appuntamento con lui. Segreteria/admin (`providerId = null`) vedono tutto.

## Impatti del cambio

1. **Self-lockout (rischio principale).** Se un dottore sposta il medico di riferimento su un
   collega e non ha appuntamenti con quel paziente, il paziente **sparisce** dalla sua lista e
   `findById` restituisce vuoto → in FE compare "Paziente non trovato o accesso non autorizzato".
   Il dato non è perso, solo non più visibile a quell'operatore.

2. **Concessione di accesso.** Impostare il riferimento su un provider concede a quel provider la
   visibilità del paziente e di tutta la cartella clinica collegata.

3. **Nessun riallineamento dei record esistenti.** Appuntamenti, preventivi, piani di cura,
   fatture e richiami mantengono il proprio `provider_id`: **non** vengono riassegnati. Cambia
   solo l'etichetta "medico di riferimento" e la visibilità di default. Storico e ownership
   restano sui provider originari.

4. **Richiami futuri.** Da verificare se la generazione richiami usa `primary_provider_id` come
   target: in tal caso i richiami futuri verrebbero attribuiti al nuovo medico (i già esistenti no).

5. **Audit.** Nessuna traccia di chi/quando ha cambiato il riferimento.

6. **Autorizzazione.** Il backend `update` non impone controlli di ruolo sul cambio di
   `primary_provider_id` (da verificare eventuale gate lato FE): oggi un dottore può riassegnare
   (e quindi togliersi) un paziente.

## Raccomandazioni

- **Conferma esplicita** in UI quando si cambia il medico di riferimento, con avviso "il paziente
  potrebbe non essere più visibile nella tua lista" se il nuovo provider ≠ operatore corrente.
- **Restringere il permesso**: consentire il cambio solo ad admin/segreteria (o al medico di
  riferimento corrente), non a qualsiasi dottore.
- **Nota informativa**: chiarire che appuntamenti/piani/preventivi esistenti non vengono
  riassegnati.
- **Audit opzionale**: log del cambio (vecchio→nuovo provider, operatore, timestamp).

## Verifiche ancora aperte

- Generazione richiami: usa `primary_provider_id`? (grep su servizio richiami)
- Esiste gate di ruolo sul bottone "Modifica anagrafica" in FE?
- Default provider per nuovo appuntamento: eredita da `primary_provider_id`?

## Proposta minima (se si vuole un fix, non solo analisi)

Solo FE, basso rischio: in `saveAnagrafica`, se `editForm.primaryProviderId` cambia rispetto a
`paziente.primaryProviderId` e il nuovo valore ≠ `userContext.providerId()`, mostrare `confirm()`
con l'avviso di perdita visibilità prima di salvare.
