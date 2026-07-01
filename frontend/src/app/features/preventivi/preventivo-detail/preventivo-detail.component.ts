import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { forkJoin, from } from 'rxjs';
import { concatMap } from 'rxjs/operators';
import { EstimateService } from '../../../core/services/estimate.service';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { ServiceCatalogService } from '../../../core/services/service-catalog.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { PatientService } from '../../../core/services/patient.service';
import { EstimateDetail, PlanItemCoverage } from '../../../core/models/estimate.model';
import { TreatmentPlan } from '../../../core/models/treatment-plan.model';
import { ServiceItem } from '../../../core/models/service.model';
import { PatientListItem } from '../../../core/models/patient.model';

@Component({
  selector: 'app-preventivo-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './preventivo-detail.component.html'
})
export class PreventivoDetailComponent implements OnInit {
  estimateId = '';
  isNew = false;

  // New estimate form
  newPatientId = '';
  newPlanId = '';
  newTitle = 'Preventivo';
  newNotes = '';
  newValidUntil = '';
  creating = signal(false);
  patients = signal<PatientListItem[]>([]);
  patientsLoading = signal(false);

  estimate = signal<EstimateDetail | null>(null);
  loading = signal(true);
  error = signal<string | null>(null);

  // Edit header
  editingHeader = signal(false);
  savingHeader = signal(false);
  headerForm = { title: '', notes: '', validUntil: '' };

  // Add line form
  showAddLine = signal(false);
  addingLine = signal(false);
  addLineForm = {
    serviceId: '',
    toothSnapshot: '',
    quantity: 1,
    unitPrice: null as number | null,
    discountAmount: 0,
    vatRate: 0
  };
  services = signal<ServiceItem[]>([]);

  // Import from plan
  showImportPlan = signal(false);
  linkedPlan = signal<TreatmentPlan | null>(null);
  planCoverage = signal<PlanItemCoverage[]>([]);
  planLoading = signal(false);
  selectedImportItems = signal<string[]>([]);
  addingMultiple = signal(false);

  // Delete line
  deletingLineId = signal<string | null>(null);

  // Delete estimate
  confirmDelete = signal(false);
  deleting = signal(false);

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private estimateService: EstimateService,
    private treatmentPlanService: TreatmentPlanService,
    private serviceCatalogService: ServiceCatalogService,
    private userContext: UserContextService,
    private patientService: PatientService
  ) {}

  ngOnInit(): void {
    this.estimateId = this.route.snapshot.paramMap.get('estimateId') ?? '';
    this.isNew = this.estimateId === 'nuovo';

    if (this.isNew) {
      this.newPatientId = this.route.snapshot.queryParamMap.get('patientId') ?? '';
      this.newPlanId = this.route.snapshot.queryParamMap.get('planId') ?? '';
      if (!this.newPatientId) {
        this.patientsLoading.set(true);
        this.patientService.findAll().subscribe({
          next: data => { this.patients.set(data); this.patientsLoading.set(false); },
          error: () => { this.error.set('Errore nel caricamento dei pazienti'); this.patientsLoading.set(false); }
        });
      }
      this.loading.set(false);
    } else {
      this.loadEstimate();
    }

    this.serviceCatalogService.findAll().subscribe(data => this.services.set(data));
  }

  private loadEstimate(): void {
    this.loading.set(true);
    this.estimateService.findById(this.estimateId).subscribe({
      next: data => { this.estimate.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento del preventivo'); this.loading.set(false); }
    });
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  createEstimate(): void {
    if (!this.newPatientId) return;
    this.creating.set(true);
    this.estimateService.create({
      patientId: this.newPatientId,
      treatmentPlanId: this.newPlanId || undefined,
      createdByProviderId: this.userContext.providerId() ?? undefined,
      title: this.newTitle.trim() || 'Preventivo',
      notes: this.newNotes || undefined,
      validUntil: this.newValidUntil || undefined
    }).subscribe({
      next: id => { this.creating.set(false); this.router.navigate(['/preventivi', id]); },
      error: () => { this.creating.set(false); this.error.set('Errore nella creazione del preventivo'); }
    });
  }

  // ── Header edit ────────────────────────────────────────────────────────────

  startEditHeader(): void {
    const e = this.estimate();
    if (!e) return;
    this.headerForm = { title: e.title, notes: e.notes ?? '', validUntil: e.validUntil ?? '' };
    this.editingHeader.set(true);
  }

  cancelEditHeader(): void { this.editingHeader.set(false); }

  saveHeader(): void {
    this.savingHeader.set(true);
    this.estimateService.updateHeader(this.estimateId, {
      title: this.headerForm.title.trim() || undefined,
      notes: this.headerForm.notes || undefined,
      validUntil: this.headerForm.validUntil || undefined
    }).subscribe({
      next: () => { this.savingHeader.set(false); this.editingHeader.set(false); this.loadEstimate(); },
      error: () => { this.savingHeader.set(false); this.error.set('Errore nel salvataggio'); }
    });
  }

  // ── Status ─────────────────────────────────────────────────────────────────

  updateStatus(status: string): void {
    this.estimateService.updateStatus(this.estimateId, status).subscribe({
      next: () => this.loadEstimate(),
      error: () => this.error.set('Errore nell\'aggiornamento dello stato')
    });
  }

  // ── Add line ───────────────────────────────────────────────────────────────

  onAddLineServiceChange(): void {
    const svc = this.services().find(s => s.serviceId === this.addLineForm.serviceId);
    if (svc) this.addLineForm.unitPrice = svc.defaultPrice;
  }

  submitAddLine(): void {
    if (!this.addLineForm.serviceId) return;
    this.addingLine.set(true);
    this.estimateService.addLine(this.estimateId, {
      serviceId: this.addLineForm.serviceId,
      toothSnapshot: this.addLineForm.toothSnapshot || undefined,
      quantity: this.addLineForm.quantity || undefined,
      unitPrice: this.addLineForm.unitPrice ?? undefined,
      discountAmount: this.addLineForm.discountAmount || undefined,
      vatRate: this.addLineForm.vatRate || undefined
    }).subscribe({
      next: () => {
        this.addingLine.set(false);
        this.showAddLine.set(false);
        this.addLineForm = { serviceId: '', toothSnapshot: '', quantity: 1, unitPrice: null, discountAmount: 0, vatRate: 0 };
        this.loadEstimate();
      },
      error: () => { this.addingLine.set(false); this.error.set('Errore nell\'aggiunta della riga'); }
    });
  }

  // ── Delete line ────────────────────────────────────────────────────────────

  deleteLine(lineId: string): void {
    this.estimateService.deleteLine(this.estimateId, lineId).subscribe({
      next: () => { this.deletingLineId.set(null); this.loadEstimate(); },
      error: () => this.error.set('Errore nella rimozione della riga')
    });
  }

  // ── Import from plan ───────────────────────────────────────────────────────

  toggleImportPlan(): void {
    if (this.showImportPlan()) { this.showImportPlan.set(false); return; }
    const planId = this.estimate()?.treatmentPlanId;
    if (!planId) return;
    this.planLoading.set(true);
    this.showImportPlan.set(true);
    this.selectedImportItems.set([]);

    forkJoin({
      plan: this.treatmentPlanService.findById(planId),
      coverage: this.estimateService.getPlanCoverage(planId)
    }).subscribe({
      next: ({ plan, coverage }) => {
        this.linkedPlan.set(plan);
        this.planCoverage.set(coverage);
        this.planLoading.set(false);
        // Pre-select items not yet in this estimate and not covered elsewhere
        const preSelected = plan.items
          .filter(i => i.status !== 'cancelled')
          .filter(i => !this.planItemInEstimate(i.itemId))
          .filter(i => !coverage.some(c => c.planItemId === i.itemId))
          .map(i => i.itemId);
        this.selectedImportItems.set(preSelected);
      },
      error: () => { this.planLoading.set(false); this.error.set('Errore nel caricamento del piano'); }
    });
  }

  planItemInEstimate(itemId: string): boolean {
    return (this.estimate()?.lines ?? []).some(l => l.treatmentPlanItemId === itemId);
  }

  itemCoverageInfo(itemId: string): PlanItemCoverage | undefined {
    return this.planCoverage().find(c => c.planItemId === itemId);
  }

  isItemSelectedForImport(itemId: string): boolean {
    return this.selectedImportItems().includes(itemId);
  }

  toggleImportItemSelection(itemId: string): void {
    const current = this.selectedImportItems();
    if (current.includes(itemId)) {
      this.selectedImportItems.set(current.filter(id => id !== itemId));
    } else {
      this.selectedImportItems.set([...current, itemId]);
    }
  }

  addSelectedPlanItems(): void {
    const plan = this.linkedPlan();
    if (!plan) return;
    const ids = this.selectedImportItems();
    if (ids.length === 0) return;

    this.addingMultiple.set(true);
    const items = plan.items.filter(i => ids.includes(i.itemId));

    from(items).pipe(
      concatMap(item => this.estimateService.addLine(this.estimateId, {
        serviceId: item.serviceId,
        treatmentPlanItemId: item.itemId,
        toothSnapshot: item.toothNumber ?? undefined,
        unitPrice: item.plannedPrice ?? undefined
      }))
    ).subscribe({
      complete: () => {
        this.addingMultiple.set(false);
        this.selectedImportItems.set([]);
        this.loadEstimate();
      },
      error: () => {
        this.addingMultiple.set(false);
        this.error.set('Errore nell\'aggiunta delle prestazioni selezionate');
        this.loadEstimate();
      }
    });
  }

  // ── Delete estimate ────────────────────────────────────────────────────────

  deleteEstimate(): void {
    this.deleting.set(true);
    this.estimateService.delete(this.estimateId).subscribe({
      next: () => this.router.navigate(['/preventivi']),
      error: () => {
        this.deleting.set(false);
        this.confirmDelete.set(false);
        this.error.set('Errore nell\'eliminazione del preventivo');
      }
    });
  }

  // ── Labels / helpers ───────────────────────────────────────────────────────

  statusLabel(status: string): string {
    const map: Record<string, string> = {
      draft: 'Bozza', sent: 'Inviato', accepted: 'Accettato',
      rejected: 'Rifiutato', expired: 'Scaduto', cancelled: 'Annullato'
    };
    return map[status] ?? status;
  }

  statusSelectClass(status: string): string {
    switch (status) {
      case 'sent':     return 'border-blue-300 text-blue-700 bg-blue-50';
      case 'accepted': return 'border-green-300 text-green-700 bg-green-50';
      case 'rejected': return 'border-red-300 text-red-700 bg-red-50';
      case 'expired':  return 'border-orange-300 text-orange-700 bg-orange-50';
      default:         return 'border-slate-300 text-slate-600 bg-slate-50';
    }
  }

  formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
