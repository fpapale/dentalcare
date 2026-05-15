import { Component, Input, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { OdontogramService } from '../../../core/services/odontogram.service';
import { ServiceCatalogService } from '../../../core/services/service-catalog.service';
import { TreatmentPlanService } from '../../../core/services/treatment-plan.service';
import { TreatmentPlanSummary } from '../../../core/models/treatment-plan.model';
import { ServiceItem } from '../../../core/models/service.model';

const TOOTH = 32;
const STEP  = 34;
const PAD   = 6;
const MID   = 10;

const UPPER_Y       = 8;
const UPPER_LABEL_Y = UPPER_Y + TOOTH + 8;
const LOWER_LABEL_Y = 64;
const LOWER_Y       = LOWER_LABEL_Y + 8;

export const SVG_W       = PAD + 8 * STEP + MID + 8 * STEP + PAD;
export const SVG_H       = LOWER_Y + TOOTH + PAD;
export const CHILD_SVG_W = PAD + 5 * STEP + MID + 5 * STEP + PAD;

const Q1 = [18, 17, 16, 15, 14, 13, 12, 11];
const Q2 = [21, 22, 23, 24, 25, 26, 27, 28];
const Q4 = [48, 47, 46, 45, 44, 43, 42, 41];
const Q3 = [31, 32, 33, 34, 35, 36, 37, 38];
const Q5 = [55, 54, 53, 52, 51];
const Q6 = [61, 62, 63, 64, 65];
const Q7 = [71, 72, 73, 74, 75];
const Q8 = [85, 84, 83, 82, 81];

const POLY: Record<string, string> = {
  O:      '9,9 23,9 23,23 9,23',
  top:    '0,0 32,0 23,9 9,9',
  bottom: '0,32 32,32 23,23 9,23',
  left:   '0,0 0,32 9,23 9,9',
  right:  '32,0 32,32 23,23 23,9',
};

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
const WHOLE_CONDITIONS   = ['none', 'crown', 'missing', 'extracted', 'implant',
                             'bridge_pillar', 'bridge_pontic', 'root_canal', 'to_extract'];

const ACTIONABLE = new Set([
  'cavity', 'to_extract', 'root_canal', 'missing',
  'bridge_pillar', 'bridge_pontic', 'crown', 'implant',
]);

const CONDITION_TREATMENT_HINT: Record<string, string | undefined> = {
  cavity:        'Conservativa',
  to_extract:    'Chirurgia',
  root_canal:    'Endodonzia',
  missing:       'Implantologia',
  bridge_pillar: 'Protesi',
  bridge_pontic: 'Protesi',
  crown:         'Protesi',
  implant:       'Implantologia',
};

interface ToothSurface { key: string; points: string; label: string; }
interface ToothCell {
  fdi: number; pos: number; x: number; y: number;
  localLabelY: number; labelAnchorX: number; quadrant: number;
  surfaces: ToothSurface[];
}

interface PianificaItem {
  rowId: string;
  fdi: number;
  condition: string;
  serviceId: string;
  isSuggested: boolean;
  parentRowId?: string;
}

@Component({
  selector: 'app-odontogramma-tab',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './odontogramma-tab.component.html',
})
export class OdontogrammaTabComponent implements OnInit {
  @Input() patientId!: string;

  readonly SVG_W              = SVG_W;
  readonly SVG_H              = SVG_H;
  readonly CHILD_SVG_W        = CHILD_SVG_W;
  readonly CONDITIONS         = CONDITIONS;
  readonly SURFACE_CONDITIONS = SURFACE_CONDITIONS;
  readonly WHOLE_CONDITIONS   = WHOLE_CONDITIONS;
  readonly TOOTH_PATHS        = TOOTH_PATHS;
  readonly TOOTH_POS_KEYS     = [1, 2, 3, 4, 5, 6, 7, 8] as const;
  readonly CONDITION_TREATMENT_HINT = CONDITION_TREATMENT_HINT;

  activeArch  = signal<'adult' | 'child'>('adult');
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

  // Pianifica mode
  pianificaMode          = signal(false);
  pianificaModeType      = signal<'new' | 'existing'>('new');
  pianificaName          = signal('Piano di cura da odontogramma');
  pianificaItems         = signal<PianificaItem[]>([]);
  servicesByFdi          = signal<Map<number, ServiceItem[]>>(new Map());
  servicesLoading        = signal(false);
  creatingPlan           = signal(false);
  planCreatedId          = signal<string | null>(null);
  existingPlans          = signal<TreatmentPlanSummary[]>([]);
  existingPlansLoading   = signal(false);
  selectedExistingPlanId = signal<string>('');

  readonly teeth:      ToothCell[] = this.buildArch([[...Q1], [...Q2]], [[...Q4], [...Q3]], 8);
  readonly childTeeth: ToothCell[] = this.buildArch([[...Q5], [...Q6]], [[...Q8], [...Q7]], 5);

  constructor(
    private readonly odontogramService: OdontogramService,
    private readonly serviceCatalogService: ServiceCatalogService,
    private readonly treatmentPlanService: TreatmentPlanService,
  ) {}

  ngOnInit(): void {
    this.loadOdontogram();
  }

  private loadOdontogram(): void {
    this.loading.set(true);
    this.odontogramService.get(this.patientId).subscribe({
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

  effectiveFill(fdi: number, surfaceKey: string): string {
    const whole = this.conditionMap().get(`${fdi}_WHOLE`);
    if (whole && whole !== 'none') return CONDITIONS[whole]?.fill ?? '#ffffff';
    return CONDITIONS[this.conditionMap().get(`${fdi}_${surfaceKey}`) ?? 'healthy']?.fill ?? '#ffffff';
  }

  surfaceStroke(fdi: number, surfaceKey: string): string {
    return this.selectedFdi() === fdi && this.selectedSurface() === surfaceKey
      ? '#0d9488' : '#cbd5e1';
  }

  wholeCondition(fdi: number): string {
    return this.conditionMap().get(`${fdi}_WHOLE`) ?? 'none';
  }

  isExtracted(fdi: number): boolean { return this.wholeCondition(fdi) === 'extracted'; }
  isMissing(fdi: number):   boolean { return this.wholeCondition(fdi) === 'missing';   }

  wholeIndicatorFill(fdi: number): string {
    const c = this.wholeCondition(fdi);
    return c === 'none' ? '#f1f5f9' : (CONDITIONS[c]?.fill ?? '#f1f5f9');
  }

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
    const fdi     = this.selectedFdi();
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

  save(): void {
    this.saving.set(true);
    const conditions = Array.from(this.conditionMap().entries()).map(([key, condition]) => {
      const us = key.indexOf('_');
      return { toothFdi: Number(key.slice(0, us)), surface: key.slice(us + 1), condition, notes: null };
    });
    this.odontogramService.save(this.patientId, { conditions }).subscribe({
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

  // ── Pianifica ─────────────────────────────────────────────────────────────

  openPianifica(): void {
    const map = this.conditionMap();
    const wholeByFdi = new Map<number, string>();
    const surfaceByFdi = new Map<number, string>();

    for (const [key, condition] of map.entries()) {
      if (!ACTIONABLE.has(condition)) continue;
      const us      = key.indexOf('_');
      const fdi     = Number(key.slice(0, us));
      const surface = key.slice(us + 1);
      if (surface === 'WHOLE') {
        wholeByFdi.set(fdi, condition);
      } else if (!surfaceByFdi.has(fdi)) {
        surfaceByFdi.set(fdi, condition);
      }
    }

    const combined = new Map<number, string>(wholeByFdi);
    for (const [fdi, cond] of surfaceByFdi.entries()) {
      if (!combined.has(fdi)) combined.set(fdi, cond);
    }

    const sourceItems = [...combined.entries()]
      .map(([fdi, condition]) => ({ fdi, condition }))
      .sort((a, b) => a.fdi - b.fdi);

    this.pianificaItems.set([]);
    this.planCreatedId.set(null);
    this.error.set(null);
    this.pianificaModeType.set('new');
    this.selectedExistingPlanId.set('');
    this.pianificaMode.set(true);
    this.servicesLoading.set(true);

    this.existingPlansLoading.set(true);
    this.treatmentPlanService.findByPatient(this.patientId).subscribe({
      next: plans => {
        this.existingPlans.set(plans.filter(p => p.status !== 'completed' && p.status !== 'rejected'));
        this.existingPlansLoading.set(false);
      },
      error: () => this.existingPlansLoading.set(false),
    });

    const uniqueFdis = [...new Set(sourceItems.map(i => i.fdi))];
    const uniqueConditions = [...new Set(sourceItems.map(i => i.condition))];
    const requests: Record<string, ReturnType<typeof this.serviceCatalogService.findAll>> = {};
    for (const fdi of uniqueFdis) requests[`s_${fdi}`] = this.serviceCatalogService.findAll(fdi);
    for (const c of uniqueConditions) requests[`d_${c}`] = this.serviceCatalogService.findConditionDefaults(c);

    forkJoin(requests).subscribe({
      next: (result: Record<string, ServiceItem[]>) => {
        const svcMap = new Map<number, ServiceItem[]>();
        for (const fdi of uniqueFdis) svcMap.set(fdi, result[`s_${fdi}`] ?? []);
        this.servicesByFdi.set(svcMap);

        const rows: PianificaItem[] = [];
        for (const src of sourceItems) {
          const defaults: ServiceItem[] = result[`d_${src.condition}`] ?? [];
          const primaryId = crypto.randomUUID();
          rows.push({ rowId: primaryId, fdi: src.fdi, condition: src.condition,
                      serviceId: defaults[0]?.serviceId ?? '', isSuggested: false });
          for (let i = 1; i < defaults.length; i++) {
            rows.push({ rowId: crypto.randomUUID(), fdi: src.fdi, condition: src.condition,
                        serviceId: defaults[i].serviceId, isSuggested: true, parentRowId: primaryId });
          }
        }
        this.pianificaItems.set(rows);
        this.servicesLoading.set(false);
      },
      error: () => this.servicesLoading.set(false),
    });
  }

  closePianifica(): void {
    this.pianificaMode.set(false);
  }

  updateServiceForRow(rowId: string, serviceId: string): void {
    this.pianificaItems.update(items =>
      items.map(i => i.rowId === rowId ? { ...i, serviceId } : i)
    );
    // remove old suggested children, then load new bundle
    this.pianificaItems.update(items => items.filter(i => i.parentRowId !== rowId));
    if (!serviceId) return;
    this.serviceCatalogService.findBundle(serviceId).subscribe({
      next: bundle => {
        if (!bundle.length) return;
        const row = this.pianificaItems().find(i => i.rowId === rowId);
        if (!row) return;
        const suggested: PianificaItem[] = bundle.map(s => ({
          rowId: crypto.randomUUID(),
          fdi: row.fdi,
          condition: row.condition,
          serviceId: s.serviceId,
          isSuggested: true,
          parentRowId: rowId,
        }));
        const idx = this.pianificaItems().findIndex(i => i.rowId === rowId);
        this.pianificaItems.update(items => [
          ...items.slice(0, idx + 1),
          ...suggested,
          ...items.slice(idx + 1),
        ]);
      },
    });
  }

  removeRow(rowId: string): void {
    this.pianificaItems.update(items =>
      items.filter(i => i.rowId !== rowId && i.parentRowId !== rowId)
    );
  }

  addRowForFdi(fdi: number, condition: string): void {
    const newRow: PianificaItem = { rowId: crypto.randomUUID(), fdi, condition, serviceId: '', isSuggested: false };
    const lastIdx = this.pianificaItems().map((i, idx) => i.fdi === fdi ? idx : -1).filter(x => x >= 0).at(-1) ?? -1;
    this.pianificaItems.update(items => [
      ...items.slice(0, lastIdx + 1),
      newRow,
      ...items.slice(lastIdx + 1),
    ]);
  }

  uniquePianificaFdis(): { fdi: number; condition: string }[] {
    const seen = new Map<number, string>();
    for (const item of this.pianificaItems()) {
      if (!seen.has(item.fdi)) seen.set(item.fdi, item.condition);
    }
    return [...seen.entries()].map(([fdi, condition]) => ({ fdi, condition }));
  }

  rowsForFdi(fdi: number): PianificaItem[] {
    return this.pianificaItems().filter(i => i.fdi === fdi);
  }

  servicesCatForTooth(fdi: number): { category: string; items: ServiceItem[] }[] {
    const svcs = this.servicesByFdi().get(fdi) ?? [];
    const map = new Map<string, ServiceItem[]>();
    for (const s of svcs) {
      const cat = s.category ?? 'Altro';
      if (!map.has(cat)) map.set(cat, []);
      map.get(cat)!.push(s);
    }
    return [...map.entries()]
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([category, items]) => ({ category, items }));
  }

  canCreatePlan(): boolean {
    const items = this.pianificaItems();
    return items.length > 0 &&
           !!this.pianificaName().trim() &&
           items.every(i => !!i.serviceId) &&
           this.uniquePianificaFdis().length > 0;
  }

  createPlanFromOdontogram(): void {
    if (!this.canCreatePlan()) return;
    this.creatingPlan.set(true);
    this.treatmentPlanService.createFromOdontogram({
      patientId: this.patientId,
      name: this.pianificaName(),
      items: this.pianificaItems().map(i => ({
        toothFdi: i.fdi,
        condition: i.condition,
        serviceId: i.serviceId,
        clinicalNotes: i.isSuggested ? 'Aggiunto automaticamente' : undefined,
      })),
    }).subscribe({
      next: (planId: any) => {
        this.creatingPlan.set(false);
        this.planCreatedId.set(String(planId));
      },
      error: () => {
        this.creatingPlan.set(false);
        this.error.set('Errore nella creazione del piano di cura');
      },
    });
  }

  canAddToExistingPlan(): boolean {
    const items = this.pianificaItems();
    return items.length > 0 &&
           !!this.selectedExistingPlanId() &&
           items.every(i => !!i.serviceId);
  }

  addItemsToExistingPlan(): void {
    const planId = this.selectedExistingPlanId();
    if (!this.canAddToExistingPlan() || !planId) return;
    this.creatingPlan.set(true);
    const requests = this.pianificaItems().map(i =>
      this.treatmentPlanService.addItem(planId, {
        serviceId: i.serviceId,
        toothNumber: String(i.fdi),
        quadrant: Math.floor(i.fdi / 10),
        clinicalNotes: i.isSuggested ? 'Aggiunto automaticamente' : undefined,
      })
    );
    forkJoin(requests).subscribe({
      next: () => {
        this.creatingPlan.set(false);
        this.planCreatedId.set(planId);
      },
      error: () => {
        this.creatingPlan.set(false);
        this.error.set('Errore nell\'aggiornamento del piano di cura');
      },
    });
  }
}
