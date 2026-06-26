import { Component, Input, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
import { PatientDocumentService } from '../../../core/services/patient-document.service';
import {
  DOCUMENT_TYPE_LABELS,
  PatientDocumentSummary,
  UpdatePatientDocumentRequest,
} from '../../../core/models/patient-document.model';

@Component({
  selector: 'app-documenti-tab',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './documenti-tab.component.html',
})
export class DocumentiTabComponent implements OnInit, OnDestroy {
  @Input({ required: true }) patientId!: string;

  private readonly docService = inject(PatientDocumentService);
  private readonly sanitizer = inject(DomSanitizer);

  docs = signal<PatientDocumentSummary[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  showUploadForm = signal(false);
  uploading = signal(false);
  uploadError = signal<string | null>(null);
  pendingFile: File | null = null;
  uploadForm = { title: '', documentType: 'altro', notes: '', takenAt: '' };

  editingDocId = signal<string | null>(null);
  editForm: UpdatePatientDocumentRequest & { takenAt?: string; notes?: string } = { title: '', documentType: 'altro' };
  saving = signal(false);

  previewDoc = signal<PatientDocumentSummary | null>(null);
  previewBlobUrl = signal<string | null>(null);
  previewLoading = signal(false);

  safePdfUrl = computed((): SafeResourceUrl | null => {
    const url = this.previewBlobUrl();
    return url ? this.sanitizer.bypassSecurityTrustResourceUrl(url) : null;
  });

  confirmDeleteId = signal<string | null>(null);

  readonly documentTypes = Object.entries(DOCUMENT_TYPE_LABELS).map(([key, label]) => ({ key, label }));

  ngOnInit(): void { this.load(); }

  ngOnDestroy(): void { this.revokeBlobUrl(); }

  load(): void {
    this.loading.set(true);
    this.error.set(null);
    this.docService.findAll(this.patientId).subscribe({
      next: data => { this.docs.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento documenti'); this.loading.set(false); },
    });
  }

  onFileSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;
    if (file.size > 50 * 1024 * 1024) {
      this.uploadError.set('File troppo grande (max 50 MB)');
      return;
    }
    this.pendingFile = file;
    this.uploadError.set(null);
    if (!this.uploadForm.title) {
      this.uploadForm.title = file.name.replace(/\.[^.]+$/, '');
    }
  }

  submitUpload(): void {
    if (!this.pendingFile || this.uploading()) return;
    if (!this.uploadForm.title.trim()) { this.uploadError.set('Inserisci un titolo'); return; }

    const fd = new FormData();
    fd.append('file', this.pendingFile);
    fd.append('title', this.uploadForm.title.trim());
    fd.append('documentType', this.uploadForm.documentType);
    if (this.uploadForm.notes) fd.append('notes', this.uploadForm.notes);
    if (this.uploadForm.takenAt) fd.append('takenAt', this.uploadForm.takenAt);

    this.uploading.set(true);
    this.docService.upload(this.patientId, fd).subscribe({
      next: () => {
        this.uploading.set(false);
        this.showUploadForm.set(false);
        this.resetUploadForm();
        this.load();
      },
      error: () => { this.uploading.set(false); this.uploadError.set('Errore durante il caricamento'); },
    });
  }

  openPreview(doc: PatientDocumentSummary): void {
    this.revokeBlobUrl();
    this.previewDoc.set(doc);
    this.previewLoading.set(true);
    this.docService.getContent(this.patientId, doc.id).subscribe({
      next: blob => {
        this.previewBlobUrl.set(URL.createObjectURL(blob));
        this.previewLoading.set(false);
      },
      error: () => { this.previewLoading.set(false); },
    });
  }

  closePreview(): void {
    this.revokeBlobUrl();
    this.previewDoc.set(null);
  }

  downloadDoc(doc: PatientDocumentSummary): void {
    this.docService.getContent(this.patientId, doc.id).subscribe({
      next: blob => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = doc.fileName;
        a.click();
        URL.revokeObjectURL(url);
      },
    });
  }

  startEdit(doc: PatientDocumentSummary): void {
    this.editingDocId.set(doc.id);
    this.editForm = {
      title: doc.title,
      documentType: doc.documentType,
      notes: doc.notes ?? '',
      takenAt: doc.takenAt ?? '',
    };
  }

  saveEdit(doc: PatientDocumentSummary): void {
    if (this.saving()) return;
    this.saving.set(true);
    const req: UpdatePatientDocumentRequest = {
      title: this.editForm.title,
      documentType: this.editForm.documentType,
      notes: (this.editForm.notes as string) || undefined,
      takenAt: (this.editForm.takenAt as string) || undefined,
    };
    this.docService.update(this.patientId, doc.id, req).subscribe({
      next: updated => {
        this.docs.update(list => list.map(d => (d.id === doc.id ? updated : d)));
        this.editingDocId.set(null);
        this.saving.set(false);
      },
      error: () => { this.saving.set(false); },
    });
  }

  cancelEdit(): void { this.editingDocId.set(null); }

  confirmDelete(id: string): void { this.confirmDeleteId.set(id); }
  cancelDelete(): void { this.confirmDeleteId.set(null); }

  doDelete(id: string): void {
    this.docService.delete(this.patientId, id).subscribe({
      next: () => {
        this.docs.update(list => list.filter(d => d.id !== id));
        this.confirmDeleteId.set(null);
      },
    });
  }

  isImage(mimeType: string): boolean { return mimeType?.startsWith('image/') ?? false; }
  isPdf(mimeType: string): boolean { return mimeType === 'application/pdf'; }
  typeLabel(type: string): string { return DOCUMENT_TYPE_LABELS[type] ?? type; }

  formatSize(bytes: number | null): string {
    if (!bytes) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  formatDate(iso: string | null): string {
    if (!iso) return '';
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  private revokeBlobUrl(): void {
    const url = this.previewBlobUrl();
    if (url) { URL.revokeObjectURL(url); this.previewBlobUrl.set(null); }
  }

  private resetUploadForm(): void {
    this.pendingFile = null;
    this.uploadForm = { title: '', documentType: 'altro', notes: '', takenAt: '' };
    this.uploadError.set(null);
  }
}
