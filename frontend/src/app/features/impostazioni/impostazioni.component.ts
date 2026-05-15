import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ClinicSettingsService } from '../../core/services/clinic-settings.service';
import { ProviderService } from '../../core/services/provider.service';
import { ClinicBilling } from '../../core/models/clinic-billing.model';
import { Provider } from '../../core/models/provider.model';

export interface AppSettings {
  // Agenda
  slotDurationMin: number;
  workStartTime: string;
  workEndTime: string;
  workDays: number[];
  // Preventivi
  estimateValidityDays: number;
  defaultVatRate: number;
  estimatePrefix: string;
  // Fatturazione
  defaultPaymentMethod: string;
  defaultDueDays: number;
  studioInvoicePrefix: string;
  // Richiami
  recallIntervalMonths: number;
  recallSecondIntervalMonths: number;
  recallMessageTemplate: string;
}

const DEFAULT_SETTINGS: AppSettings = {
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
  recallMessageTemplate: 'Gentile {paziente}, la informiamo che è giunto il momento della sua visita di controllo. La invitiamo a contattarci per fissare un appuntamento. Studio {studio}, tel. {telefono}.'
};

const LS_KEY = 'dentalcare_app_settings';

@Component({
  selector: 'app-impostazioni',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './impostazioni.component.html'
})
export class ImpostazioniComponent implements OnInit {
  activeTab = signal<'studio' | 'professionisti' | 'agenda' | 'preventivi' | 'fatturazione' | 'richiami'>('studio');

  clinic = signal<ClinicBilling | null>(null);
  clinicForm: Partial<ClinicBilling> = {};
  loadingClinic = signal(true);
  savingClinic = signal(false);
  clinicSaved = signal(false);

  providers = signal<Provider[]>([]);
  selectedProvider = signal<Provider | null>(null);
  billingForm: Partial<Provider> = {};
  loadingProviders = signal(true);
  savingProvider = signal(false);
  providerSaved = signal(false);

  appSettings: AppSettings = { ...DEFAULT_SETTINGS };
  appSettingsSaved = signal(false);

  readonly slotOptions = [
    { value: 15, label: '15 minuti' },
    { value: 20, label: '20 minuti' },
    { value: 30, label: '30 minuti' },
    { value: 60, label: '60 minuti' }
  ];

  readonly dayLabels = ['Dom', 'Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab'];

  readonly paymentMethods = ['Contanti', 'Bonifico', 'Carta di credito', 'Assegno', 'RID/SDD'];

  readonly vatRates = [0, 4, 5, 10, 22];

  tabs = [
    { key: 'studio', icon: 'business', label: 'Studio' },
    { key: 'professionisti', icon: 'badge', label: 'Professionisti' },
    { key: 'agenda', icon: 'event', label: 'Agenda' },
    { key: 'preventivi', icon: 'description', label: 'Preventivi' },
    { key: 'fatturazione', icon: 'receipt_long', label: 'Fatturazione' },
    { key: 'richiami', icon: 'notifications_active', label: 'Richiami' },
  ] as const;

  constructor(
    private clinicService: ClinicSettingsService,
    private providerService: ProviderService
  ) {}

  ngOnInit(): void {
    this.clinicService.get().subscribe({
      next: c => { this.clinic.set(c); this.clinicForm = { ...c }; this.loadingClinic.set(false); },
      error: () => this.loadingClinic.set(false)
    });
    this.providerService.findAll(false).subscribe({
      next: list => { this.providers.set(list); this.loadingProviders.set(false); },
      error: () => this.loadingProviders.set(false)
    });
    this.loadAppSettings();
  }

  private loadAppSettings(): void {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (raw) this.appSettings = { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    } catch { this.appSettings = { ...DEFAULT_SETTINGS }; }
  }

  saveClinic(): void {
    this.savingClinic.set(true);
    this.clinicService.update(this.clinicForm).subscribe({
      next: () => { this.savingClinic.set(false); this.clinicSaved.set(true); setTimeout(() => this.clinicSaved.set(false), 2500); },
      error: () => this.savingClinic.set(false)
    });
  }

  selectProvider(p: Provider): void {
    this.selectedProvider.set(p);
    this.billingForm = {
      vatNumber: p.vatNumber, fiscalCode: p.fiscalCode,
      professionalRegister: p.professionalRegister, registerNumber: p.registerNumber,
      billingAddressStreet: p.billingAddressStreet, billingAddressZip: p.billingAddressZip,
      billingAddressCity: p.billingAddressCity, billingAddressProvince: p.billingAddressProvince,
      billingPec: p.billingPec, billingIban: p.billingIban,
      billingSdiCode: p.billingSdiCode, invoicePrefix: p.invoicePrefix
    };
    this.providerSaved.set(false);
  }

  saveProviderBilling(): void {
    const p = this.selectedProvider();
    if (!p) return;
    this.savingProvider.set(true);
    this.providerService.updateBilling(p.providerId, this.billingForm).subscribe({
      next: () => {
        this.savingProvider.set(false);
        this.providerSaved.set(true);
        setTimeout(() => this.providerSaved.set(false), 2500);
        const updated = { ...p, ...this.billingForm } as Provider;
        this.selectedProvider.set(updated);
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
      },
      error: () => this.savingProvider.set(false)
    });
  }

  saveAppSettings(): void {
    localStorage.setItem(LS_KEY, JSON.stringify(this.appSettings));
    this.appSettingsSaved.set(true);
    setTimeout(() => this.appSettingsSaved.set(false), 2500);
  }

  isWorkDay(d: number): boolean {
    return this.appSettings.workDays.includes(d);
  }

  toggleWorkDay(d: number): void {
    const days = this.appSettings.workDays;
    this.appSettings.workDays = days.includes(d) ? days.filter(x => x !== d) : [...days, d].sort();
  }

  roleLabel(role: string): string {
    const r = role.toLowerCase();
    if (r.includes('igien') || r.includes('hygien')) return 'Igienista';
    if (r.includes('admin')) return 'Amministratore';
    return 'Dentista';
  }
}
