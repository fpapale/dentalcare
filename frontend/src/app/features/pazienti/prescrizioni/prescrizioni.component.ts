import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { PrescrizioneService } from '../../../core/services/prescrizione.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { Prescrizione } from '../../../core/models/prescrizione.model';

@Component({
  selector: 'app-prescrizioni',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './prescrizioni.component.html'
})
export class PrescrizioniComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly prescrizioneService = inject(PrescrizioneService);
  private readonly userContext = inject(UserContextService);

  patientId = signal('');
  prescrizioni = signal<Prescrizione[]>([]);
  loading = signal(true);
  showForm = signal(false);
  saving = signal(false);
  error = signal<string | null>(null);

  form = {
    drugName: '',
    dosage: '',
    frequency: '',
    duration: '',
    expiresAt: '',
    notes: ''
  };

  ngOnInit(): void {
    this.patientId.set(this.route.snapshot.paramMap.get('id') ?? '');
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.prescrizioneService.findAll(this.patientId()).subscribe({
      next: d => { this.prescrizioni.set(d); this.loading.set(false); },
      error: () => this.loading.set(false)
    });
  }

  save(): void {
    if (!this.form.drugName.trim() || this.saving()) return;
    const providerId = this.userContext.providerId();
    if (!providerId) return;
    this.saving.set(true);
    this.prescrizioneService.create(this.patientId(), {
      providerId,
      drugName: this.form.drugName.trim(),
      dosage: this.form.dosage || undefined,
      frequency: this.form.frequency || undefined,
      duration: this.form.duration || undefined,
      expiresAt: this.form.expiresAt || undefined,
      notes: this.form.notes || undefined
    }).subscribe({
      next: () => {
        this.saving.set(false);
        this.showForm.set(false);
        this.form = { drugName: '', dosage: '', frequency: '', duration: '', expiresAt: '', notes: '' };
        this.load();
      },
      error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
    });
  }

  delete(id: string): void {
    if (!confirm('Eliminare questa prescrizione?')) return;
    this.prescrizioneService.delete(this.patientId(), id).subscribe({ next: () => this.load() });
  }

  formatDate(d: string | null): string {
    if (!d) return '';
    return new Date(d).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
