import { Injectable, signal } from '@angular/core';

/**
 * Contesto UI condiviso letto dal Copilot (SegretarIA) per sapere quale paziente/schermata
 * l'utente sta guardando in questo momento. I componenti feature (es. paziente-detail)
 * lo aggiornano in ngOnInit e lo azzerano in ngOnDestroy.
 *
 * Solo informativo: nessun controllo di sicurezza deve basarsi su questi valori.
 */
@Injectable({ providedIn: 'root' })
export class CopilotContextService {
  readonly patientId = signal<string | null>(null);
  readonly patientName = signal<string | null>(null);
  readonly view = signal<string | null>(null);

  setPatient(patientId: string | null, patientName: string | null): void {
    this.patientId.set(patientId);
    this.patientName.set(patientName);
  }

  setView(view: string | null): void {
    this.view.set(view);
  }

  clearPatient(): void {
    this.patientId.set(null);
    this.patientName.set(null);
  }
}
