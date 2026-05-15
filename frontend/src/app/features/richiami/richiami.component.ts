import {
  AfterViewInit,
  Component,
  OnDestroy,
  OnInit,
  TemplateRef,
  ViewChild,
  computed,
  inject,
  signal
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { LayoutService } from '../../core/services/layout.service';
import { RecallService } from '../../core/services/recall.service';
import { PatientService } from '../../core/services/patient.service';
import { PatientListItem } from '../../core/models/patient.model';
import {
  Recall,
  RecallContact,
  CreateRecallContactRequest,
  GenerateRecallsResponse
} from '../../core/models/recall.model';

@Component({
  selector: 'app-richiami',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './richiami.component.html'
})
export class RichiamiComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild('rightPanel') rightPanelTpl!: TemplateRef<unknown>;

  private readonly layout = inject(LayoutService);
  private readonly recallService = inject(RecallService);
  private readonly patientService = inject(PatientService);

  recalls = signal<Recall[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);
  statusFilter = signal<string>('');
  priorityFilter = signal<string>('');
  generating = signal(false);
  generateResult = signal<GenerateRecallsResponse | null>(null);

  showContactModal = signal(false);
  selectedRecall = signal<Recall | null>(null);
  contactForm: { contactType: string; outcome: string; notes: string } = {
    contactType: 'telefono',
    outcome: 'risposto',
    notes: ''
  };
  savingContact = signal(false);

  showNewRecallModal = signal(false);
  newRecallForm: { patientId: string; recallType: string; dueDate: string; priority: string; notes: string } = {
    patientId: '',
    recallType: 'Controllo periodico',
    dueDate: '',
    priority: 'media',
    notes: ''
  };
  savingRecall = signal(false);
  patients = signal<PatientListItem[]>([]);
  patientSearch = signal('');
  readonly filteredPatients = computed(() => {
    const q = this.patientSearch().toLowerCase().trim();
    if (!q) return this.patients();
    return this.patients().filter(p =>
      p.patientFullName.toLowerCase().includes(q) ||
      (p.fiscalCode ?? '').toLowerCase().includes(q)
    );
  });

  updatingStatus = signal<string | null>(null);

  showEditModal = signal(false);
  editingRecall = signal<Recall | null>(null);
  editForm: { recallType: string; dueDate: string; priority: string; notes: string; status: string } = {
    recallType: '', dueDate: '', priority: 'media', notes: '', status: 'da_contattare'
  };
  savingEdit = signal(false);

  showContactsDrawer = signal(false);
  drawerRecall = signal<Recall | null>(null);
  drawerContacts = signal<RecallContact[]>([]);
  loadingContacts = signal(false);

  readonly filteredRecalls = computed(() =>
    this.recalls().filter(r => {
      if (this.statusFilter() && r.status !== this.statusFilter()) return false;
      if (this.priorityFilter() && r.priority !== this.priorityFilter()) return false;
      return true;
    })
  );

  readonly daContattareCount = computed(() =>
    this.recalls().filter(r => r.status === 'da_contattare').length
  );

  readonly contattatoCount = computed(() =>
    this.recalls().filter(r => r.status === 'contattato' || r.status === 'in_attesa').length
  );

  readonly confermatoCount = computed(() =>
    this.recalls().filter(r => r.status === 'confermato').length
  );

  readonly scadutiCount = computed(() =>
    this.recalls().filter(r => this.isOverdue(r.dueDate) && r.status === 'da_contattare').length
  );

  readonly urgentList = computed(() =>
    this.recalls()
      .filter(r => r.priority === 'alta' && r.status === 'da_contattare')
      .slice(0, 5)
  );

  ngOnInit(): void {
    this.loadRecalls();
  }

  ngAfterViewInit(): void {
    this.layout.setRightPanel(this.rightPanelTpl);
  }

  ngOnDestroy(): void {
    this.layout.setRightPanel(null);
  }

  loadRecalls(): void {
    this.loading.set(true);
    this.error.set(null);
    this.recallService.findAll(
      this.statusFilter() || undefined,
      this.priorityFilter() || undefined
    ).subscribe({
      next: data => { this.recalls.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento richiami'); this.loading.set(false); }
    });
  }

  generateRecalls(): void {
    this.generating.set(true);
    this.generateResult.set(null);
    this.recallService.generate(6).subscribe({
      next: result => {
        this.generating.set(false);
        this.generateResult.set(result);
        this.loadRecalls();
        setTimeout(() => this.generateResult.set(null), 4000);
      },
      error: () => {
        this.generating.set(false);
        this.error.set('Errore nella generazione richiami');
      }
    });
  }

  updateStatus(recall: Recall, newStatus: string): void {
    this.updatingStatus.set(recall.recallId);
    this.recallService.update(recall.recallId, { status: newStatus }).subscribe({
      next: updated => {
        this.recalls.update(list => list.map(r => r.recallId === updated.recallId ? updated : r));
        this.updatingStatus.set(null);
      },
      error: () => {
        this.updatingStatus.set(null);
        this.error.set('Errore nell\'aggiornamento stato');
      }
    });
  }

  openContactModal(r: Recall): void {
    this.selectedRecall.set(r);
    this.contactForm = { contactType: 'telefono', outcome: 'risposto', notes: '' };
    this.showContactModal.set(true);
  }

  closeContactModal(): void {
    this.showContactModal.set(false);
    this.selectedRecall.set(null);
  }

  saveContact(): void {
    const r = this.selectedRecall();
    if (!r) return;
    this.savingContact.set(true);
    const req: CreateRecallContactRequest = {
      contactType: this.contactForm.contactType,
      outcome: this.contactForm.outcome,
      notes: this.contactForm.notes || undefined
    };
    this.recallService.addContact(r.recallId, req).subscribe({
      next: () => {
        this.savingContact.set(false);
        this.closeContactModal();
        this.loadRecalls();
      },
      error: () => {
        this.savingContact.set(false);
        this.error.set('Errore nel salvataggio contatto');
      }
    });
  }

  openEditModal(r: Recall): void {
    this.editingRecall.set(r);
    this.editForm = {
      recallType: r.recallType,
      dueDate: r.dueDate,
      priority: r.priority,
      notes: r.notes ?? '',
      status: r.status
    };
    this.showEditModal.set(true);
  }

  closeEditModal(): void {
    this.showEditModal.set(false);
    this.editingRecall.set(null);
  }

  saveEdit(): void {
    const r = this.editingRecall();
    if (!r) return;
    this.savingEdit.set(true);
    this.recallService.update(r.recallId, {
      recallType: this.editForm.recallType,
      dueDate: this.editForm.dueDate,
      priority: this.editForm.priority,
      notes: this.editForm.notes || undefined,
      status: this.editForm.status
    }).subscribe({
      next: updated => {
        this.recalls.update(list => list.map(x => x.recallId === updated.recallId ? updated : x));
        this.savingEdit.set(false);
        this.closeEditModal();
      },
      error: () => {
        this.savingEdit.set(false);
        this.error.set('Errore nel salvataggio');
      }
    });
  }

  openContactsDrawer(r: Recall): void {
    this.drawerRecall.set(r);
    this.showContactsDrawer.set(true);
    this.loadingContacts.set(true);
    this.drawerContacts.set([]);
    this.recallService.findContacts(r.recallId).subscribe({
      next: contacts => { this.drawerContacts.set(contacts); this.loadingContacts.set(false); },
      error: () => { this.loadingContacts.set(false); }
    });
  }

  closeContactsDrawer(): void {
    this.showContactsDrawer.set(false);
    this.drawerRecall.set(null);
    this.drawerContacts.set([]);
  }

  openNewRecallModal(): void {
    this.newRecallForm = { patientId: '', recallType: 'Controllo periodico', dueDate: '', priority: 'media', notes: '' };
    this.patientSearch.set('');
    if (this.patients().length === 0) {
      this.patientService.findAll().subscribe({ next: list => this.patients.set(list) });
    }
    this.showNewRecallModal.set(true);
  }

  closeNewRecallModal(): void {
    this.showNewRecallModal.set(false);
  }

  saveNewRecall(): void {
    if (!this.newRecallForm.patientId || !this.newRecallForm.dueDate) return;
    this.savingRecall.set(true);
    this.recallService.create({
      patientId: this.newRecallForm.patientId,
      recallType: this.newRecallForm.recallType,
      dueDate: this.newRecallForm.dueDate,
      priority: this.newRecallForm.priority || undefined,
      notes: this.newRecallForm.notes || undefined
    }).subscribe({
      next: () => {
        this.savingRecall.set(false);
        this.closeNewRecallModal();
        this.loadRecalls();
      },
      error: () => {
        this.savingRecall.set(false);
        this.error.set('Errore nella creazione del richiamo');
      }
    });
  }

  deleteRecall(id: string): void {
    if (!confirm('Eliminare questo richiamo?')) return;
    this.recallService.delete(id).subscribe({
      next: () => this.loadRecalls(),
      error: () => this.error.set('Errore nell\'eliminazione richiamo')
    });
  }

  initials(name: string): string {
    const parts = name.trim().split(' ');
    if (parts.length === 1) return parts[0][0]?.toUpperCase() ?? '';
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  priorityDotClass(p: string): string {
    switch (p) {
      case 'alta': return 'bg-red-500';
      case 'media': return 'bg-yellow-400';
      default: return 'bg-green-400';
    }
  }

  statusBadgeClass(s: string): string {
    switch (s) {
      case 'da_contattare': return 'bg-red-100 text-red-700';
      case 'contattato': return 'bg-yellow-100 text-yellow-700';
      case 'in_attesa': return 'bg-blue-100 text-blue-700';
      case 'confermato': return 'bg-green-100 text-green-700';
      case 'chiuso': return 'bg-slate-100 text-slate-500';
      case 'annullato': return 'bg-slate-100 text-slate-400 line-through';
      default: return 'bg-slate-100 text-slate-600';
    }
  }

  statusLabel(s: string): string {
    const map: Record<string, string> = {
      da_contattare: 'Da contattare',
      contattato: 'Contattato',
      in_attesa: 'In attesa',
      confermato: 'Confermato',
      chiuso: 'Chiuso',
      annullato: 'Annullato'
    };
    return map[s] ?? s;
  }

  isOverdue(dueDate: string): boolean {
    return new Date(dueDate) < new Date(new Date().toDateString());
  }

  formatDate(iso: string | null): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  daysOverdue(dueDate: string): number {
    const diff = new Date().getTime() - new Date(dueDate).getTime();
    return Math.floor(diff / (1000 * 60 * 60 * 24));
  }

  contactTypeIcon(ct: string): string {
    switch (ct) {
      case 'telefono': return 'phone';
      case 'sms': return 'sms';
      case 'email': return 'email';
      case 'whatsapp': return 'chat';
      default: return 'contact_phone';
    }
  }

  outcomeLabel(o: string): string {
    const map: Record<string, string> = {
      risposto: 'Risposto',
      non_risposto: 'Non risponde',
      messaggio_lasciato: 'Mess. lasciato',
      confermato: 'Confermato',
      rifiutato: 'Rifiutato'
    };
    return map[o] ?? o;
  }

  outcomeBadgeClass(o: string): string {
    switch (o) {
      case 'risposto': return 'bg-blue-100 text-blue-700';
      case 'confermato': return 'bg-green-100 text-green-700';
      case 'rifiutato': return 'bg-red-100 text-red-700';
      case 'non_risposto': return 'bg-slate-100 text-slate-500';
      default: return 'bg-yellow-100 text-yellow-700';
    }
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
