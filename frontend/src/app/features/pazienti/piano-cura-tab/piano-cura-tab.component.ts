import { Component, Input, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { TreatmentPlanSummary, TreatmentPlanStatus } from '../../../core/models/treatment-plan.model';

@Component({
  selector: 'app-piano-cura-tab',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './piano-cura-tab.component.html'
})
export class PianoCuraTabComponent implements OnInit {
  @Input() patientId!: string;

  plans = signal<TreatmentPlanSummary[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  constructor(private planService: TreatmentPlanService) {}

  ngOnInit(): void {
    this.planService.findByPatient(this.patientId).subscribe({
      next: data => { this.plans.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento dei piani di cura'); this.loading.set(false); }
    });
  }

  statusLabel(s: TreatmentPlanStatus): string {
    const map: Record<TreatmentPlanStatus, string> = {
      draft: 'Bozza', proposed: 'Proposto', accepted: 'Accettato',
      completed: 'Completato', rejected: 'Rifiutato'
    };
    return map[s] ?? s;
  }

  statusClass(s: TreatmentPlanStatus): string {
    switch (s) {
      case 'accepted':  return 'bg-green-100 text-green-700';
      case 'completed': return 'bg-slate-100 text-slate-500';
      case 'rejected':  return 'bg-red-100 text-red-700';
      case 'proposed':  return 'bg-blue-100 text-blue-700';
      default:          return 'bg-yellow-50 text-yellow-700';
    }
  }

  progressPct(p: TreatmentPlanSummary): number {
    if (p.totalItems === 0) return 0;
    return Math.round((p.completedItems / p.totalItems) * 100);
  }
}
