# Procedure deploy — trigger "deploy in produzione" / "lavoriamo in dev"

Direttiva operativa. Quando l'utente scrive uno dei due trigger, applicare la
procedura corrispondente senza richiederne i dettagli.

---

## Trigger: "deploy in produzione"

Predisporre/aggiornare il deploy Docker di produzione sulla macchina
`192.168.0.72` (cartella `~/docker/dentalcarepro`), DB `dentalcare_prod` su
`192.168.0.173`. Stato atteso dei file (creare/riallineare se divergono):

1. **`backend/src/main/resources/application-prod.properties`**
   - Riallineato per struttura ad `application.properties`.
   - `spring.datasource.url=jdbc:postgresql://192.168.0.173:5432/dentalcare_prod`
   - Hardening prod: `server.error.include-message=never`,
     `server.error.include-binding-errors=never`, `logging.level.root=WARN`,
     `logging.level.com.dentalcare=INFO`.
   - Demo mode resta abilitato (`app.demo.enabled=true`).

2. **`docker-compose.yml`** (file UNICO, niente override prod):
   - `backend`: profilo `prod` (`SPRING_PROFILES_ACTIVE=prod`), **non esposto**
     sull'host; config esterna montata `./config:/app/config:ro` +
     `SPRING_CONFIG_ADDITIONAL_LOCATION=optional:file:/app/config/`;
     healthcheck su `/api/public/demo-config`; limite memoria 1g.
   - `frontend`: nginx ascolta su **4200** nel container, esposto
     `"${FRONTEND_PORT:-8181}:4200"`; `depends_on` backend healthy; limite 256m.
   - network bridge `dentalcarepro`.

3. **`frontend/nginx.conf`** e **`frontend/Dockerfile`**: nginx `listen 4200`,
   `EXPOSE 4200`. nginx proxa `/api/` a `http://backend:8080/api/`.

4. **`config/`** (flat, non più `config/backend` o `config/frontend`):
   - `config/application-prod.properties.example` → puntato a `dentalcare_prod`
     (DB, creds, `app.jwt.secret` da cambiare, demo on, errori non esposti).
   - `config/.gitignore` ignora il file reale `application-prod.properties`.
   - nginx è bundled nell'immagine: nessun mount frontend.

5. **`install.sh`** (eseguito da `~/docker/dentalcarepro`):
   - verifica `docker`/`git`/`docker compose`;
   - clone (prima volta, da `https://github.com/fpapale/dentalcare.git`) o
     `git pull origin master`;
   - crea `config/application-prod.properties` da `.example` se assente, crea
     `.env` da `.env.example`;
   - **chiede se creare/ricreare il DB `dentalcare_prod`**:
     - risposta affermativa → doppia conferma (`SI`), `docker compose down` per
       liberare le connessioni, poi
       `DROP DATABASE IF EXISTS dentalcare_prod WITH (FORCE)` e ricreazione da
       `database/install.sql` (`-v dbname=dentalcare_prod`). Richiede `psql`
       sul server e password postgres (da `PGPASSWORD` o prompt). **Cancella i dati esistenti.**
     - risposta negativa → si assume il DB già esistente, deploy della **sola
       parte applicativa**.
     - con `--update` la domanda DB è saltata.
   - `docker compose up -d --build`;
   - attende healthcheck container `dentalcarepro-backend` (max 120s);
   - stampa URL `http://<host>:8181/`.
   - `./install.sh --update` = solo pull + rebuild (no config, no DB).

6. **`.env.example`**: `FRONTEND_PORT=8181`, `VERSION`, `JDK_VERSION=21`.

7. **`.gitattributes`**: forza `eol=lf` su `*.sh` e `*.sql`.

8. **DB**: creato con lo script parametrico
   `psql -U postgres -h 192.168.0.173 -d postgres -v dbname=dentalcare_prod -f database/install.sql`.

Al termine: commit + push su `master`.

### Comandi deploy sul server

Bootstrap prima volta (scarica solo `setup.sh`, che prepara la cartella, clona
il repo e lancia `install.sh`):
```bash
curl -fsSL https://raw.githubusercontent.com/fpapale/dentalcare/master/setup.sh -o /tmp/setup.sh
bash /tmp/setup.sh
```

Se il repo è già clonato in `~/docker/dentalcarepro`:
```bash
cd ~/docker/dentalcarepro
./setup.sh            # mkdir+cd+pull+install (aggiornamento completo)
./setup.sh --update   # solo pull + rebuild app
```

`setup.sh` verifica/crea `~/docker/dentalcarepro`, fa clone (dir vuota) o pull
(repo esistente), poi esegue `install.sh` (che chiede se creare/ricreare il DB).
In alternativa creare il DB a mano:
```bash
psql -U postgres -h 192.168.0.173 -d postgres -v dbname=dentalcare_prod -f database/install.sql
```
App: `http://192.168.0.72:8181/` — login `admin@demo.dentalcare.it` / `DemoAdmin1!`.

---

## Trigger: "lavoriamo in dev"

Riportare tutto alla configurazione di sviluppo:

1. Backend usa **`application.properties`** (profilo default, NON `prod`).
2. Datasource punta al DB **`dentalcarepro`**
   (`jdbc:postgresql://192.168.0.173:5432/dentalcarepro`).
3. Impostazioni dev: `server.error.include-message=always`,
   `server.error.include-binding-errors=always`,
   `logging.level.com.dentalcare=DEBUG`, demo mode on.
4. Avvio locale senza Docker prod: backend `mvnw spring-boot:run` (porta 8080),
   frontend `npm start` (porta 4200). Nessun profilo `prod` attivo.
5. DB dev creato con:
   `psql -U postgres -h 192.168.0.173 -d postgres -v dbname=dentalcarepro -f database/install.sql`.

---

## Note

- DB dev: `dentalcarepro` (192.168.0.173). DB prod: `dentalcare_prod` (192.168.0.173).
- Lo schema globale è `dentalcare`; enum e funzioni globali vivono lì (i cast SQL
  usano `dentalcare.<tipo>`, non lo schema tenant).
- `database/install.sql` è lo script unico parametrico (`-v dbname=...`) che crea
  schema globale + tenant demo `t_9d754153` con dati di esempio.
