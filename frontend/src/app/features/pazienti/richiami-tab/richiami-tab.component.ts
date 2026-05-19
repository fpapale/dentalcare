import { Component, Input, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RecallService } from '../../../core/services/recall.service';
import { Recall, CreateRecallRequest } from '../../../core/models/recall.model';

@Component({
  selector: 'app-richiami-tab',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './richiami-tab.component.html'
})
export class RichiamiTabComponent implements OnInit {
  @Input({ required: true }) patientId!: string;

  private readonly recallService = inject(RecallService);

  recalls = signal<Recall[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  showNewForm = signal(false);
  saving = signal(false);
  newForm: { recallType: string; dueDate: string; priority: string; notes: string } = {
    recallType: 'Controllo periodico',
    dueDate: '',
    priority: 'media',
    notes: ''
  };

  updatingStatus = signal<string | null>(null);

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    this.recallService.findByPatient(this.patientId).subscribe({
      next: data => { this.recalls.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento richiami'); this.loading.set(false); }
    });
  }

  saveNew(): void {
    if (!this.newForm.dueDate || this.saving()) return;
    this.saving.set(true);
    const req: CreateRecallRequest = {
      patientId: this.patientId,
      recallType: this.newForm.recallType,
      dueDate: this.newForm.dueDate,
      priority: this.newForm.priority || undefined,
      notes: this.newForm.notes || undefined
    };
    this.recallService.create(req).subscribe({
      next: () => {
        this.saving.set(false);
        this.showNewForm.set(false);
        this.newForm = { recallType: 'Controllo periodico', dueDate: '', priority: 'media', notes: '' };
        this.load();
      },
      error: () => { this.error.set('Errore nella creazione del richiamo'); this.saving.set(false); }
    });
  }

  updateStatus(recall: Recall, newStatus: string): void {
    this.updatingStatus.set(recall.recallId);
    this.recallService.update(recall.recallId, { status: newStatus }).subscribe({
      next: updated => {
        this.recalls.update(list => list.map(r => r.recallId === updated.recallId ? updated : r));
        this.updatingStatus.set(null);
      },
      error: () => { this.updatingStatus.set(null); }
    });
  }

  deleteRecall(id: string): void {
    if (!confirm('Eliminare questo richiamo?')) return;
    this.recallService.delete(id).subscribe({ next: () => this.load() });
  }

  statusBadgeClass(s: string): string {
    switch (s) {
      case 'da_contattare': return 'bg-red-100 text-red-700';
      case 'contattato': return 'bg-yellow-100 text-yellow-700';
      case 'in_attesa': return 'bg-blue-100 text-blue-700';
      case 'confermato': return 'bg-green-100 text-green-700';
      case 'chiuso': return 'bg-slate-100 text-slate-500';
      case 'annullato': return 'bg-slate-100 text-slate-400';
      default: return 'bg-slate-100 text-slate-600';
    }
  }

  statusLabel(s: string): string {
    const map: Record<string, string> = {
      da_contattare: 'Da contattare', contattato: 'Contattato',
      in_attesa: 'In attesa', confermato: 'Confermato',
      chiuso: 'Chiuso', annullato: 'Annullato'
    };
    return map[s] ?? s;
  }

  priorityDotClass(p: string): string {
    switch (p) {
      case 'alta': return 'bg-red-500';
      case 'media': return 'bg-yellow-400';
      default: return 'bg-green-400';
    }
  }

  isOverdue(dueDate: string): boolean {
    return new Date(dueDate) < new Date(new Date().toDateString());
  }

  formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  readonly allStatuses = [
    { key: 'da_contattare', label: 'Da contattare' },
    { key: 'contattato', label: 'Contattato' },
    { key: 'in_attesa', label: 'In attesa' },
    { key: 'confermato', label: 'Confermato' },
    { key: 'chiuso', label: 'Chiuso' },
    { key: 'annullato', label: 'Annullato' }
  ];
}
