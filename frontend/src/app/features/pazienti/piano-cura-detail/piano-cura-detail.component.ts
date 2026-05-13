import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { ServiceCatalogService } from '../../../core/services/service-catalog.service';
import { ProviderService } from '../../../core/services/provider.service';
import { PatientService } from '../../../core/services/patient.service';
import { TreatmentPlan, TreatmentPlanItem, TreatmentPlanStatus, TreatmentItemStatus } from '../../../core/models/treatment-plan.model';
import { ServiceItem } from '../../../core/models/service.model';
import { Provider } from '../../../core/models/provider.model';

@Component({
  selector: 'app-piano-cura-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './piano-cura-detail.component.html'
})
export class PianoCuraDetailComponent implements OnInit {
  patientId = '';
  planId = '';
  isNew = false;

  plan = signal<TreatmentPlan | null>(null);
  loading = signal(true);
  saving = signal(false);
  error = signal<string | null>(null);

  // New plan form
  newPlanName = 'Piano di cura';
  newPlanDescription = '';

  // Add item form
  showAddItem = signal(false);
  addingItem = signal(false);
  itemForm = {
    serviceId: '',
    providerId: '',
    toothNumber: '',
    quadrant: '',
    plannedDate: '',
    clinicalNotes: '',
    plannedPrice: ''
  };

  services = signal<ServiceItem[]>([]);
  providers = signal<Provider[]>([]);

  // Delete confirm
  deletingItemId = signal<string | null>(null);

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private planService: TreatmentPlanService,
    private serviceCatalogService: ServiceCatalogService,
    private providerService: ProviderService,
    private patientService: PatientService
  ) {}

  ngOnInit(): void {
    this.patientId = this.route.snapshot.paramMap.get('id') ?? '';
    this.planId = this.route.snapshot.paramMap.get('planId') ?? '';
    this.isNew = this.planId === 'nuovo';

    this.serviceCatalogService.findAll().subscribe(data => this.services.set(data));
    this.providerService.findAll().subscribe(data => this.providers.set(data));

    if (this.isNew) {
      this.loading.set(false);
    } else {
      this.loadPlan();
    }
  }

  private loadPlan(): void {
    this.loading.set(true);
    this.planService.findById(this.planId).subscribe({
      next: data => { this.plan.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento del piano'); this.loading.set(false); }
    });
  }

  createPlan(): void {
    if (!this.newPlanName.trim()) return;
    this.saving.set(true);
    this.planService.create(this.patientId, this.newPlanName.trim(), this.newPlanDescription || undefined).subscribe({
      next: id => {
        this.saving.set(false);
        this.router.navigate(['/pazienti', this.patientId, 'piano-cura', id]);
      },
      error: () => { this.saving.set(false); this.error.set('Errore nella creazione del piano'); }
    });
  }

  openAddItem(): void {
    this.itemForm = { serviceId: '', providerId: '', toothNumber: '', quadrant: '', plannedDate: '', clinicalNotes: '', plannedPrice: '' };
    this.showAddItem.set(true);
  }

  cancelAddItem(): void {
    this.showAddItem.set(false);
  }

  onServiceChange(): void {
    const svc = this.services().find(s => s.serviceId === this.itemForm.serviceId);
    if (svc && svc.defaultPrice != null) {
      this.itemForm.plannedPrice = String(svc.defaultPrice);
    }
  }

  submitAddItem(): void {
    if (!this.itemForm.serviceId) return;
    this.addingItem.set(true);
    const payload: any = { serviceId: this.itemForm.serviceId };
    if (this.itemForm.providerId)    payload.providerId    = this.itemForm.providerId;
    if (this.itemForm.toothNumber)   payload.toothNumber   = this.itemForm.toothNumber;
    if (this.itemForm.quadrant)      payload.quadrant      = Number(this.itemForm.quadrant);
    if (this.itemForm.plannedDate)   payload.plannedDate   = this.itemForm.plannedDate;
    if (this.itemForm.clinicalNotes) payload.clinicalNotes = this.itemForm.clinicalNotes;
    if (this.itemForm.plannedPrice)  payload.plannedPrice  = Number(this.itemForm.plannedPrice);

    this.planService.addItem(this.planId, payload).subscribe({
      next: () => { this.addingItem.set(false); this.showAddItem.set(false); this.loadPlan(); },
      error: () => { this.addingItem.set(false); this.error.set('Errore nell\'aggiunta della prestazione'); }
    });
  }

  confirmDeleteItem(itemId: string): void {
    this.deletingItemId.set(itemId);
  }

  deleteItem(itemId: string): void {
    this.planService.deleteItem(this.planId, itemId).subscribe({
      next: () => { this.deletingItemId.set(null); this.loadPlan(); },
      error: () => this.error.set('Errore nella rimozione della prestazione')
    });
  }

  updatePlanStatus(status: string): void {
    this.planService.updateStatus(this.planId, status).subscribe({
      next: () => this.loadPlan(),
      error: () => this.error.set('Errore nell\'aggiornamento dello stato')
    });
  }

  selectedServiceDuration(): number {
    const svc = this.services().find(s => s.serviceId === this.itemForm.serviceId);
    return svc?.durationMinutes ?? 30;
  }

  statusLabel(s: TreatmentPlanStatus | string): string {
    const map: Record<string, string> = {
      draft: 'Bozza', proposed: 'Proposto', accepted: 'Accettato',
      completed: 'Completato', rejected: 'Rifiutato'
    };
    return map[s] ?? s;
  }

  itemStatusLabel(s: TreatmentItemStatus | string): string {
    const map: Record<string, string> = {
      planned: 'Da pianificare', accepted: 'Accettato', scheduled: 'Appuntamento fissato',
      completed: 'Completato', cancelled: 'Annullato'
    };
    return map[s] ?? s;
  }

  itemStatusClass(s: TreatmentItemStatus | string): string {
    switch (s) {
      case 'scheduled':  return 'bg-blue-100 text-blue-700';
      case 'completed':  return 'bg-slate-100 text-slate-500';
      case 'cancelled':  return 'bg-red-100 text-red-700';
      case 'accepted':   return 'bg-green-100 text-green-700';
      default:           return 'bg-yellow-50 text-yellow-700';
    }
  }

  canSchedule(item: TreatmentPlanItem): boolean {
    return item.status === 'planned' || item.status === 'accepted';
  }

  scheduleItem(item: TreatmentPlanItem): void {
    const plan = this.plan();
    if (!plan) return;
    const duration = item.durationMinutes ?? 30;
    this.router.navigate(['/agenda/nuovo'], {
      queryParams: {
        patientId: plan.patientId,
        planId: this.planId,
        planItemId: item.itemId,
        serviceId: item.serviceId,
        duration
      }
    });
  }

  openItemsCount(): number {
    return (this.plan()?.items ?? [])
      .filter(i => i.status !== 'completed' && i.status !== 'cancelled').length;
  }

  totalAmount(): number {
    return (this.plan()?.items ?? [])
      .filter(i => i.status !== 'cancelled')
      .reduce((sum, i) => sum + (i.plannedPrice ?? 0), 0);
  }

  completedAmount(): number {
    return (this.plan()?.items ?? [])
      .filter(i => i.status === 'completed')
      .reduce((sum, i) => sum + (i.plannedPrice ?? 0), 0);
  }
}
