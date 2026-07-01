# Manuale di installazione — Produzione (Docker)

Guida operativa per portare in produzione (server locale `192.168.0.72` **o** un host cloud) i tre servizi DentalCare:

1. **DentalCare Pro** — backend Spring Boot + frontend nginx (una sola immagine ciascuno)
2. **MinIO** — object storage (documenti pazienti, ortopanoramiche, artefatti AI)
3. **dentalcare-ai-service** — microservizio Python/FastAPI (inferenza YOLO ONNX)

> Documento da consultare e **aggiornare** a ogni modifica dell'infrastruttura. Ultimo aggiornamento: 2026-07-01.

---

## 0. Architettura e stato dei servizi

```
Host Docker (192.168.0.72 o cloud)
├── dentalcarepro-backend     (Spring Boot, profilo prod, NON esposto)      :8080 interno
├── dentalcarepro-frontend    (nginx, serve SPA + proxy /api → backend)     :8181 → 4200
├── dentalcare-ai-service     (FastAPI + ONNX YOLO, NON esposto)            :8000 interno
└── minio                     (object storage, esterno al compose)          :9000 API / :9001 console

DB PostgreSQL: 192.168.0.173:5432  (dev: dentalcarepro · prod: dentalcare_prod)
```

- **backend**, **frontend**, **ai-service** stanno nello **stesso `docker-compose.yml`** (rete `dentalcarepro`, si parlano per nome container).
- **MinIO è esterno al compose**: gira come container a sé (volume persistente). I servizi lo raggiungono via `host.docker.internal:9000` (`extra_hosts: host-gateway` già nel compose).
- **Servizi già installati**: su `192.168.0.72` MinIO e `dentalcare-ai-service` sono già attivi. La procedura è **idempotente**: si può installare tutto da zero oppure aggiornare solo alcuni servizi (vedi §7).

---

## 1. Prerequisiti

Sull'host di destinazione:
- **Docker** + **Docker Compose v2** (`docker compose`)
- **git**
- accesso di rete al **DB PostgreSQL** (`192.168.0.173:5432` o l'istanza cloud)
- `psql` (solo se si crea/ricrea il DB dal server)
- porte libere: **8181** (frontend), **9000/9001** (MinIO, se installato qui)

> **Cloud:** DB e MinIO possono stare su host diversi. In tal caso sostituire gli endpoint nei file di config (§4) — non serve `host.docker.internal` se MinIO ha un hostname/IP raggiungibile.

---

## 2. Da dove si scaricano i file di installazione

I file provengono dal repository (come per DentalCare Pro). Due modalità:

**A. Bootstrap da git (metodo standard, come DentalCare Pro):**
```bash
curl -fsSL https://raw.githubusercontent.com/fpapale/dentalcare/master/setup.sh -o /tmp/setup.sh
bash /tmp/setup.sh
```
`setup.sh` prepara `~/docker/dentalcarepro`, fa `git clone`/`git pull` e lancia `install.sh`.

**B. Da `192.168.0.72` (mirror locale):** se il cloud non ha accesso a GitHub, si copia il repo dal server esistente:
```bash
# sul cloud
rsync -az fpapale@192.168.0.72:~/docker/dentalcarepro/ ~/docker/dentalcarepro/
# oppure git pull da un remote interno su 192.168.0.72
```

> ⚠️ **La versione corrente è su `master` locale, avanti rispetto a `origin`.** Prima di deployarla via git bisogna **pushare** `master` (dopo aver eliminato `backup/ai-yolo-prepurge` e verificato la history). In alternativa usare il metodo B (copia diretta da `192.168.0.72`).

I file **con segreti** (`backend/config/`, `dentalcare-ai-service/.env`, `credentials/`) e i **modelli ONNX** sono **gitignored** → non arrivano col clone: vanno copiati/creati a mano sul server (§4, §6).

---

## 3. Struttura cartelle di deploy

```
~/docker/dentalcarepro/                      ← repo clonato
├── docker-compose.yml                        (3 servizi app)
├── .env                                       FRONTEND_PORT, VERSION, JDK_VERSION
├── setup.sh / install.sh                      bootstrap + deploy backend/frontend/ai
├── config/                                    (opz.) config prod montata su backend
│   └── application-prod.properties            ← DA CREARE (segreti reali, gitignored)
├── backend/config/                            config Spring montata (alternativa a ./config)
│   ├── application-prod.properties            ← DA CREARE/EDITARE
│   └── application.properties
├── credentials/credential.properties          ← DA CREARE (app.jwt.secret, DB pw, openai)
├── dentalcare-ai-service/
│   ├── .env                                    ← DA CREARE da .env.example
│   ├── models/
│   │   ├── dentex_fdi_v1.onnx                  ← DA COPIARE (non in git)
│   │   └── dentex_disease_v1.onnx              ← DA COPIARE (non in git)
│   └── tmp/
└── database/install.sql                        installer DB parametrico
```

---

## 4. Configurazione produzione (dove editare i parametri)

Tutti i parametri prod si modificano in **pochi file gitignored**. Nessun segreto nel repo.

### 4.1 Backend — `config/application-prod.properties` (root, montato `./config:/app/config:ro`)
> Deploy Docker prod: la config sta in **`config/`** alla radice del repo (montata dal compose). `install.sh` la crea da `config/application-prod.properties.example` se assente. (`backend/config/` serve solo all'avvio **locale** con `mvnw`.)

Override reali (il committato `src/main/resources/application-prod.properties` ha solo default/placeholder):
```properties
# DB
spring.datasource.url=jdbc:postgresql://192.168.0.173:5432/dentalcare_prod
spring.datasource.username=postgres
# password -> credentials/credential.properties

# MinIO (dall'interno del container backend)
app.minio.endpoint=http://host.docker.internal:9000
app.minio.access-key=<MINIO_USER>
app.minio.secret-key=<MINIO_PASSWORD>
app.minio.bucket-prefix=dc-

# AI inference service (rete Docker interna → nome container)
app.ai.base-url=http://dentalcare-ai-service:8000
app.ai.hmac-secret=<HMAC_SECRET>          # DEVE combaciare con AI_CALLBACK_SECRET dell'ai-service
```

### 4.2 Segreti backend — `credentials/credential.properties` (gitignored)
```properties
spring.datasource.password=<DB_PASSWORD>
app.jwt.secret=<JWT_SECRET>               # DEVE combaciare con JWT_SECRET dell'ai-service
spring.ai.openai.api-key=<OPENAI_KEY>     # per la Segreteria AI (chat)
```

### 4.3 AI service — `dentalcare-ai-service/.env` (gitignored, `env_file` del compose)
Creare da `.env.example` e impostare:
```
JWT_SECRET=<JWT_SECRET>                    # = app.jwt.secret del backend
MINIO_ENDPOINT=host.docker.internal:9000  # MinIO sull'host
MINIO_ACCESS_KEY=<MINIO_USER>
MINIO_SECRET_KEY=<MINIO_PASSWORD>
MINIO_SECURE=false
FDI_MODEL_PATH=/app/models/dentex_fdi_v1.onnx
DISEASE_MODEL_PATH=/app/models/dentex_disease_v1.onnx
FDI_INPUT_SIZE=1024
DISEASE_INPUT_SIZE=1024
MODEL_INPUT_SCALE=255                      # 1 se i modelli bakano /255 nel grafo ONNX
AI_CALLBACK_URL=http://dentalcarepro-backend:8080/api/internal/ai/callback
AI_CALLBACK_SECRET=<HMAC_SECRET>          # = app.ai.hmac-secret del backend
CALLBACK_RETRIES=3
```

### 4.4 Compose — `.env` (root, non segreto)
```
FRONTEND_PORT=8181
VERSION=1.0.0
JDK_VERSION=25        # o 21 se l'host non ha JDK 25 disponibile per la build
```

### 4.5 Tabella segreti condivisi (DEVONO combaciare)
| Valore | Backend | AI service |
|--------|---------|------------|
| JWT firma | `app.jwt.secret` (credentials) | `JWT_SECRET` (.env) |
| HMAC callback | `app.ai.hmac-secret` (config) | `AI_CALLBACK_SECRET` (.env) |
| URL AI (backend→ai) | `app.ai.base-url = http://dentalcare-ai-service:8000` | — |
| URL callback (ai→backend) | — | `AI_CALLBACK_URL = http://dentalcarepro-backend:8080/...` |
| MinIO | `app.minio.*` | `MINIO_*` |

> Genera i segreti nuovi con `openssl rand -base64 48` (HMAC) e una stringa robusta per il JWT. **Stesso valore sui due lati**, altrimenti token/callback vengono rifiutati.

---

## 5. MinIO

### 5.1 Se già installato (caso 192.168.0.72)
Non reinstallare. Verificare solo:
- è raggiungibile su `:9000` dall'host Docker;
- le credenziali in §4 combaciano con quelle del MinIO esistente;
- il **prefisso bucket** `dc-` è libero (i bucket per-tenant `dc-<schema>` vengono creati **applicativamente** dal backend alla creazione del tenant e all'upload — nessun bucket da creare a mano).

### 5.2 Installazione da zero (host senza MinIO, es. cloud)
```bash
docker run -d --name minio --restart unless-stopped \
  -p 127.0.0.1:9000:9000 -p 127.0.0.1:9001:9001 \
  -e MINIO_ROOT_USER=<MINIO_USER> \
  -e MINIO_ROOT_PASSWORD=<MINIO_PASSWORD> \
  -v minio_data:/data \
  minio/minio:latest server /data --console-address ":9001"
```
- Esporre solo su `127.0.0.1` (non pubblico). Console via **tunnel SSH**: `ssh -L 9001:127.0.0.1:9001 -L 9000:127.0.0.1:9000 <user>@<host>`.
- I bucket documenti (`dentalcare-docs` per il modulo #4/#5) e i bucket per-tenant `dc-<schema>` sono gestiti dall'applicazione.

---

## 6. dentalcare-ai-service

### 6.1 Modelli ONNX (obbligatori, non in git — copia automatica)
I due modelli servono in `dentalcare-ai-service/models/`:
```
dentex_fdi_v1.onnx        (denti FDI, 32 classi)
dentex_disease_v1.onnx    (patologie, 4 classi)
```
**`install.sh` li copia automaticamente** se assenti, dalla sorgente `MODELS_SRC`
(default `fpapale@192.168.0.72:~/docker/dentalcarepro/dentalcare-ai-service/models`).
Su `192.168.0.72` sono già presenti → lo step viene saltato. Su un host cloud la
copia richiede accesso SSH a `192.168.0.72`; override della sorgente:
```bash
MODELS_SRC=user@altro-host:/path/models ./install.sh
```
Se la copia automatica fallisce, copiarli a mano (l'AI resta `loaded:false` finché mancano).
Se i modelli sono `.pt` (PyTorch/Ultralytics) vanno convertiti in ONNX prima:
```python
from ultralytics import YOLO
YOLO('modello.pt').export(format='onnx', imgsz=1024, simplify=True)
```
Verificare che `MODEL_INPUT_SCALE` nel `.env` sia coerente (255 = input 0-1 standard; 1 = normalizzazione `/255` bakata nel grafo).

### 6.2 Se già installato (caso 192.168.0.72)
La build fa parte del compose. Per **non** ricostruirlo durante un deploy del solo backend/frontend, usare il deploy selettivo (§7.2).

---

## 7. Procedura di deploy

### 7.1 Installazione completa (fresh / tutti i servizi)
```bash
# 1. bootstrap (scarica repo)
curl -fsSL https://raw.githubusercontent.com/fpapale/dentalcare/master/setup.sh -o /tmp/setup.sh
bash /tmp/setup.sh
#   → clona in ~/docker/dentalcarepro, poi install.sh chiede se creare il DB

# 2. PRIMA di far salire i container: creare i file di config (§4) e copiare i modelli (§6.1)
cd ~/docker/dentalcarepro
#   - backend/config/application-prod.properties
#   - credentials/credential.properties
#   - dentalcare-ai-service/.env
#   - dentalcare-ai-service/models/*.onnx
#   - .env (root)

# 3. MinIO: installare se assente (§5.2) o verificare se presente (§5.1)

# 4. build + up di tutti e 3 i servizi app
docker compose up -d --build

# 5. (opz.) creare/ricreare il DB prod
psql -U postgres -h 192.168.0.173 -d postgres -v dbname=dentalcare_prod -f database/install.sql
```
`install.sh` (via `setup.sh`) automatizza i passi: verifica tool, clone/pull, crea config da `.example` se assenti, chiede se creare il DB, `docker compose up -d --build`, attende l'healthcheck del backend, stampa l'URL.

### 7.2 Servizi già installati → deploy selettivo (idempotente)
```bash
cd ~/docker/dentalcarepro

# aggiorna solo backend + frontend, NON ricostruisce ai-service né tocca MinIO
docker compose up -d --build backend frontend

# aggiorna solo l'ai-service (es. nuovi modelli / .env)
docker compose up -d --build dentalcare-ai-service

# MinIO è esterno al compose: non viene mai toccato da 'docker compose'
```

### 7.3 Aggiornamento applicativo (nuova versione del codice)
```bash
cd ~/docker/dentalcarepro
./setup.sh --update      # git pull + rebuild app (salta config e DB)
# oppure selettivo:
git pull origin master && docker compose up -d --build backend frontend
```

---

## 8. Verifica / smoke test

```bash
# container su
docker compose ps

# backend healthy (dall'host)
curl -s http://127.0.0.1:8080/api/public/demo-config     # se esposto in debug; in prod il backend NON è esposto
# frontend
curl -sI http://127.0.0.1:8181/                          # 200

# ai-service health (dentro la rete o esponendo temporaneamente :8000)
docker exec dentalcare-ai-service python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health').read())"

# MinIO
curl -sI http://127.0.0.1:9000/minio/health/live         # 200
```
Test funzionale AI (dal browser): login → paziente → Documenti → carica `rx_panoramica` → **Analizza con AI** → overlay box + sync odontogramma.

App: `http://<host>:8181/` — login demo `admin@demo.dentalcare.it` / `DemoAdmin1!` (cambiare in prod reale).

---

## 9. Note operative e sicurezza

- **Backend e ai-service NON esposti** sull'host: raggiungibili solo via rete Docker interna / proxy frontend. Solo `frontend:8181` e (se locale) `minio:9000/9001` su `127.0.0.1`.
- **Nessun segreto nel repo**: `backend/config/`, `credentials/`, `dentalcare-ai-service/.env`, `*.onnx`, `database/dentalcarepro.sql` sono gitignored.
- **DB prod** `dentalcare_prod` (dev `dentalcarepro`). Ricreare il DB **cancella i dati** — `install.sh` chiede doppia conferma.
- **Schema globale** `dentalcare` (enum/funzioni globali). Tenant demo `t_9d754153`. Nuovi tenant creati da `dentalcare.create_tenant(...)` — include già lo schema AI (analyses/labels/tooth_conditions).
- **MinIO** solo su `127.0.0.1`; accesso admin via tunnel SSH.
- Per il **cloud pubblico**: mettere un reverse proxy TLS davanti al frontend, non esporre MinIO/DB, valutare la proposta **#7** (cifratura GDPR) prima di trattare dati clinici reali.

---

## 10. Troubleshooting

| Sintomo | Causa probabile | Rimedio |
|---------|-----------------|---------|
| Analisi AI: `422` alla creazione job | ai-service non raggiungibile / body vuoto | verifica `app.ai.base-url` = `http://dentalcare-ai-service:8000`; container su stessa rete |
| Callback AI: `401` | HMAC non combacia | `app.ai.hmac-secret` = `AI_CALLBACK_SECRET` |
| Token backend↔ai rifiutato | JWT secret diverso | `app.jwt.secret` = `JWT_SECRET` |
| ai-service `models/status` `loaded:false` | ONNX mancanti/percorso errato | copiare i `.onnx` in `models/`, controllare `*_MODEL_PATH` |
| AI rileva pochissimo | `MODEL_INPUT_SCALE` errato | 255 (input 0-1) vs 1 (grafo con /255 bakata) |
| Backend non parte (`@Value` non risolto) | manca `backend/config/` | creare `application-prod.properties` + `credentials/credential.properties` |
| MinIO non raggiungibile dal container | manca `host.docker.internal` | il compose ha già `extra_hosts: host-gateway`; su cloud usare hostname/IP reale di MinIO |
| Documento AI non trovato in bucket | bucket per-tenant vs bucket documenti | i documenti nuovi vanno in `dc-<schema>`; verificare `app.minio.bucket-prefix=dc-` |

---

## 11. Checklist rapida (nuovo host cloud)

- [ ] Docker + compose + git installati; porte 8181 (+9000/9001 se MinIO qui) libere
- [ ] `master` pushato su GitHub **oppure** repo copiato da `192.168.0.72`
- [ ] repo in `~/docker/dentalcarepro` (`setup.sh`)
- [ ] `backend/config/application-prod.properties` creato (DB, MinIO, `app.ai.*`)
- [ ] `credentials/credential.properties` creato (DB pw, JWT, OpenAI)
- [ ] `dentalcare-ai-service/.env` creato (JWT, MinIO, callback, modelli, scale)
- [ ] modelli `*.onnx` presenti in `dentalcare-ai-service/models/` (auto-copia di `install.sh` da `MODELS_SRC`, o manuale)
- [ ] `.env` root (FRONTEND_PORT, VERSION, JDK_VERSION)
- [ ] segreti condivisi combaciano (JWT, HMAC) — §4.5
- [ ] MinIO installato/raggiungibile (§5)
- [ ] `docker compose up -d --build`
- [ ] DB `dentalcare_prod` creato (`install.sql`)
- [ ] smoke test (§8): frontend 200, ai-service health, analisi AI end-to-end
