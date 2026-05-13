import { Component, inject, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { OdontogramService } from '../../../core/services/odontogram.service';
import { PatientService } from '../../../core/services/patient.service';

// ─── Layout constants ─────────────────────────────────────────────────────────
const TOOTH = 32;
const STEP  = 34;    // tooth width + gap
const PAD   = 6;
const MID   = 10;    // midline gap

const UPPER_Y       = 8;
const UPPER_LABEL_Y = UPPER_Y + TOOTH + 8;  // 48 — below upper teeth
const LOWER_LABEL_Y = 64;                    // above lower teeth
const LOWER_Y       = LOWER_LABEL_Y + 8;    // 72

export const SVG_W = PAD + 8 * STEP + MID + 8 * STEP + PAD;  // 570
export const SVG_H = LOWER_Y + TOOTH + PAD;                   // 108

const Q1 = [18, 17, 16, 15, 14, 13, 12, 11];
const Q2 = [21, 22, 23, 24, 25, 26, 27, 28];
const Q4 = [48, 47, 46, 45, 44, 43, 42, 41];
const Q3 = [31, 32, 33, 34, 35, 36, 37, 38];

// Deciduous (primary) teeth — FDI quadrants 5-8
const Q5 = [55, 54, 53, 52, 51];
const Q6 = [61, 62, 63, 64, 65];
const Q7 = [71, 72, 73, 74, 75];
const Q8 = [85, 84, 83, 82, 81];

export const CHILD_SVG_W = PAD + 5 * STEP + MID + 5 * STEP + PAD;

// ─── Surface polygons (32×32 box) ─────────────────────────────────────────────
const POLY: Record<string, string> = {
  O:      '9,9 23,9 23,23 9,23',
  top:    '0,0 32,0 23,9 9,9',
  bottom: '0,32 32,32 23,23 9,23',
  left:   '0,0 0,32 9,23 9,9',
  right:  '32,0 32,32 23,23 23,9',
};

// ─── Tooth silhouette paths (32×32) by position 1–8 from midline ──────────────
// 1=central incisor, 2=lateral incisor, 3=canine, 4-5=premolars, 6-8=molars
const TOOTH_PATHS: Record<number, string> = {
  1: 'M11,0 L21,0 Q23,0 23,2 L23,30 Q23,32 21,32 L11,32 Q9,32 9,30 L9,2 Q9,0 11,0 Z',
  2: 'M12,0 L20,0 Q22,0 22,2 L22,30 Q22,32 20,32 L12,32 Q10,32 10,30 L10,2 Q10,0 12,0 Z',
  3: 'M10,0 L22,0 Q24,0 24,2 L24,30 Q24,32 22,32 L10,32 Q8,32 8,30 L8,2 Q8,0 10,0 Z',
  4: 'M8,0 L24,0 Q26,0 26,2 L26,30 Q26,32 24,32 L8,32 Q6,32 6,30 L6,2 Q6,0 8,0 Z',
  5: 'M8,0 L24,0 Q26,0 26,2 L26,30 Q26,32 24,32 L8,32 Q6,32 6,30 L6,2 Q6,0 8,0 Z',
  6: 'M4,0 L28,0 Q30,0 30,2 L30,30 Q30,32 28,32 L4,32 Q2,32 2,30 L2,2 Q2,0 4,0 Z',
  7: 'M4,0 L28,0 Q30,0 30,2 L30,30 Q30,32 28,32 L4,32 Q2,32 2,30 L2,2 Q2,0 4,0 Z',
  8: 'M5,0 L27,0 Q29,0 29,2 L29,30 Q29,32 27,32 L5,32 Q3,32 3,30 L3,2 Q3,0 5,0 Z',
};

// ─── Conditions palette ───────────────────────────────────────────────────────
export const CONDITIONS: Record<string, { label: string; fill: string; border: string }> = {
  healthy:       { label: 'Sano',              fill: '#ffffff', border: '#cbd5e1' },
  cavity:        { label: 'Carie',             fill: '#ef4444', border: '#b91c1c' },
  filling:       { label: 'Otturazione',       fill: '#60a5fa', border: '#1d4ed8' },
  crown:         { label: 'Corona',            fill: '#fbbf24', border: '#92400e' },
  missing:       { label: 'Mancante',          fill: '#e2e8f0', border: '#94a3b8' },
  extracted:     { label: 'Estratto',          fill: '#94a3b8', border: '#475569' },
  implant:       { label: 'Impianto',          fill: '#a78bfa', border: '#5b21b6' },
  bridge_pillar: { label: 'Bridge (pilastro)', fill: '#34d399', border: '#065f46' },
  bridge_pontic: { label: 'Bridge (pontile)',  fill: '#d1fae5', border: '#065f46' },
  root_canal:    { label: 'Devitalizzato',     fill: '#fb923c', border: '#7c2d12' },
  to_extract:    { label: 'Da estrarre',       fill: '#fca5a5', border: '#991b1b' },
};

const SURFACE_CONDITIONS = ['healthy', 'cavity', 'filling'];
const WHOLE_CONDITIONS    = ['none', 'crown', 'missing', 'extracted', 'implant',
                              'bridge_pillar', 'bridge_pontic', 'root_canal', 'to_extract'];

// ─── Types ────────────────────────────────────────────────────────────────────
interface ToothSurface { key: string; points: string; label: string; }

interface ToothCell {
  fdi: number;
  pos: number;           // 1–8 (adult) or 1–5 (child) from midline
  x: number;
  y: number;
  localLabelY: number;   // label Y in tooth-local coordinates
  labelAnchorX: number;  // center x for label (always 16)
  quadrant: number;      // 1-4 adult, 5-8 deciduous
  surfaces: ToothSurface[];
}

// ─── Component ────────────────────────────────────────────────────────────────
@Component({
  selector: 'app-cartella-clinica',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './cartella-clinica.component.html',
  styleUrl: './cartella-clinica.component.css'
})
export class CartellaClinciComponent implements OnInit {
  private readonly route  = inject(ActivatedRoute);
  private readonly odSvc  = inject(OdontogramService);
  private readonly patSvc = inject(PatientService);

  readonly SVG_W = SVG_W;
  readonly SVG_H = SVG_H;
  readonly CHILD_SVG_W = CHILD_SVG_W;
  readonly CONDITIONS = CONDITIONS;
  readonly SURFACE_CONDITIONS = SURFACE_CONDITIONS;
  readonly WHOLE_CONDITIONS = WHOLE_CONDITIONS;
  readonly TOOTH_PATHS = TOOTH_PATHS;
  readonly TOOTH_POS_KEYS = [1, 2, 3, 4, 5, 6, 7, 8] as const;

  activeTab = signal<'adult' | 'child'>('adult');
  readonly LEGEND_ENTRIES = [
    ['cavity', 'Carie'], ['filling', 'Otturazione'], ['crown', 'Corona'],
    ['missing', 'Mancante'], ['extracted', 'Estratto'], ['implant', 'Impianto'],
    ['bridge_pillar', 'Bridge pil.'], ['bridge_pontic', 'Bridge pont.'],
    ['root_canal', 'Devitalizzato'], ['to_extract', 'Da estrarre'],
  ];

  patientId   = '';
  patientName = signal('');
  loading     = signal(true);
  saving      = signal(false);
  isDirty     = signal(false);
  saveOk      = signal(false);
  error       = signal<string | null>(null);

  conditionMap    = signal<Map<string, string>>(new Map());
  selectedFdi     = signal<number | null>(null);
  selectedSurface = signal<string | null>(null);
  panelX          = signal(0);
  panelY          = signal(0);

  readonly teeth: ToothCell[]      = this.buildArch([[...Q1],[...Q2]], [[...Q4],[...Q3]], 8);
  readonly childTeeth: ToothCell[] = this.buildArch([[...Q5],[...Q6]], [[...Q8],[...Q7]], 5);

  // ─── Lifecycle ──────────────────────────────────────────────────────────────
  ngOnInit(): void {
    this.patientId = this.route.snapshot.paramMap.get('id') ?? '';
    this.patSvc.findById(this.patientId).subscribe({
      next: p => this.patientName.set(p.fullName ?? `${p.firstName} ${p.lastName}`),
      error: () => {}
    });
    this.loadOdontogram();
  }

  private loadOdontogram(): void {
    this.loading.set(true);
    this.odSvc.get(this.patientId).subscribe({
      next: list => {
        const m = new Map<string, string>();
        list.forEach(c => m.set(`${c.toothFdi}_${c.surface}`, c.condition));
        this.conditionMap.set(m);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.error.set('Errore nel caricamento odontogramma');
      }
    });
  }

  // ─── Layout builder ─────────────────────────────────────────────────────────
  private buildArch(upperRows: number[][], lowerRows: number[][], nPerSide: number): ToothCell[] {
    const cells: ToothCell[] = [];
    const addRow = (rows: number[][], toothY: number, labelY: number) => {
      rows.forEach((fdis, ri) => {
        fdis.forEach((fdi, ci) => {
          const q = Math.floor(fdi / 10);
          const x = PAD + ci * STEP + ri * (nPerSide * STEP + MID);
          cells.push({
            fdi, pos: fdi % 10, quadrant: q, x, y: toothY,
            localLabelY: labelY - toothY,
            labelAnchorX: 16,
            surfaces: this.buildSurfaces(q),
          });
        });
      });
    };
    addRow(upperRows, UPPER_Y, UPPER_LABEL_Y);
    addRow(lowerRows, LOWER_Y, LOWER_LABEL_Y);
    return cells;
  }

  private buildSurfaces(q: number): ToothSurface[] {
    const isUpper = q === 1 || q === 2 || q === 5 || q === 6;
    const isLeft  = q === 2 || q === 3 || q === 6 || q === 7;
    return [
      { key: 'O',                 points: POLY['O'],      label: 'Occlusale' },
      { key: isUpper ? 'B' : 'L', points: POLY['top'],    label: isUpper ? 'Vestibolare' : 'Linguale' },
      { key: isUpper ? 'L' : 'B', points: POLY['bottom'], label: isUpper ? 'Palatale' : 'Vestibolare' },
      { key: isLeft  ? 'M' : 'D', points: POLY['left'],   label: isLeft  ? 'Mesiale' : 'Distale' },
      { key: isLeft  ? 'D' : 'M', points: POLY['right'],  label: isLeft  ? 'Distale' : 'Mesiale' },
    ];
  }

  // ─── Rendering helpers ──────────────────────────────────────────────────────
  effectiveFill(fdi: number, surfaceKey: string): string {
    const whole = this.conditionMap().get(`${fdi}_WHOLE`);
    if (whole && whole !== 'none') return CONDITIONS[whole]?.fill ?? '#ffffff';
    const cond = this.conditionMap().get(`${fdi}_${surfaceKey}`) ?? 'healthy';
    return CONDITIONS[cond]?.fill ?? '#ffffff';
  }

  surfaceStroke(fdi: number, surfaceKey: string): string {
    return this.selectedFdi() === fdi && this.selectedSurface() === surfaceKey
      ? '#0d9488' : '#cbd5e1';
  }

  wholeCondition(fdi: number): string {
    return this.conditionMap().get(`${fdi}_WHOLE`) ?? 'none';
  }

  isExtracted(fdi: number): boolean { return this.wholeCondition(fdi) === 'extracted'; }
  isMissing(fdi: number): boolean   { return this.wholeCondition(fdi) === 'missing';   }

  wholeIndicatorFill(fdi: number): string {
    const c = this.wholeCondition(fdi);
    return c === 'none' ? '#f1f5f9' : (CONDITIONS[c]?.fill ?? '#f1f5f9');
  }

  // ─── Interaction ────────────────────────────────────────────────────────────
  onSurfaceClick(fdi: number, surfaceKey: string, event: MouseEvent): void {
    event.stopPropagation();
    this.selectedFdi.set(fdi);
    this.selectedSurface.set(surfaceKey);
    this.panelX.set(event.clientX);
    this.panelY.set(event.clientY);
  }

  onWholeClick(fdi: number, event: MouseEvent): void {
    event.stopPropagation();
    this.selectedFdi.set(fdi);
    this.selectedSurface.set('WHOLE');
    this.panelX.set(event.clientX);
    this.panelY.set(event.clientY);
  }

  setCondition(condition: string): void {
    const fdi = this.selectedFdi();
    const surface = this.selectedSurface();
    if (fdi === null || !surface) return;
    const map = new Map(this.conditionMap());
    if (condition === 'healthy' || condition === 'none') {
      map.delete(`${fdi}_${surface}`);
    } else {
      map.set(`${fdi}_${surface}`, condition);
    }
    this.conditionMap.set(map);
    this.isDirty.set(true);
    this.closePanel();
  }

  closePanel(): void {
    this.selectedFdi.set(null);
    this.selectedSurface.set(null);
  }

  panelConditions(): string[] {
    return this.selectedSurface() === 'WHOLE' ? WHOLE_CONDITIONS : SURFACE_CONDITIONS;
  }

  panelCurrentCondition(): string {
    const fdi = this.selectedFdi();
    const s   = this.selectedSurface();
    if (fdi === null || !s) return 'healthy';
    return this.conditionMap().get(`${fdi}_${s}`) ?? (s === 'WHOLE' ? 'none' : 'healthy');
  }

  // ─── Save ───────────────────────────────────────────────────────────────────
  save(): void {
    this.saving.set(true);
    const conditions = Array.from(this.conditionMap().entries()).map(([key, condition]) => {
      const us = key.indexOf('_');
      return { toothFdi: Number(key.slice(0, us)), surface: key.slice(us + 1), condition, notes: null };
    });
    this.odSvc.save(this.patientId, { conditions }).subscribe({
      next: () => {
        this.saving.set(false);
        this.isDirty.set(false);
        this.saveOk.set(true);
        setTimeout(() => this.saveOk.set(false), 2500);
      },
      error: () => {
        this.saving.set(false);
        this.error.set('Errore nel salvataggio');
      }
    });
  }
}
