import { Component, Input, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, Router } from '@angular/router';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { TreatmentPlanSummary, TreatmentPlanStatus } from '../../../core/models/treatment-plan.model';

@Component({
  selector: 'app-piano-cura-tab',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './piano-cura-tab.component.html'
})
export class PianoCuraTabComponent implements OnInit {
  @Input() patientId!: string;

  plans = signal<TreatmentPlanSummary[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  confirmDeletePlanId = signal<string | null>(null);
  deletingPlanId = signal<string | null>(null);

  editingPlanId = signal<string | null>(null);
  savingNameId = signal<string | null>(null);
  editNameValue = '';

  constructor(
    private planService: TreatmentPlanService,
    private router: Router,
  ) {}

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

  navigateToPlan(planId: string): void {
    this.router.navigate(['/pazienti', this.patientId, 'piano-cura', planId]);
  }

  startEditName(plan: TreatmentPlanSummary): void {
    this.editNameValue = plan.name;
    this.editingPlanId.set(plan.planId);
  }

  cancelEditName(): void {
    this.editingPlanId.set(null);
  }

  saveNameEdit(planId: string): void {
    const name = this.editNameValue.trim();
    if (!name) return;
    this.savingNameId.set(planId);
    this.planService.updateName(planId, name).subscribe({
      next: () => {
        this.plans.update(list => list.map(p => p.planId === planId ? { ...p, name } : p));
        this.savingNameId.set(null);
        this.editingPlanId.set(null);
      },
      error: () => {
        this.savingNameId.set(null);
        this.error.set('Errore nel salvataggio del nome');
      }
    });
  }

  deletePlan(planId: string): void {
    this.deletingPlanId.set(planId);
    this.planService.deletePlan(planId).subscribe({
      next: () => {
        this.deletingPlanId.set(null);
        this.confirmDeletePlanId.set(null);
        this.plans.update(list => list.filter(p => p.planId !== planId));
      },
      error: () => {
        this.deletingPlanId.set(null);
        this.error.set('Errore nella eliminazione del piano di cura');
      }
    });
  }
}
