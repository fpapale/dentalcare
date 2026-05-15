import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { InvoiceService } from '../../../core/services/invoice.service';
import { InvoiceDetail, InvoiceLine } from '../../../core/models/invoice.model';

@Component({
  selector: 'app-fattura-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './fattura-detail.component.html'
})
export class FatturaDetailComponent implements OnInit {
  invoiceId = '';
  invoice = signal<InvoiceDetail | null>(null);
  loading = signal(true);
  error = signal<string | null>(null);

  // Edit header
  editingHeader = signal(false);
  savingHeader = signal(false);
  headerForm = { documentType: '', invoiceDate: '', dueDate: '', notes: '', paymentMethod: '' };

  // Add line
  showAddLine = signal(false);
  addingLine = signal(false);
  addLineForm = { description: '', toothInfo: '', quantity: 1, unitPrice: 0, discountAmount: 0, vatRate: 0 };

  // Delete
  deletingLineId = signal<string | null>(null);
  confirmDelete = signal(false);
  deleting = signal(false);

  // Status
  changingStatus = signal(false);

  documentTypes = [
    { key: 'fattura', label: 'Fattura' },
    { key: 'ricevuta', label: 'Ricevuta' },
    { key: 'parcella', label: 'Parcella' },
    { key: 'nota_credito', label: 'Nota di credito' }
  ];

  paymentMethods = ['Contanti', 'Bonifico', 'Carta di credito', 'Assegno'];

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private invoiceService: InvoiceService
  ) {}

  ngOnInit(): void {
    this.invoiceId = this.route.snapshot.paramMap.get('invoiceId') ?? '';
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.invoiceService.findById(this.invoiceId).subscribe({
      next: data => { this.invoice.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento fattura'); this.loading.set(false); }
    });
  }

  // Header edit
  startEdit(): void {
    const inv = this.invoice();
    if (!inv) return;
    this.headerForm = {
      documentType: inv.documentType,
      invoiceDate: inv.invoiceDate,
      dueDate: inv.dueDate ?? '',
      notes: inv.notes ?? '',
      paymentMethod: inv.paymentMethod ?? ''
    };
    this.editingHeader.set(true);
  }

  saveHeader(): void {
    this.savingHeader.set(true);
    this.invoiceService.update(this.invoiceId, {
      documentType: this.headerForm.documentType,
      invoiceDate: this.headerForm.invoiceDate || undefined,
      dueDate: this.headerForm.dueDate || undefined,
      notes: this.headerForm.notes || undefined,
      paymentMethod: this.headerForm.paymentMethod || undefined
    }).subscribe({
      next: () => { this.savingHeader.set(false); this.editingHeader.set(false); this.load(); },
      error: () => this.savingHeader.set(false)
    });
  }

  // Status
  changeStatus(status: string): void {
    this.changingStatus.set(true);
    this.invoiceService.updateStatus(this.invoiceId, status).subscribe({
      next: () => { this.changingStatus.set(false); this.load(); },
      error: () => this.changingStatus.set(false)
    });
  }

  // Lines
  addLine(): void {
    if (!this.addLineForm.description.trim()) return;
    this.addingLine.set(true);
    this.invoiceService.addLine(this.invoiceId, {
      description: this.addLineForm.description.trim(),
      toothInfo: this.addLineForm.toothInfo || undefined,
      quantity: this.addLineForm.quantity,
      unitPrice: this.addLineForm.unitPrice,
      discountAmount: this.addLineForm.discountAmount || 0,
      vatRate: this.addLineForm.vatRate || 0
    }).subscribe({
      next: () => {
        this.addingLine.set(false);
        this.showAddLine.set(false);
        this.addLineForm = { description: '', toothInfo: '', quantity: 1, unitPrice: 0, discountAmount: 0, vatRate: 0 };
        this.load();
      },
      error: () => this.addingLine.set(false)
    });
  }

  deleteLine(lineId: string): void {
    this.deletingLineId.set(lineId);
    this.invoiceService.deleteLine(this.invoiceId, lineId).subscribe({
      next: () => { this.deletingLineId.set(null); this.load(); },
      error: () => this.deletingLineId.set(null)
    });
  }

  // Delete invoice
  doDelete(): void {
    this.deleting.set(true);
    this.invoiceService.delete(this.invoiceId).subscribe({
      next: () => this.router.navigate(['/fatturazione']),
      error: () => { this.deleting.set(false); this.error.set('Impossibile eliminare la fattura'); }
    });
  }

  // Print
  print(): void { window.print(); }

  // Email
  emailLink(): string {
    const inv = this.invoice();
    if (!inv || !inv.patientEmail) return '';
    const subject = encodeURIComponent(`${this.docLabel(inv.documentType)} ${inv.invoiceNumber}`);
    const body = encodeURIComponent(`Gentile ${inv.patientFullName},\n\nIn allegato ${this.docLabel(inv.documentType).toLowerCase()} n° ${inv.invoiceNumber} del ${this.formatDate(inv.invoiceDate)} per un importo di € ${inv.totalAmount.toFixed(2)}.\n\nCordiali saluti`);
    return `mailto:${inv.patientEmail}?subject=${subject}&body=${body}`;
  }

  // Helpers
  isDraft(): boolean { return this.invoice()?.status === 'draft'; }
  isIssued(): boolean { return this.invoice()?.status === 'issued'; }

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
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'long', year: 'numeric' });
  }

  lineTotal(l: InvoiceLine): number { return l.lineTotal; }
}
