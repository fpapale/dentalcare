# Direttiva per miglioramento Scheda Paziente - Cartella Clinica DentalCare Pro

## Obiettivo

Migliorare la maschera della scheda paziente, in particolare la sezione **Cartella Clinica**, rendendola coerente con l’uso reale di un gestionale odontoiatrico.

La sezione **Cartella Clinica** non deve essere una pagina vuota o generica, ma deve diventare il centro operativo clinico del paziente, con informazioni odontoiatriche, diario clinico, odontogramma, piano di cura, esami, documenti e alert sanitari rilevanti.

L’anamnesi deve rimanere una tab autonoma, ma dentro la Cartella Clinica deve essere presente un riepilogo anamnestico sintetico con gli alert principali.

---

## Principio funzionale

Nel gestionale odontoiatrico:

- **Anamnesi** = sezione specifica e strutturata dedicata alla storia medica generale del paziente.
- **Cartella Clinica** = area clinica operativa del dentista, dove vengono gestiti odontogramma, diagnosi, trattamenti, diario clinico, piano di cura, prescrizioni, esami e documenti clinici.
- L’anamnesi appartiene concettualmente alla cartella clinica, ma a livello UI deve restare una sezione separata per chiarezza e compilazione guidata.
- Nella Cartella Clinica deve però essere sempre visibile un **riepilogo anamnestico critico**.

---

## Miglioramento della testata paziente

Nella testata paziente evitare badge clinici troppo diretti o stigmatizzanti, ad esempio:

```text
Obeso