import { Component, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { PatientService } from '../../core/services/patient.service';
import { UserContextService } from '../../core/services/user-context.service';
import { PatientListItem } from '../../core/models/patient.model';

@Component({
  selector: 'app-pazienti',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './pazienti.component.html',
  styleUrl: './pazienti.component.css'
})
export class PazientiComponent {
  private readonly patientService = inject(PatientService);
  private readonly userContext = inject(UserContextService);

  searchQuery = '';
  activeFilter = signal<'tutti' | 'attivi' | 'archiviati'>('tutti');
  patients = signal<PatientListItem[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  constructor() {
    effect(() => {
      const providerId = this.userContext.providerId();
      this.userContext.role(); // track secretary switch
      this.loadPatients(providerId);
    });
  }

  loadPatients(providerId?: string | null): void {
    this.loading.set(true);
    this.error.set(null);
    this.patientService.findAll(this.searchQuery || undefined, providerId).subscribe({
      next: data => { this.patients.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento pazienti'); this.loading.set(false); }
    });
  }

  onSearch(): void {
    this.loadPatients(this.userContext.providerId());
  }

  get filteredPatients(): PatientListItem[] {
    const f = this.activeFilter();
    const all = this.patients();
    if (f === 'attivi') return all.filter(p => p.active);
    if (f === 'archiviati') return all.filter(p => !p.active);
    return all;
  }

  setFilter(f: 'tutti' | 'attivi' | 'archiviati'): void {
    this.activeFilter.set(f);
  }

  initials(p: PatientListItem): string {
    return `${p.firstName?.[0] ?? ''}${p.lastName?.[0] ?? ''}`.toUpperCase();
  }

  avatarColor(p: PatientListItem): string {
    const colors = ['bg-teal-100 text-teal-700', 'bg-blue-100 text-blue-700',
                    'bg-purple-100 text-purple-700', 'bg-orange-100 text-orange-700'];
    const idx = (p.patientFullName.charCodeAt(0) || 0) % colors.length;
    return colors[idx];
  }

  stripeColor(p: PatientListItem): string {
    const colors = ['bg-teal-400', 'bg-blue-400', 'bg-purple-400', 'bg-orange-400'];
    const idx = (p.patientFullName.charCodeAt(0) || 0) % colors.length;
    return colors[idx];
  }

  deletePatient(p: PatientListItem): void {
    if (!confirm(`Eliminare definitivamente ${p.patientFullName}? L'operazione è irreversibile.`)) {
      return;
    }
    this.patientService.delete(p.patientId).subscribe({
      next: () => this.loadPatients(this.userContext.providerId()),
      error: (err: { error?: { message?: string } }) => {
        const msg = err.error?.message ?? 'Impossibile eliminare il paziente.';
        alert(msg);
      }
    });
  }

  archivePatient(p: PatientListItem): void {
    if (!confirm(`Archiviare ${p.patientFullName}? Il paziente non apparirà più nella lista attivi.`)) return;
    this.patientService.archive(p.patientId).subscribe({
      next: () => this.loadPatients(this.userContext.providerId()),
      error: () => alert('Impossibile archiviare il paziente.')
    });
  }

  restorePatient(p: PatientListItem): void {
    this.patientService.restore(p.patientId).subscribe({
      next: () => this.loadPatients(this.userContext.providerId()),
      error: () => alert('Impossibile ripristinare il paziente.')
    });
  }
}
