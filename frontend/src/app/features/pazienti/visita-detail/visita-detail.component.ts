import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../../environments/environment';

interface DiaryEntry {
  entryId: string;
  entryDate: string | null;
  providerName: string;
  toothNumber: string | null;
  serviceName: string | null;
  clinicalNotes: string;
  nextVisitNotes: string | null;
}

@Component({
  selector: 'app-visita-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './visita-detail.component.html'
})
export class VisitaDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly http = inject(HttpClient);

  patientId = signal('');
  entryId = signal('');
  loading = signal(true);
  saving = signal(false);
  error = signal<string | null>(null);

  form = {
    toothNumber: '',
    serviceName: '',
    clinicalNotes: '',
    nextVisitNotes: '',
    materialsUsed: ''
  };

  providerName = signal('');
  entryDate = signal<string | null>(null);

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id') ?? '';
    const eid = this.route.snapshot.paramMap.get('entryId') ?? '';
    this.patientId.set(id);
    this.entryId.set(eid);
    this.loadEntry(id, eid);
  }

  private loadEntry(patientId: string, entryId: string): void {
    this.http.get<DiaryEntry>(
      `${environment.apiBaseUrl}/patients/${patientId}/clinical-record/diary/${entryId}`
    ).subscribe({
      next: (entry) => {
        this.form.toothNumber = entry.toothNumber ?? '';
        this.form.serviceName = entry.serviceName ?? '';
        this.form.clinicalNotes = entry.clinicalNotes ?? '';
        this.form.nextVisitNotes = entry.nextVisitNotes ?? '';
        this.providerName.set(entry.providerName);
        this.entryDate.set(entry.entryDate);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Impossibile caricare la visita');
        this.loading.set(false);
      }
    });
  }

  save(): void {
    if (!this.form.clinicalNotes.trim() || this.saving()) return;
    this.saving.set(true);
    this.error.set(null);
    this.http.put(
      `${environment.apiBaseUrl}/patients/${this.patientId()}/clinical-record/diary/${this.entryId()}`,
      {
        toothNumber: this.form.toothNumber || null,
        serviceName: this.form.serviceName || null,
        clinicalNotes: this.form.clinicalNotes,
        nextVisitNotes: this.form.nextVisitNotes || null,
        materialsUsed: this.form.materialsUsed || null
      }
    ).subscribe({
      next: () => this.router.navigate(['/pazienti', this.patientId()], { queryParams: { tab: 'cartella' } }),
      error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
    });
  }

  formatDate(d: string | null): string {
    if (!d) return '—';
    return new Date(d).toLocaleDateString('it-IT', { day: '2-digit', month: 'long', year: 'numeric' });
  }
}
