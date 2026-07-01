import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { DiagnosiService } from '../../../core/services/diagnosi.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { PatientDocumentService } from '../../../core/services/patient-document.service';
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
  private readonly docService = inject(PatientDocumentService);

  patientId = signal('');
  diagnosi = signal<Diagnosi[]>([]);
  loading = signal(true);
  showForm = signal(false);
  saving = signal(false);
  error = signal<string | null>(null);
  editingId = signal<string | null>(null);

  form = { toothNumber: '', title: '', description: '', icdCode: '' };
  pendingFile: File | null = null;

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

  startEdit(d: Diagnosi): void {
    this.form = {
      toothNumber: d.toothNumber ?? '',
      title: d.title,
      description: d.description ?? '',
      icdCode: d.icdCode ?? ''
    };
    this.editingId.set(d.id);
    this.showForm.set(true);
  }

  cancelForm(): void {
    this.showForm.set(false);
    this.editingId.set(null);
    this.error.set(null);
    this.form = { toothNumber: '', title: '', description: '', icdCode: '' };
    this.pendingFile = null;
  }

  onFileSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;
    if (file.size > 50 * 1024 * 1024) {
      this.error.set('File troppo grande (max 50 MB)');
      return;
    }
    this.pendingFile = file;
    this.error.set(null);
  }

  save(): void {
    if (!this.form.title.trim() || this.saving()) return;
    const editingId = this.editingId();
    this.saving.set(true);

    if (editingId) {
      this.diagnosiService.update(this.patientId(), editingId, {
        title: this.form.title.trim(),
        toothNumber: this.form.toothNumber || undefined,
        description: this.form.description || undefined,
        icdCode: this.form.icdCode || undefined
      }).subscribe({
        next: () => this.afterSave(),
        error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
      });
      return;
    }

    const providerId = this.userContext.providerId();
    if (!providerId) { this.saving.set(false); return; }
    this.diagnosiService.create(this.patientId(), {
      providerId,
      title: this.form.title.trim(),
      toothNumber: this.form.toothNumber || undefined,
      description: this.form.description || undefined,
      icdCode: this.form.icdCode || undefined
    }).subscribe({
      next: () => this.afterSave(),
      error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
    });
  }

  private afterSave(): void {
    const title = this.form.title.trim();
    const description = this.form.description;
    const pendingFile = this.pendingFile;

    this.saving.set(false);
    this.showForm.set(false);
    this.editingId.set(null);
    this.form = { toothNumber: '', title: '', description: '', icdCode: '' };
    this.pendingFile = null;

    if (!pendingFile) { this.load(); return; }

    const fd = new FormData();
    fd.append('file', pendingFile);
    fd.append('title', `Diagnosi: ${title}`);
    fd.append('documentType', 'referto');
    if (description) fd.append('notes', description);

    this.docService.upload(this.patientId(), fd).subscribe({
      next: () => this.load(),
      error: () => { this.error.set('Diagnosi salvata, ma il documento non è stato caricato'); this.load(); }
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
