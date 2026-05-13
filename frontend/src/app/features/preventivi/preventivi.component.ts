import { Component, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { EstimateService } from '../../core/services/estimate.service';
import { Estimate } from '../../core/models/estimate.model';

@Component({
  selector: 'app-preventivi',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './preventivi.component.html',
  styleUrl: './preventivi.component.css'
})
export class PreventiviComponent implements OnInit {
  activeFilter = signal<string>('tutti');
  searchQuery = '';
  estimates = signal<Estimate[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  filters = [
    { key: 'tutti', label: 'Tutti' },
    { key: 'draft', label: 'Bozza' },
    { key: 'sent', label: 'Inviato' },
    { key: 'accepted', label: 'Accettato' },
    { key: 'rejected', label: 'Rifiutato' },
    { key: 'expired', label: 'Scaduto' },
  ];

  constructor(private estimateService: EstimateService) {}

  ngOnInit(): void {
    this.loadEstimates();
  }

  loadEstimates(): void {
    this.loading.set(true);
    const status = this.activeFilter() === 'tutti' ? undefined : this.activeFilter();
    this.estimateService.findAll(status).subscribe({
      next: data => { this.estimates.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento preventivi'); this.loading.set(false); }
    });
  }

  setFilter(key: string): void {
    this.activeFilter.set(key);
    this.loadEstimates();
  }

  get filteredEstimates(): Estimate[] {
    if (!this.searchQuery) return this.estimates();
    const q = this.searchQuery.toLowerCase();
    return this.estimates().filter(e =>
      e.patientFullName.toLowerCase().includes(q) || e.estimateNumber.toLowerCase().includes(q)
    );
  }

  get totaleAccettato(): number {
    return this.estimates().filter(e => e.estimateStatus === 'accepted')
      .reduce((s, e) => s + e.totalAmount, 0);
  }

  get totaleInAttesa(): number {
    return this.estimates().filter(e => e.estimateStatus === 'sent')
      .reduce((s, e) => s + e.totalAmount, 0);
  }

  statoLabel(status: string): string {
    const map: Record<string, string> = {
      draft: 'Bozza', sent: 'Inviato', accepted: 'Accettato',
      rejected: 'Rifiutato', expired: 'Scaduto', cancelled: 'Annullato'
    };
    return map[status] ?? status;
  }

  statoClass(status: string): string {
    switch (status) {
      case 'draft':    return 'bg-slate-100 text-slate-600';
      case 'sent':     return 'bg-blue-100 text-blue-700';
      case 'accepted': return 'bg-green-100 text-green-700';
      case 'rejected': return 'bg-red-100 text-red-600';
      case 'expired':  return 'bg-orange-100 text-orange-600';
      default:         return 'bg-slate-100 text-slate-600';
    }
  }

  formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  initials(name: string): string {
    return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
  }
}
