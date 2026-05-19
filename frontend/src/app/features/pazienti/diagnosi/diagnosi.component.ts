import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { DiagnosiService } from '../../../core/services/diagnosi.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { Diagnosi } from '../../../core/models/diagnosi.model';

@Component({
  selector: 'app-diagnosi',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './diagnosi.component.html'
})
export class DiagnosiComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly diagnosiService = inject(DiagnosiService);
  private readonly userContext = inject(UserContextService);

  patientId = signal('');
  diagnosi = signal<Diagnosi[]>([]);
  loading = signal(true);
  showForm = signal(false);
  saving = signal(false);
  error = signal<string | null>(null);

  form = { toothNumber: '', title: '', description: '', icdCode: '' };

  ngOnInit(): void {
    this.patientId.set(this.route.snapshot.paramMap.get('id') ?? '');
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.diagnosiService.findAll(this.patientId()).subscribe({
      next: d => { this.diagnosi.set(d); this.loading.set(false); },
      error: () => this.loading.set(false)
    });
  }

  save(): void {
    if (!this.form.title.trim() || this.saving()) return;
    const providerId = this.userContext.providerId();
    if (!providerId) return;
    this.saving.set(true);
    this.diagnosiService.create(this.patientId(), {
      providerId,
      title: this.form.title.trim(),
      toothNumber: this.form.toothNumber || undefined,
      description: this.form.description || undefined,
      icdCode: this.form.icdCode || undefined
    }).subscribe({
      next: () => {
        this.saving.set(false);
        this.showForm.set(false);
        this.form = { toothNumber: '', title: '', description: '', icdCode: '' };
        this.load();
      },
      error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
    });
  }

  delete(id: string): void {
    if (!confirm('Eliminare questa diagnosi?')) return;
    this.diagnosiService.delete(this.patientId(), id).subscribe({ next: () => this.load() });
  }

  statusLabel(s: string): string {
    return s === 'active' ? 'Attiva' : s === 'resolved' ? 'Risolta' : 'Cronica';
  }

  statusClass(s: string): string {
    return s === 'active' ? 'bg-red-100 text-red-700' :
           s === 'resolved' ? 'bg-green-100 text-green-700' : 'bg-amber-100 text-amber-700';
  }

  formatDate(d: string): string {
    return new Date(d).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
