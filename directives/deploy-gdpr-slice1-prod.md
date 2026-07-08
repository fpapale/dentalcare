# Deploy prod — GDPR Slice 1 (cifratura birth_date, #7)

Runbook operativo per portare in produzione la cifratura `birth_date`.
Prod: Docker su `192.168.0.72` (`~/docker/dentalcarepro`), profilo `prod`, DB
`dentalcare_prod` su `192.168.0.173`. Backend NON esposto sull'host: le API si
raggiungono via nginx frontend → `http://192.168.0.72:8181/api/...`.

**Stato prod al momento della stesura:** 1 solo tenant `t_9d754153` (23 pazienti,
22 con `birth_date`), colonna `birth_date_enc` ancora assente. Migrazione = 1 tenant.

Codice: master `ee47bbd` (Slice 1 + fix follow-up).

---

## Modello di rollout

Il build unico contiene sia dual-write sia cutover (legge da `birth_date_enc`,
età in Java). Quindi all'avvio:
- `EstimateSchemaInitializer` aggiunge `birth_date_enc` + `foreign_patient` e
  ricostruisce le viste (senza `birth_date`/`age_years`);
- i pazienti esistenti hanno `birth_date_enc = NULL` finché non gira la migrazione
  → **finestra**: tra avvio e migrazione le date/età dei pazienti risultano vuote.

Con 1 tenant piccolo la finestra è di secondi/minuti: eseguire i passi 4→5 in
sequenza. Preferibile finestra a basso traffico.

---

## Prerequisito CRITICO — master key prima del deploy

`ConfigMasterKeyProvider` fa **fail-fast**: senza `app.encryption.master-key`
valida (64 hex) il backend NON parte. Quindi la chiave va messa PRIMA del deploy,
altrimenti il container va in crash-loop.

```bash
# 1. Genera la master key di PRODUZIONE (diversa da dev). 64 hex.
openssl rand -hex 32
```

- Conservala in un secret store sicuro (per ora file gitignored; in futuro Vault).
- **Perdita chiave = birth_date_enc irrecuperabile.** Nessun recovery.
- NON committarla, NON riusarla da dev.

Sul server, in `~/docker/dentalcarepro/config/application-prod.properties`
(file reale, gitignored — creato da `.example` al primo install), impostare:

```properties
app.encryption.key-source=config
app.encryption.master-key=<64 hex generati sopra>
```

---

## Passi

### 1. Backup DB (obbligatorio)
```bash
PGPASSWORD=<pwd> pg_dump -h 192.168.0.173 -U postgres -d dentalcare_prod \
  -Fc -f ~/dentalcare_prod_pre_gdpr_$(date +%Y%m%d_%H%M).dump
```

### 2. Master key nel config montato
Vedi prerequisito sopra: `config/application-prod.properties` deve avere
`app.encryption.key-source=config` + `app.encryption.master-key=<hex>`.

### 3. Deploy applicativo (pull master + rebuild, NIENTE ricreazione DB)
```bash
cd ~/docker/dentalcarepro
./setup.sh --update
```
`--update` = solo `git pull origin master` + `docker compose up -d --build`.
NON tocca il DB (nessun `install.sql`, nessun DROP). Attende l'healthcheck backend.

All'avvio, verificare nei log che il patch schema sia passato:
```bash
docker logs dentalcarepro-backend 2>&1 | grep -iE "patched schema|schema OK"
# atteso: "patched schema t_9d754153" + "schema OK"
```

### 4. Migrazione (cifra birth_date + fiscal_code esistenti) — subito dopo l'avvio
Nota: da Slice 2a l'endpoint `/migrate` cifra sia `birth_date` sia `fiscal_code`
(pazienti) + lo snapshot `patient_fiscal_code` delle fatture. Idempotente cumulativo.
```bash
# Login demo (unico tenant): ottieni il JWT
TOKEN=$(curl -s -X POST http://192.168.0.72:8181/api/public/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@demo.dentalcare.it","password":"DemoAdmin1!"}' \
  | grep -o '"token":"[^"]*"' | head -1 | sed 's/"token":"//;s/"//')

# Migrazione idempotente (popola *_enc/_idx, plaintext intatto)
curl -s -X POST http://192.168.0.72:8181/api/admin/encryption/migrate \
  -H "Authorization: Bearer $TOKEN"
# atteso (primo run): {"birthDate":22,"fiscalCode":22}

# Re-run per conferma idempotenza
curl -s -X POST http://192.168.0.72:8181/api/admin/encryption/migrate \
  -H "Authorization: Bearer $TOKEN"
# atteso: {"birthDate":0,"fiscalCode":0}
```

### 5. Verifica
```bash
PSQL="PGPASSWORD=<pwd> psql -h 192.168.0.173 -U postgres -d dentalcare_prod -At"
# pending birth_date (deve essere 0)
$PSQL -c "select count(*) from t_9d754153.patients where birth_date is not null and birth_date_enc is null;"
# pending fiscal_code (deve essere 0)
$PSQL -c "select count(*) from t_9d754153.patients where fiscal_code is not null and fiscal_code_enc is null;"
# enc popolati (birth_date_enc, fiscal_code_enc/idx)
$PSQL -c "select count(birth_date_enc)||'/'||count(fiscal_code_enc)||'/'||count(fiscal_code_idx) from t_9d754153.patients;"
```
Poi in app: aprire un paziente → `birthDate`, età e `fiscalCode` corretti; ricerca per
CF esatto trova il paziente (parziale no: match esatto via blind index); dettaglio
fattura → `patientFiscalCode` corretto.

---

## Rollback

Il deploy NON cancella il plaintext `birth_date` (resta in colonna fino a un
futuro DROP in Slice 2). Se qualcosa va storto:
```bash
cd ~/docker/dentalcarepro
git checkout <commit-precedente-a-ee47bbd>   # es. ceabc6d
./setup.sh --update
```
Il codice precedente legge `birth_date` plaintext (ancora presente) → nessuna
perdita dati. `birth_date_enc` resta popolato ma inutilizzato.

## Note
- La colonna plaintext `birth_date` NON va droppata ora: serve al rollback e viene
  rimossa solo in Slice 2 dopo verifica prod prolungata.
- Se in futuro prod avrà più tenant, la migrazione va ripetuta per ciascuno con il
  JWT admin del rispettivo tenant (endpoint tenant-scoped). Valutare a quel punto
  un endpoint platform-admin "migrate-all".
