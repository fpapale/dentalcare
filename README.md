# DentalCare Pro

Gestionale clinico odontoiatrico full stack — Angular 21 + Spring Boot 3.5 + PostgreSQL.

---

## Indice

- [Funzionalità](#funzionalità)
- [Architettura](#architettura)
- [Struttura repository](#struttura-repository)
- [Requisiti](#requisiti)
- [Installazione e avvio](#installazione-e-avvio)
- [Database](#database)
- [Configurazione backend](#configurazione-backend)
- [API REST](#api-rest)
- [Autenticazione e multitenancy](#autenticazione-e-multitenancy)
- [SegretarIA — Agente vocale AI](#segretaria--agente-vocale-ai)
- [Licenza](#licenza)

---

## Funzionalità

### Dashboard
- KPI clinica: appuntamenti del giorno, pazienti totali, preventivi in attesa
- Agenda settimanale sintetica
- Accessi rapidi alle funzioni principali

### Pazienti
- Anagrafica completa con modifica inline
- Anamnesi medica strutturata (allergie, patologie, farmaci)
- Cartella clinica con storico prestazioni e note
- Odontogramma interattivo (denti decidui e permanenti)
- Piani di cura con workflow stati: `bozza → proposto → accettato → completato`
- Preventivi collegati ai piani di cura
- Storico appuntamenti con cambio stato diretto

### Agenda
- Vista settimanale per poltrona/medico
- Creazione appuntamento con ricerca paziente autocomplete
- Validazione weekend e conflitti orario
- Collegamento diretto da piano di cura (pre-compilazione automatica)
- Aggiornamento automatico stato prestazione a `scheduled` al salvataggio

### Piani di Cura
- Creazione piano con più prestazioni da catalogo
- Durata stimata per prestazione (popolata dal catalogo servizi)
- Workflow stati piano: `draft → proposed → accepted → completed / rejected`
- Workflow stati prestazione: `planned → accepted → scheduled → completed / cancelled`
- Pianificazione appuntamento direttamente dalla singola prestazione
- Calcolo totale piano e avanzamento completamento

### Preventivi
- Generazione preventivo da piano di cura
- Gestione stati: bozza, inviato, accettato, rifiutato, scaduto
- Calcolo automatico imponibile, IVA e totale tramite trigger PostgreSQL

### SegretarIA
- Agente vocale AI integrato via Retell AI
- Gestione appuntamenti in linguaggio naturale (conferma, modifica, cancellazione)
- Risposta telefonica automatica
- Console web di monitoraggio sessioni

### Altre sezioni (placeholder UI)
- Fatturazione
- Richiami e recall pazienti
- Magazzino e inventario

---

## Architettura

```
Angular 21 (SPA)
    └── HTTP REST (JSON)
            └── Spring Boot 3.5 (API)
                    ├── Spring Security (mock JWT in dev)
                    ├── AOP Tenant Filter
                    ├── NamedParameterJdbcTemplate (no ORM)
                    └── PostgreSQL 17
```

**Multitenancy** a livello di `clinic_id`: ogni query filtra i dati per clinica corrente derivata dal contesto autenticato.

**Layout frontend** a tre colonne: menu laterale | contenuto centrale | pannello destro contestuale (KPI, riepilogo).

---

## Struttura repository

```
dentalcare/
├── CLAUDE.md                        # Istruzioni operative per Claude Code
├── README.md
├── LICENZA                          # Apache License 2.0
├── install.sh                       # Script deploy Docker (Linux)
├── backend/                         # Spring Boot API
│   ├── pom.xml
│   └── src/main/java/com/dentalcare/
│       ├── config/                  # CORS, AOP tenant aspect
│       ├── controller/              # REST controllers
│       ├── dto/                     # Request / Response DTOs
│       ├── entity/                  # JPA entities (Clinic, Patient, Provider, ...)
│       ├── exception/               # GlobalExceptionHandler, custom exceptions
│       ├── security/                # MockJwtAuthenticationFilter, TenantContext
│       └── service/                 # Business logic
├── frontend/                        # Angular 21 SPA
│   └── src/app/
│       ├── core/
│       │   ├── models/              # TypeScript interfaces (DTO mirror)
│       │   └── services/            # HTTP services
│       ├── features/
│       │   ├── agenda/              # Agenda settimanale + nuovo appuntamento
│       │   ├── dashboard/
│       │   ├── fatturazione/
│       │   ├── magazzino/
│       │   ├── pazienti/            # Lista, dettaglio, tab clinici, piani di cura
│       │   ├── preventivi/
│       │   ├── richiami/
│       │   └── segretaria/          # Console SegretarIA
│       ├── layout/                  # Shell, menu, layout a tre colonne
│       └── app.routes.ts
├── database/
│   ├── 01_schema_applicative.sql    # Schema globale dentalcare (ENUMs, tenants, geo)
│   ├── 02_schema_tenant.sql         # Schema operativo per tenant (parametrizzato)
│   ├── 03_seed_global.sql           # Dati globali: geo Italia, festivi, anamnesi
│   ├── 04_seed_demo_tenant.sql      # Dati demo con appuntamenti su CURRENT_DATE
│   ├── 05_install_new_system.sql    # Orchestratore fresh install completo
│   └── 06_install_new_tenant.sql    # Provisioning nuovo tenant (cliente)
├── directives/                      # Documenti funzionali e architetturali
├── userdocument/                    # Manuale utente
└── Segretaria/                      # Configurazioni agente Retell AI
```

---

## Requisiti

| Componente | Versione minima |
|---|---|
| Java | 21+ (build con Java 25) |
| Maven | 3.9+ (o `mvnw` incluso) |
| Node.js | 20+ |
| npm | 11+ |
| PostgreSQL | 15+ (testato su 17) |
| Angular CLI | 21 |

---

## Installazione e avvio

### 1. Database

```bash
# Crea database
createdb dentalcarepro

# Installazione completa in un solo comando
psql -U postgres -d dentalcarepro -f database/05_install_new_system.sql

# Oppure passo per passo:
psql -d dentalcarepro -f database/01_schema_applicative.sql   # schema globale
psql -d dentalcarepro -f database/03_seed_global.sql          # geo + festivi + anamnesi
psql -v tenant_schema=t_9d754153 \
     -d dentalcarepro -f database/02_schema_tenant.sql        # schema demo
psql -d dentalcarepro -f database/04_seed_demo_tenant.sql     # dati demo
```

Per aggiungere un nuovo tenant (cliente):
```bash
# Edita le variabili in testa al file, poi:
psql -U postgres -d dentalcarepro -f database/06_install_new_tenant.sql
```

### 2. Backend

```bash
cd backend

# Con wrapper Maven (consigliato)
./mvnw clean package -DskipTests
./mvnw spring-boot:run

# Oppure con Maven installato
mvn clean package -DskipTests
mvn spring-boot:run
```

Backend disponibile su `http://localhost:8080`.

Swagger UI: `http://localhost:8080/swagger-ui.html`

### 3. Frontend

```bash
cd frontend
npm install
npm start
```

Frontend disponibile su `http://localhost:4200`.

---

## Deploy su server remoto (Docker)

### Script `install.sh`

Lo script `install.sh` nella root del repository automatizza il deploy completo su qualsiasi server Linux con Docker installato.

```bash
# Clona il repo sul server (prima volta)
git clone https://github.com/fpapale/dentalcare.git ~/docker/dentalcarepro
cd ~/docker/dentalcarepro
chmod +x install.sh

# Primo avvio — guida alla configurazione e build
./install.sh

# Aggiornamento (git pull + rebuild) — config già presenti
./install.sh --update
```

**Cosa fa `install.sh`:**

| Step | Azione |
|---|---|
| 1 | Verifica prerequisiti: `docker`, `git`, `docker compose` |
| 2 | Prima volta: clona repo; aggiornamento: `git pull origin master` |
| 3 | Crea `config/backend/application.properties` e `config/frontend/default.conf` dai template `.example` se assenti; fa pausa se le credenziali DB non sono ancora configurate |
| 4 | Esegue `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build` |
| 5 | Attende healthcheck backend (max 90s) e stampa URL e stato container |

### File di configurazione (da non committare)

Dopo il primo `./install.sh`, personalizzare:

```
config/backend/application.properties   ← DB host, username, password
config/frontend/default.conf            ← nginx (proxy backend, porta)
.env                                    ← FRONTEND_PORT (default 8081)
```

### Porta esposta

Per default il frontend è disponibile sulla porta **8081**. Per cambiare:

```bash
echo "FRONTEND_PORT=80" >> .env
./install.sh --update
```

---

## Database

### Tecnologie
- **PostgreSQL 17** con schema `dentalcare`
- Estensioni: `pgcrypto` (UUID), `citext` (email case-insensitive)
- Flyway presente come dipendenza ma **disabilitato** (`spring.flyway.enabled=false`) — migrazioni applicate manualmente

### Tabelle principali

| Tabella | Descrizione |
|---|---|
| `clinics` | Cliniche (tenant root) |
| `patients` | Pazienti per clinica |
| `providers` | Medici e personale |
| `service_catalog` | Catalogo prestazioni con prezzi e durata |
| `appointments` | Appuntamenti con slot orario e poltrona |
| `treatment_plans` | Piani di cura |
| `treatment_plan_items` | Singole prestazioni nel piano |
| `estimates` | Preventivi economici |
| `estimate_lines` | Righe preventivo con calcoli generati automaticamente |
| `anamnesis_entries` | Anamnesi strutturata per paziente |
| `tooth_conditions` | Stato denti per odontogramma |
| `clinical_history` | Storico note cliniche |

### ENUM

```sql
treatment_plan_status: draft | proposed | accepted | in_progress | completed | rejected | archived
treatment_item_status: planned | accepted | scheduled | completed | cancelled
estimate_status:       draft | sent | accepted | rejected | expired | cancelled
provider_role:         dentist | hygienist | orthodontist | surgeon | assistant | admin | other
```

### Trigger automatici
- `set_updated_at()` — aggiorna `updated_at` su ogni UPDATE
- `trg_recalc_estimate_totals()` — ricalcola `subtotal_amount`, `vat_amount`, `total_amount` su ogni modifica righe preventivo

### Indici
Indici su `(clinic_id, ...)` per tutte le query multitenant. Indici specifici su:
- `patients(clinic_id, last_name, first_name)`
- `patients(clinic_id, fiscal_code)` (partial, NOT NULL)
- `appointments(clinic_id, starts_at)`
- `treatment_plans(clinic_id, patient_id, status)`
- `treatment_plan_items(clinic_id, treatment_plan_id, status, priority)`

---

## Configurazione backend

File: `backend/src/main/resources/application.properties`

```properties
# Database
spring.datasource.url=jdbc:postgresql://<host>:5432/<database>
spring.datasource.username=<utente>
spring.datasource.password=<password>

# JPA — nessuna DDL automatica
spring.jpa.hibernate.ddl-auto=none
spring.flyway.enabled=false

# Server
server.port=8080
```

> **Attenzione**: non committare password reali. Usare variabili d'ambiente in produzione:
> ```bash
> export SPRING_DATASOURCE_URL=jdbc:postgresql://...
> export SPRING_DATASOURCE_PASSWORD=...
> ```

---

## API REST

Base URL: `http://localhost:8080/api`

### Pazienti
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/patients` | Lista pazienti (con filtro ricerca) |
| GET | `/patients/{id}` | Dettaglio paziente |
| POST | `/patients` | Crea paziente |
| PUT | `/patients/{id}` | Aggiorna anagrafica |

### Appuntamenti
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/appointments` | Lista appuntamenti (filtri: week, providerId) |
| GET | `/appointments/patient/{id}` | Appuntamenti paziente |
| GET | `/appointments/chair-labels` | Poltrone disponibili |
| POST | `/appointments` | Crea appuntamento |
| PATCH | `/appointments/{id}/status` | Aggiorna stato |

### Piani di Cura
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/treatment-plans?patientId=` | Piani paziente |
| GET | `/treatment-plans/{id}` | Dettaglio piano con prestazioni |
| POST | `/treatment-plans` | Crea piano |
| PATCH | `/treatment-plans/{id}/status` | Avanza stato piano |
| POST | `/treatment-plans/{id}/items` | Aggiungi prestazione |
| PATCH | `/treatment-plans/{id}/items/{itemId}/status` | Aggiorna stato prestazione |
| DELETE | `/treatment-plans/{id}/items/{itemId}` | Rimuovi prestazione |

### Catalogo Servizi
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/services` | Lista prestazioni con durata |

### Medici
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/providers` | Lista medici attivi |

### Anamnesi
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/anamnesis/{patientId}` | Anamnesi paziente |
| PUT | `/anamnesis/{patientId}` | Salva anamnesi |

### Odontogramma
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/odontogram/{patientId}` | Stato denti |
| PUT | `/odontogram/{patientId}` | Aggiorna odontogramma |

### Dashboard
| Metodo | Endpoint | Descrizione |
|---|---|---|
| GET | `/dashboard` | KPI clinica |

### SegretarIA (AI Chat)
| Metodo | Endpoint | Descrizione |
|---|---|---|
| POST | `/chat` | Endpoint tool-layer per agente Retell AI |

---

## Autenticazione e multitenancy

In sviluppo è attivo un **MockJwtAuthenticationFilter** che inietta automaticamente:
- `clinic_id` dal header `X-Clinic-Id` (o default dalla prima clinica)
- `provider_id` dal header `X-Provider-Id` (opzionale)
- `role` dal header `X-Role` (`admin` | `doctor` | `hygienist`)

Ogni service accede al tenant corrente via `TenantContext.getCurrentTenant()`.

In produzione sostituire il mock con autenticazione JWT reale e derivare `clinic_id` dal token.

---

## SegretarIA — Agente vocale AI

Agente Retell AI configurato per:
- risposta telefonica automatica
- prenotazione, modifica e cancellazione appuntamenti in linguaggio naturale
- integrazione con le API REST del backend (`/api/chat`)

Configurazioni agente in `Segretaria/` (formato JSON Retell AI).

---

## Stack tecnologico

| Layer | Tecnologia |
|---|---|
| Frontend | Angular 21, TypeScript 5.9, Tailwind CSS |
| Backend | Spring Boot 3.5, Java 25, Spring Security |
| Persistenza | NamedParameterJdbcTemplate (no ORM attivo) + JPA entities |
| Database | PostgreSQL 17 |
| Build frontend | Angular CLI 21, Vite |
| Build backend | Maven 3 / mvnw |
| API Docs | SpringDoc OpenAPI (Swagger UI) |
| AI | Retell AI (agente vocale) |

---

## Licenza

Apache 2.0. Vedi [LICENZA](LICENZA).

Copyright 2024-2026 Fabrizio Papale

Questo software è distribuito nei termini della **Apache License, Version 2.0**.
È consentito l'uso, la copia, la modifica e la distribuzione del software,
con o senza modifiche, in formato sorgente o binario, a condizione che vengano
rispettati i termini indicati nel file [LICENZA](LICENZA).

Testo completo della licenza: [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)
