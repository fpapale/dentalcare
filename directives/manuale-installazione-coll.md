# Manuale installazione — ambiente COLLAUDO (#41)

> **Segnaposto.** File versionato su repo pubblico: nessun indirizzo/credenziale reale.
> Sostituire prima dell'uso: `<server-app>` host Docker · `<host-db>` host PostgreSQL ·
> `<utente>` utente SSH. I valori reali stanno fuori dal repo (config montata, gestore password).

Ambiente di **collaudo** in stack Docker parallelo a produzione, sulla **stessa** macchina
`<server-app>`. Indipendente da prod per cartella, container, immagini, porta e profilo Spring.
Serve a provare release candidate su un DB separato senza toccare i dati di produzione.

## Cosa lo distingue da prod

| | Prod | Collaudo |
|---|---|---|
| Cartella deploy | `~/docker/dentalcarepro` | `~/docker/dentalcarepro-coll` |
| Profilo Spring | `prod` | `coll` |
| Database (`<host-db>`) | `dentalcare_prod` | `dentalcare_coll` |
| Compose | `docker-compose.yml` | `docker-compose.coll.yml` |
| Container | `dentalcarepro-*` | `dentalcarepro-coll-*` |
| Immagini | `:latest` | `:coll-*` |
| Porta frontend | 8181 | **8082** |
| Radice bucket MinIO (#40) | `dc-prod-` | `dc-coll-` |
| Demo mode | off | off |
| Errori/log | non esposti / WARN | esposti / DEBUG (diagnosi) |

MinIO è lo **stesso container fisico** di prod: l'isolamento dei documenti è per bucket
(`dc-coll-`), non per rete. Coll non ha dati reali da migrare: adotta il prefisso direttamente.

## Prerequisiti
- Docker Engine + plugin Compose e `git` sul server `<server-app>`.
- Client `psql` (solo se si (ri)crea il DB dal server).
- Container MinIO già attivo (rete esterna `minio_default`), condiviso con prod.
- Prod già in esecuzione **non** è un ostacolo: i nomi/porte non collidono.

## Installazione

### Bootstrap (prima volta)
```bash
curl -fsSL https://raw.githubusercontent.com/fpapale/dentalcare/master/setup-coll.sh -o /tmp/setup-coll.sh
bash /tmp/setup-coll.sh
```
`setup-coll.sh` crea `~/docker/dentalcarepro-coll`, clona il repo e lancia `install-coll.sh`.

### install-coll.sh — cosa fa
1. Verifica `docker`/`git`/`docker compose`.
2. Clone (prima volta) o `git pull origin master`.
3. Crea `config/application-coll.properties` da `.example` se assente, e `.env` con `FRONTEND_PORT=8082`.
4. Chiede se creare/**ricreare** `dentalcare_coll` (doppia conferma `SI`, `DROP DATABASE ... FORCE`
   + ricreazione da `database/install.sql -v dbname=dentalcare_coll`). Con `--update` la domanda è saltata.
5. Copia i modelli AI ONNX se assenti.
6. `docker compose -f docker-compose.coll.yml up -d --build`.
7. Attende l'healthcheck di `dentalcarepro-coll-backend` e stampa `http://<host>:8082/`.

### Configurazione obbligatoria prima del primo avvio
In `~/docker/dentalcarepro-coll/config/application-coll.properties` (creato dal template),
impostare valori **DIVERSI da prod**:
- `spring.datasource.password` (password DB coll);
- `app.jwt.secret` (`openssl rand -base64 48`);
- `app.encryption.master-key` (`openssl rand -hex 32`, 64 hex) — senza chiave valida il backend
  non parte (fail-fast). Non riusare la chiave di prod.
- credenziali MinIO (`app.minio.access-key`/`secret-key`).

## Aggiornamento
```bash
cd ~/docker/dentalcarepro-coll && ./setup-coll.sh --update   # pull + rebuild, no config, no DB
```

## Creazione DB a mano (alternativa)
```bash
psql -U postgres -h <host-db> -d postgres -v dbname=dentalcare_coll -f database/install.sql
```

## Note
- Nessun flusso n8n/Retell dedicato a Coll (confermato 23/07/2026): è solo stack web (BE+FE+AI+DB).
- Immagini `:coll-*` da pulire periodicamente (`docker image prune`), come per prod.
- Coll è un ambiente di test: **non** abilita l'uso su pazienti reali (gate go-live invariato).
