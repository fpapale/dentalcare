import { Component, EventEmitter, inject, Input, OnInit, Output, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { ClinicalRecordService } from '../../../core/services/clinical-record.service';
import { ClinicalHistoryEntry, OdontogramSummary, TreatmentPlanSummary } from '../../../core/models/clinical-record.model';
import { UserContextService } from '../../../core/services/user-context.service';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { DiagnosiService } from '../../../core/services/diagnosi.service';
import { PrescrizioneService } from '../../../core/services/prescrizione.service';
import { Diagnosi } from '../../../core/models/diagnosi.model';
import { Prescrizione } from '../../../core/models/prescrizione.model';

@Component({
  selector: 'app-cartella-tab',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './cartella-tab.component.html',
})
export class CartellaClinicalTabComponent implements OnInit {
  private readonly userContext = inject(UserContextService);
  private readonly treatmentPlanService = inject(TreatmentPlanService);
  private readonly diagnosiService = inject(DiagnosiService);
  private readonly prescrizioneService = inject(PrescrizioneService);

  @Input({ required: true }) paziente!: any;
  @Input({ required: true }) patientId!: string;
  @Output() readonly openAnamnesi = new EventEmitter<void>();
  @Output() readonly openTab = new EventEmitter<string>();

  readonly role = this.userContext.role;

  diary = signal<ClinicalHistoryEntry[]>([]);
  treatmentPlans = signal<TreatmentPlanSummary[]>([]);
  odontogram = signal<OdontogramSummary | null>(null);
  diagnosi = signal<Diagnosi[]>([]);
  prescrizioni = signal<Prescrizione[]>([]);
  loadingDiary = signal(true);
  loadingPlans = signal(true);
  loadingOdonto = signal(true);
  loadingDiagnosi = signal(true);
  loadingPrescrizioni = signal(true);

  showCreaPianoModal = signal(false);
  nuovoPianoNome = signal('');
  nuovoPianoDesc = signal('');
  savingPiano = signal(false);

  constructor(private clinicalService: ClinicalRecordService) {}

  ngOnInit(): void {
    this.clinicalService.getDiary(this.patientId).subscribe({
      next: d => { this.diary.set(d); this.loadingDiary.set(false); },
      error: () => this.loadingDiary.set(false)
    });
    this.clinicalService.getTreatmentPlans(this.patientId).subscribe({
      next: d => { this.treatmentPlans.set(d); this.loadingPlans.set(false); },
      error: () => this.loadingPlans.set(false)
    });
    this.clinicalService.getOdontogramSummary(this.patientId).subscribe({
      next: d => { this.odontogram.set(d); this.loadingOdonto.set(false); },
      error: () => this.loadingOdonto.set(false)
    });
    const r = this.role();
    if (r !== 'secretary') {
      this.diagnosiService.findAll(this.patientId).subscribe({
        next: d => { this.diagnosi.set(d); this.loadingDiagnosi.set(false); },
        error: () => this.loadingDiagnosi.set(false)
      });
      this.prescrizioneService.findAll(this.patientId).subscribe({
        next: d => { this.prescrizioni.set(d); this.loadingPrescrizioni.set(false); },
        error: () => this.loadingPrescrizioni.set(false)
      });
    } else {
      this.loadingDiagnosi.set(false);
      this.loadingPrescrizioni.set(false);
    }
  }

  get activeDiagnosi(): Diagnosi[] {
    return this.diagnosi().filter(d => d.status === 'active');
  }

  get activePrescrizioni(): Prescrizione[] {
    return this.prescrizioni().filter(p => p.active);
  }

  get alerts(): { type: 'critical' | 'warning' | 'info'; label: string }[] {
    const list: { type: 'critical' | 'warning' | 'info'; label: string }[] = [];
    const p = this.paziente;
    if (!p) return list;
    if (p.allergie?.length) {
      list.push({ type: 'critical', label: 'Allergie registrate' });
    }
    if (p.takingAnticoagulants) list.push({ type: 'critical', label: 'Terapia anticoagulante' });
    if (p.takingBisphosphonates) list.push({ type: 'critical', label: 'Terapia con bisfosfonati' });
    if (p.heartDisease) list.push({ type: 'warning', label: 'Cardiopatia' });
    if (p.hypertension) list.push({ type: 'warning', label: 'Ipertensione' });
    if (p.diabetes) list.push({ type: 'warning', label: 'Diabete' });
    if (!p.anamnesisDate) list.push({ type: 'info', label: 'Anamnesi da completare' });
    return list;
  }

  get activePlans(): TreatmentPlanSummary[] {
    return this.treatmentPlans().filter(p => ['in_progress', 'accepted', 'proposed'].includes(p.status));
  }

  creaPiano(): void {
    if (!this.nuovoPianoNome().trim() || this.savingPiano()) return;
    this.savingPiano.set(true);
    this.treatmentPlanService.create(this.patientId, this.nuovoPianoNome().trim(), this.nuovoPianoDesc().trim() || undefined)
      .subscribe({
        next: () => {
          this.savingPiano.set(false);
          this.showCreaPianoModal.set(false);
          this.nuovoPianoNome.set('');
          this.nuovoPianoDesc.set('');
          this.clinicalService.getTreatmentPlans(this.patientId).subscribe(d => this.treatmentPlans.set(d));
        },
        error: () => this.savingPiano.set(false)
      });
  }

  formatDate(d: string | null): string {
    if (!d) return 'Non registrato';
    return new Date(d).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  planStatusLabel(s: string): string {
    const m: Record<string, string> = {
      draft: 'Bozza', proposed: 'Proposto', accepted: 'Accettato',
      in_progress: 'In corso', completed: 'Completato', rejected: 'Rifiutato', archived: 'Archiviato'
    };
    return m[s] ?? s;
  }

  planStatusClass(s: string): string {
    if (s === 'in_progress' || s === 'accepted') return 'bg-teal-100 text-teal-700';
    if (s === 'completed') return 'bg-green-100 text-green-700';
    if (s === 'proposed') return 'bg-blue-100 text-blue-700';
    if (s === 'rejected') return 'bg-red-100 text-red-700';
    return 'bg-slate-100 text-slate-600';
  }

  diaryEntryIcon(entry: ClinicalHistoryEntry): string {
    if (entry.toothNumber) return 'dentistry';
    if (entry.serviceName?.toLowerCase().includes('igiene')) return 'cleaning_services';
    return 'edit_note';
  }

  diagnosiStatusLabel(s: string): string {
    return s === 'active' ? 'Attiva' : s === 'resolved' ? 'Risolta' : 'Cronica';
  }

  diagnosiStatusClass(s: string): string {
    return s === 'active' ? 'bg-red-100 text-red-700' :
           s === 'resolved' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700';
  }
}
