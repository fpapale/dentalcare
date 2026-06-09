import { Injectable, signal } from '@angular/core';

export interface AppSettings {
  slotDurationMin: number;
  workStartTime: string;
  workEndTime: string;
  workDays: number[];
  estimateValidityDays: number;
  defaultVatRate: number;
  estimatePrefix: string;
  defaultPaymentMethod: string;
  defaultDueDays: number;
  studioInvoicePrefix: string;
  recallIntervalMonths: number;
  recallSecondIntervalMonths: number;
  recallMessageTemplate: string;
  locale: string;
  dashboardApptPageSize: number;
  chatHistoryDays: number;
}

export const DEFAULT_SETTINGS: AppSettings = {
  slotDurationMin: 30,
  workStartTime: '08:00',
  workEndTime: '19:00',
  workDays: [1, 2, 3, 4, 5],
  estimateValidityDays: 30,
  defaultVatRate: 0,
  estimatePrefix: 'PRV',
  defaultPaymentMethod: 'Bonifico',
  defaultDueDays: 30,
  studioInvoicePrefix: 'FATT',
  recallIntervalMonths: 6,
  recallSecondIntervalMonths: 12,
  recallMessageTemplate: 'Gentile {paziente}, la informiamo che è giunto il momento della sua visita di controllo. La invitiamo a contattarci per fissare un appuntamento. Studio {studio}, tel. {telefono}.',
  locale: 'it',
  dashboardApptPageSize: 6,
  chatHistoryDays: 90,
};

const LS_KEY = 'dentalcare_app_settings';

@Injectable({ providedIn: 'root' })
export class AppSettingsService {
  private readonly _settings = signal<AppSettings>({ ...DEFAULT_SETTINGS });

  readonly settings = this._settings.asReadonly();

  constructor() {
    this.load();
  }

  get(): AppSettings {
    return this._settings();
  }

  save(settings: AppSettings): void {
    this._settings.set({ ...settings });
    localStorage.setItem(LS_KEY, JSON.stringify(settings));
  }

  private load(): void {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (raw) this._settings.set({ ...DEFAULT_SETTINGS, ...JSON.parse(raw) });
    } catch {
      this._settings.set({ ...DEFAULT_SETTINGS });
    }
  }
}
