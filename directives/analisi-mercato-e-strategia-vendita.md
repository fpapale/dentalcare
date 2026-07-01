# Analisi di mercato e strategia di vendita — DentalCare Pro

**Data:** 2026-07-01
**Autore:** analisi generata con Claude Code, basata su stato repository e memoria di progetto
**Scopo:** valutazione strategica del prodotto per posizionamento SaaS mercato italiano/europeo

---

## 1. Executive summary

DentalCare Pro è una web application gestionale per studi odontoiatrici, full stack (Angular + Spring Boot + PostgreSQL), con moduli completi (agenda, pazienti/cartella clinica, piani di cura, preventivi, fatturazione, magazzino, richiami) più un layer AI distintivo (segretaria conversazionale vocale/chat, review radiografico assistito su DICOM in sviluppo).

Il progetto è maturo funzionalmente per un MVP enterprise-grade, ma privo di clienti paganti, certificazioni regolatorie e struttura di supporto. Il differenziale competitivo reale è l'AI-first approach in un mercato IT dominato da player legacy senza automazione nativa.

---

## 2. Stato del progetto (baseline)

Metriche al 2026-07-01:

| Metrica | Valore |
|---|---|
| File Java (backend) | 289 |
| File TypeScript (frontend) | 199 |
| Moduli funzionali | Dashboard, Agenda, Pazienti/Cartella clinica/Odontogramma, Piani di cura, Preventivi, Fatturazione, Magazzino, Richiami, Segretaria AI, Admin multitenant |
| Architettura | Layered (Controller→Service→Repository→DB), DTO separati da entity, multitenant nativo |
| Sicurezza | JWT, provider-scoping su chat AI (fix IDOR 2026-07-01), validazione server-side |
| Velocità di sviluppo storica | ~50-100x compressione ore umane vs equivalente team tradizionale (vedi memoria `project_velocity`) |
| Clienti paganti | Nessuno al momento |
| Certificazioni | Nessuna (GDPR audit esterno, penetration test, MDR/CE per moduli AI diagnostici) |

---

## 3. Posizionamento di mercato

### 3.1 Competitor principali (Italia/Europa)

- **Byte Sesamo/Extra** — leader storico IT, base installata enorme, UX datata, AI assente
- **iDental, PlanDent, Kodak-based systems** — legacy, forte integrazione hardware radiografico, cloud spesso opzionale/tardivo
- **Player europei** (Dentally UK, Curve Dental) — più moderni ma non localizzati per mercato IT (fatturazione elettronica SDI, normative locali)

### 3.2 Gap di mercato individuato

Nessun competitor IT rilevante offre **nativamente**:
1. Segretaria AI conversazionale per booking/reminder telefonico
2. Review radiografico assistito da AI su immagini DICOM
3. Multitenant cloud-native pensato per gruppi/catene multi-sede fin dal design

### 3.3 Strategia di posizionamento consigliata

**Non competere frontalmente** su feature-parity con incumbent (persa in partenza per fiducia/base installata). Posizionarsi come **sfidante AI-first cloud-native**, target:
- Studi giovani/tech-savvy in fase di digitalizzazione
- Gruppi odontoiatrici multi-sede (2-10+ studi) — il multitenant è vantaggio strutturale
- Studi che vogliono ridurre costo reception/no-show tramite automazione

---

## 4. Punti di forza

| Area | Dettaglio |
|---|---|
| **Differenziazione AI** | Segretaria conversazionale + review radiografico: nessun competitor IT diretto ha entrambe oggi |
| **Multitenant nativo** | Vendibile a catene/gruppi senza refactoring, ticket medio più alto |
| **Velocità iterazione** | Costo marginale per nuova feature molto basso → time-to-market su richieste clienti reali |
| **Architettura moderna** | Angular + Spring Boot + Postgres, cloud-ready, manutenibile, testabile |
| **Sicurezza presa sul serio** | JWT, scoping per provider/tenant, fix proattivi (IDOR chat sessions) |

---

## 5. Punti di debolezza / rischi

| Area | Rischio | Mitigazione |
|---|---|---|
| **Zero clienti paganti** | Percezione "prodotto non provato" | Pilota gratuito 2-3 mesi con studi selezionati in cambio di case study |
| **Team mono-persona** | Bus-factor, SLA percepito debole vs incumbent con call center | Valutare partnership/co-founder tecnico o supporto esternalizzato per fase go-to-market |
| **Integrazioni mancanti** | No fatturazione elettronica SDI, no POS/cassa, no app mobile | Roadmap integrazione SDI prioritaria (blocco per adozione IT) |
| **Regolatorio AI diagnostica** | Review radiografico rientra potenzialmente in dispositivo medico (MDR/CE) | Posizionare come "supporto pre-screening", non diagnosi; disclaimer esplicito; consulenza legale/regolatoria prima di vendita in ambito clinico |
| **Test coverage** | Suite non enterprise-grade, no Testcontainers strutturato | Investire in integration test prima di onboarding clienti paganti |
| **Nessuna certificazione** | No audit GDPR esterno, no penetration test | Pianificare audit prima di scaling commerciale, specie per dati sanitari |

---

## 6. Strategia di vendita

### 6.1 Approccio go-to-market

1. **Wedge AI, non migrazione totale**: vendere la segretaria AI come add-on standalone a studi che già usano altro gestionale → riduce barriera d'ingresso, ROI misurabile (telefonate perse, no-show ridotti)
2. **Target primario**: gruppi multi-sede (2-10 studi) — multitenant come vantaggio strutturale, ticket medio più alto, decisione d'acquisto più centralizzata
3. **Canali**:
   - Fiere di settore (Expodental Meeting)
   - Distributori di materiali/attrezzature dentali (già presenti in studio, fiducia costruita)
   - Referral da studi pilota con case study documentato
4. **Riduzione barriera ingresso**: trial gratuito 30 giorni per studio singolo, no carta di credito richiesta

### 6.2 Sequenza consigliata

```
Fase 1 (0-3 mesi)  → 2-3 studi pilota gratuiti, raccolta case study, hardening test/sicurezza
Fase 2 (3-6 mesi)  → lancio commerciale add-on Segretaria AI standalone, canale distributori
Fase 3 (6-12 mesi) → gestionale completo per gruppi multi-sede, integrazione SDI, certificazioni
Fase 4 (12+ mesi)  → valutazione percorso MDR/CE per modulo review radiografico se validato clinicamente
```

---

## 7. Modello di pricing (SaaS, mercato IT/EU)

Riferimento mercato: gestionali dentali IT prezzano tipicamente **€50-150/mese per riunito (chair)**.

| Piano | Contenuto | Prezzo indicativo |
|---|---|---|
| **Base** | Agenda + Pazienti + Fatturazione + Magazzino (1-2 riuniti) | €89-119/mese |
| **Pro** | + Preventivi + Richiami + multi-riunito + report KPI | €199-249/mese |
| **Enterprise / multi-sede** | Multitenant completo + Segretaria AI inclusa | €399-599/mese (o scaling per sede) |
| **Add-on Segretaria AI** | Standalone su gestionale esistente, per numero telefonico gestito | €99-149/mese |
| **Add-on Review radiografico AI** | Supporto pre-screening (no diagnosi), disclaimer esplicito | €49-79/mese |

**Nota regolatoria:** il modulo di review radiografico non va venduto come strumento diagnostico finché non affrontato il percorso MDR/CE. Posizionamento attuale: supporto informativo al professionista, che mantiene piena responsabilità refertativa.

---

## 8. Prossimi passi consigliati

1. Selezionare 2-3 studi pilota per validazione gratuita e raccolta feedback/case study
2. Investire in hardening test (integration test, eventuale Testcontainers) prima di onboarding paganti
3. Pianificare audit di sicurezza esterno (penetration test) su moduli dati sanitari
4. Consulenza legale su qualificazione MDR del modulo AI radiografico
5. Sviluppare integrazione fatturazione elettronica SDI (probabile blocco per adozione mercato IT)
6. Preparare materiale commerciale per canale distributori (demo, ROI calculator segretaria AI)

---

## 9. Riferimenti interni

- Stato moduli implementati: memoria `project-modules-status`
- Metriche velocità sviluppo: memoria `project-velocity`
- Tracking proposte tecniche in corso: `directives/proposte-modifiche.md`
- Architettura AI/multitenant Segretaria: `directives/segretaria_architettura_multitenant_ai.md`
