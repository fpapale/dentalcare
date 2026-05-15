import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { InvoiceService } from '../../core/services/invoice.service';
import { EstimateService } from '../../core/services/estimate.service';
import { ProviderService } from '../../core/services/provider.service';
import { UserContextService } from '../../core/services/user-context.service';
import { Invoice } from '../../core/models/invoice.model';
import { Estimate } from '../../core/models/estimate.model';
import { Provider } from '../../core/models/provider.model';

@Component({
  selector: 'app-fatturazione',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './fatturazione.component.html'
})
export class FatturazioneComponent implements OnInit {
  activeFilter = signal('tutti');
  searchQuery = '';
  invoices = signal<Invoice[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  // New invoice modal
  showNewModal = signal(false);
  acceptedEstimates = signal<Estimate[]>([]);
  providers = signal<Provider[]>([]);
  newForm = {
    estimateId: '',
    issuerType: 'clinic',
    providerId: '',
    documentType: 'fattura',
    dueDate: '',
    notes: '',
    paymentMethod: ''
  };
  creating = signal(false);

  filters = [
    { key: 'tutti', label: 'Tutti' },
    { key: 'draft', label: 'Bozza' },
    { key: 'issued', label: 'Emessa' },
    { key: 'paid', label: 'Pagata' },
    { key: 'cancelled', label: 'Annullata' }
  ];

  documentTypes = [
    { key: 'fattura', label: 'Fattura' },
    { key: 'ricevuta', label: 'Ricevuta' },
    { key: 'parcella', label: 'Parcella' },
    { key: 'nota_credito', label: 'Nota di credito' }
  ];

  constructor(
    private invoiceService: InvoiceService,
    private estimateService: EstimateService,
    private providerService: ProviderService,
    private userContext: UserContextService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    const status = this.activeFilter() === 'tutti' ? undefined : this.activeFilter();
    this.invoiceService.findAll(status).subscribe({
      next: data => { this.invoices.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento fatture'); this.loading.set(false); }
    });
  }

  setFilter(key: string): void {
    this.activeFilter.set(key);
    this.load();
  }

  get filtered(): Invoice[] {
    if (!this.searchQuery) return this.invoices();
    const q = this.searchQuery.toLowerCase();
    return this.invoices().filter(i =>
      i.patientFullName.toLowerCase().includes(q) || i.invoiceNumber.toLowerCase().includes(q)
    );
  }

  get totaleEmesse(): number {
    return this.invoices().filter(i => i.status === 'issued' || i.status === 'paid')
      .reduce((s, i) => s + i.totalAmount, 0);
  }

  get totalePagate(): number {
    return this.invoices().filter(i => i.status === 'paid').reduce((s, i) => s + i.totalAmount, 0);
  }

  get countBozze(): number {
    return this.invoices().filter(i => i.status === 'draft').length;
  }

  openNewModal(): void {
    this.showNewModal.set(true);
    this.estimateService.findAll('accepted').subscribe(data => this.acceptedEstimates.set(data));
    this.providerService.findAll().subscribe(data => this.providers.set(data));
  }

  closeNewModal(): void {
    this.showNewModal.set(false);
    this.newForm = { estimateId: '', issuerType: 'clinic', providerId: '', documentType: 'fattura', dueDate: '', notes: '', paymentMethod: '' };
  }

  onEstimateChange(): void {
    const est = this.acceptedEstimates().find(e => e.estimateId === this.newForm.estimateId);
    if (!est) return;
    if (est.createdByProviderId) {
      this.newForm.issuerType = 'provider';
      this.newForm.providerId = est.createdByProviderId;
    } else {
      this.newForm.issuerType = 'clinic';
      this.newForm.providerId = '';
    }
  }

  createInvoice(): void {
    if (!this.newForm.estimateId) return;
    this.creating.set(true);
    this.invoiceService.createFromEstimate({
      estimateId: this.newForm.estimateId,
      issuerType: this.newForm.issuerType,
      providerId: this.newForm.issuerType === 'provider' && this.newForm.providerId ? this.newForm.providerId : undefined,
      documentType: this.newForm.documentType,
      dueDate: this.newForm.dueDate || undefined,
      notes: this.newForm.notes || undefined,
      paymentMethod: this.newForm.paymentMethod || undefined
    }).subscribe({
      next: id => { this.creating.set(false); this.router.navigate(['/fatturazione', id]); },
      error: () => { this.creating.set(false); this.error.set('Errore nella creazione della fattura'); }
    });
  }

  open(id: string): void {
    this.router.navigate(['/fatturazione', id]);
  }

  statoLabel(s: string): string {
    return { draft: 'Bozza', issued: 'Emessa', paid: 'Pagata', cancelled: 'Annullata' }[s] ?? s;
  }

  statoClass(s: string): string {
    switch (s) {
      case 'draft': return 'bg-slate-100 text-slate-600';
      case 'issued': return 'bg-blue-100 text-blue-700';
      case 'paid': return 'bg-green-100 text-green-700';
      case 'cancelled': return 'bg-red-100 text-red-600';
      default: return 'bg-slate-100 text-slate-600';
    }
  }

  docLabel(d: string): string {
    return { fattura: 'Fattura', ricevuta: 'Ricevuta', parcella: 'Parcella', nota_credito: 'Nota credito' }[d] ?? d;
  }

  formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  initials(name: string): string {
    return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
  }
}
