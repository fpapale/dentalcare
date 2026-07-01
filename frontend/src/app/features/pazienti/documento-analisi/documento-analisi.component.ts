import { Component, Input, OnDestroy, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeUrl } from '@angular/platform-browser';
import { PatientAnalysisService } from '../../../core/services/patient-analysis.service';
import { PatientDocumentService } from '../../../core/services/patient-document.service';
import { AnalysisLabel, PatientAnalysis, DISEASE_LABELS, quadrantColor } from '../../../core/models/patient-analysis.model';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-documento-analisi',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h3 class="font-bold text-slate-700 flex items-center gap-2">
          <span class="material-symbols-outlined text-[18px] text-teal-600">network_intelligence</span>
          Analisi AI ortopanoramica
        </h3>
        @if (!analysis() || analysis()?.status === 'FAILED') {
          <button (click)="analyze()" [disabled]="busy()"
            class="flex items-center gap-1.5 bg-teal-600 text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-teal-700 disabled:opacity-50">
            <span class="material-symbols-outlined text-[15px]">auto_awesome</span>
            {{ busy() ? 'Avvio...' : 'Analizza con AI' }}
          </button>
        } @else if (analysis()?.status === 'COMPLETED') {
          <button (click)="analyze()" [disabled]="busy()" title="Ri-esegue l'inferenza AI (crea una nuova analisi)"
            class="flex items-center gap-1.5 border border-teal-600 text-teal-700 text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-teal-50 disabled:opacity-50">
            <span class="material-symbols-outlined text-[15px]">refresh</span>
            {{ busy() ? 'Avvio...' : 'Ri-analizza' }}
          </button>
        }
      </div>
      @if (analyzeError()) {
        <p class="text-sm text-red-600">{{ analyzeError() }}</p>
      }

      <p class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
        AI-generated, requires clinician review
      </p>

      @if (analysis()?.status === 'PROCESSING') {
        <div class="flex items-center gap-2 text-sm text-slate-500">
          <span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
          Analisi in corso...
        </div>
      }
      @if (analysis()?.status === 'FAILED') {
        <p class="text-sm text-red-600">Analisi fallita: {{ analysis()?.errorMessage }}</p>
      }

      @if (imageUrl()) {
        <div class="relative inline-block border border-slate-200 rounded-lg overflow-hidden">
          <img #img [src]="imageUrl()" (load)="onImageLoad(img)" class="block max-w-full" alt="Ortopanoramica" />
          @if (analysis()?.status === 'COMPLETED' && natW() > 0) {
            <svg class="absolute inset-0 w-full h-full" [attr.viewBox]="'0 0 ' + natW() + ' ' + natH()" preserveAspectRatio="none">
              @for (l of analysis()!.labels; track l.id) {
                <rect [attr.x]="l.bboxX1" [attr.y]="l.bboxY1"
                      [attr.width]="l.bboxX2 - l.bboxX1" [attr.height]="l.bboxY2 - l.bboxY1"
                      [attr.stroke]="color(l.toothFdi)" stroke-width="3"
                      [attr.fill]="color(l.toothFdi)" fill-opacity="0.2" />
                <text [attr.x]="l.bboxX1" [attr.y]="l.bboxY1 - 4" [attr.fill]="color(l.toothFdi)"
                      font-size="22" font-weight="bold">{{ labelText(l) }}</text>
              }
            </svg>
          }
          <button (click)="fullscreen.set(true)" title="Schermo intero"
            class="absolute top-2 right-2 bg-black/50 hover:bg-black/70 text-white rounded-lg p-1.5">
            <span class="material-symbols-outlined text-[18px]">fullscreen</span>
          </button>
        </div>
      }

      <!-- Overlay schermo intero -->
      @if (fullscreen() && imageUrl()) {
        <div class="fixed inset-0 z-[60] bg-black/90 flex items-center justify-center p-4"
          (click)="fullscreen.set(false)">
          <button (click)="fullscreen.set(false)" title="Chiudi"
            class="absolute top-4 right-4 bg-white/10 hover:bg-white/20 text-white rounded-lg p-2 z-10">
            <span class="material-symbols-outlined">close</span>
          </button>
          <div class="relative max-w-full max-h-full" (click)="$event.stopPropagation()">
            <img [src]="imageUrl()" class="block max-w-full max-h-[92vh] object-contain" alt="Ortopanoramica" />
            @if (analysis()?.status === 'COMPLETED' && natW() > 0) {
              <svg class="absolute inset-0 w-full h-full" [attr.viewBox]="'0 0 ' + natW() + ' ' + natH()" preserveAspectRatio="none">
                @for (l of analysis()!.labels; track l.id) {
                  <rect [attr.x]="l.bboxX1" [attr.y]="l.bboxY1"
                        [attr.width]="l.bboxX2 - l.bboxX1" [attr.height]="l.bboxY2 - l.bboxY1"
                        [attr.stroke]="color(l.toothFdi)" stroke-width="3"
                        [attr.fill]="color(l.toothFdi)" fill-opacity="0.2" />
                  <text [attr.x]="l.bboxX1" [attr.y]="l.bboxY1 - 4" [attr.fill]="color(l.toothFdi)"
                        font-size="22" font-weight="bold">{{ labelText(l) }}</text>
                }
              </svg>
            }
          </div>
        </div>
      }

      @if (analysis()?.status === 'COMPLETED') {
        <!-- Legenda evidenze: testo in chiaro di ciò che i box mostrano -->
        @if (analysis()!.labels.length > 0) {
          <div class="border border-slate-200 rounded-lg p-2 space-y-1 bg-slate-50">
            <p class="text-xs font-bold text-slate-600">Evidenze rilevate</p>
            @for (l of analysis()!.labels; track l.id) {
              <div class="flex items-center gap-2 text-xs text-slate-700">
                <span class="w-3 h-3 rounded-sm border border-slate-300 shrink-0"
                  [style.background-color]="color(l.toothFdi)"></span>
                <span class="font-semibold">{{ l.toothFdi ? 'Dente ' + l.toothFdi : 'Dente n/d' }}</span>
                <span>{{ diseaseLabel(l.disease) }}</span>
                @if (l.diseaseConfidence != null) {
                  <span class="text-slate-400">{{ (l.diseaseConfidence * 100) | number:'1.0-0' }}%</span>
                }
                @if (l.needsReview) {
                  <span class="text-amber-600 font-medium">· da verificare</span>
                }
              </div>
            }
          </div>
        }

        <div class="flex items-center justify-between gap-2">
          <span class="text-xs text-slate-500">{{ analysis()?.detectionsCount }} rilevamenti · stato revisione: {{ analysis()?.reviewStatus }}</span>
          @if (analysis()?.reviewStatus === 'pending') {
            <button (click)="confirm()" [disabled]="busy()"
              class="bg-green-600 text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-green-700 disabled:opacity-50 shrink-0">
              Conferma e sincronizza odontogramma
            </button>
          } @else {
            <button (click)="confirm()" [disabled]="busy()"
              class="flex items-center gap-1 bg-teal-600 text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-teal-700 disabled:opacity-50 shrink-0">
              <span class="material-symbols-outlined text-[15px]">sync</span>
              Risincronizza odontogramma
            </button>
          }
        </div>
      }
    </div>
  `,
})
export class DocumentoAnalisiComponent implements OnInit, OnDestroy {
  @Input({ required: true }) patientId!: string;
  @Input({ required: true }) docId!: string;

  private readonly analysisSvc = inject(PatientAnalysisService);
  private readonly docSvc = inject(PatientDocumentService);
  private readonly sanitizer = inject(DomSanitizer);
  private readonly auth = inject(AuthService);

  readonly analysis = signal<PatientAnalysis | null>(null);
  readonly imageUrl = signal<SafeUrl | null>(null);
  readonly busy = signal(false);
  readonly natW = signal(0);
  readonly natH = signal(0);
  readonly analyzeError = signal<string | null>(null);
  readonly fullscreen = signal(false);

  private blobUrl: string | null = null;
  private es: EventSource | null = null;
  private fallbackTimer: ReturnType<typeof setTimeout> | null = null;

  ngOnInit(): void {
    this.docSvc.getContent(this.patientId, this.docId).subscribe(blob => {
      this.blobUrl = URL.createObjectURL(blob);
      this.imageUrl.set(this.sanitizer.bypassSecurityTrustUrl(this.blobUrl));
    });
    this.analysisSvc.list(this.patientId, this.docId).subscribe(list => {
      const sorted = [...list].sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''));
      if (sorted.length > 0) this.loadAnalysis(sorted[0].id);
    });
  }

  ngOnDestroy(): void {
    if (this.blobUrl) URL.revokeObjectURL(this.blobUrl);
    this.es?.close();
    this.es = null;
    if (this.fallbackTimer) { clearTimeout(this.fallbackTimer); this.fallbackTimer = null; }
  }

  color(tooth: string | null): string { return quadrantColor(tooth); }

  labelText(l: AnalysisLabel): string {
    const d = DISEASE_LABELS[l.disease] ?? l.disease;
    return l.toothFdi ? `${l.toothFdi} ${d}` : `? ${d}`;
  }

  diseaseLabel(disease: string): string {
    return DISEASE_LABELS[disease] ?? disease;
  }

  onImageLoad(img: HTMLImageElement): void {
    this.natW.set(img.naturalWidth);
    this.natH.set(img.naturalHeight);
  }

  analyze(): void {
    this.analyzeError.set(null);
    this.busy.set(true);
    this.analysisSvc.start(this.patientId, this.docId).subscribe({
      next: res => { this.busy.set(false); this.loadAnalysis(res.analysisId); this.subscribeStatus(res.analysisId); },
      error: () => { this.busy.set(false); this.analyzeError.set('Impossibile avviare l\'analisi. Riprova più tardi.'); },
    });
  }

  private subscribeStatus(analysisId: string): void {
    this.es?.close();
    this.es = null;

    if (this.auth.getToken() === null) {
      this.fallbackTimer = setTimeout(() => { if (this.analysis()?.status === 'PROCESSING') this.loadAnalysis(analysisId); }, 8000);
      return;
    }

    this.es = this.analysisSvc.streamStatus(this.patientId, this.docId, analysisId);
    this.es.addEventListener('analysis-status', () => {
      this.loadAnalysis(analysisId);
      this.es?.close();
      this.es = null;
    });
    this.es.addEventListener('error', () => {
      this.es?.close();
      this.es = null;
      if (this.analysis()?.status === 'PROCESSING') this.loadAnalysis(analysisId);
    });
    this.fallbackTimer = setTimeout(() => { if (this.analysis()?.status === 'PROCESSING') this.loadAnalysis(analysisId); }, 8000);
  }

  private loadAnalysis(analysisId: string): void {
    this.analysisSvc.get(this.patientId, this.docId, analysisId).subscribe(a => this.analysis.set(a));
  }

  confirm(): void {
    const a = this.analysis();
    if (!a) return;
    this.busy.set(true);
    this.analysisSvc.review(this.patientId, this.docId, a.id, { reviewStatus: 'reviewed', labels: a.labels }).subscribe({
      next: updated => { this.analysis.set(updated); this.busy.set(false); },
      error: () => { this.busy.set(false); },
    });
  }
}
