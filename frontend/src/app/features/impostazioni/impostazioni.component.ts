import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ClinicSettingsService } from '../../core/services/clinic-settings.service';
import { ProviderService } from '../../core/services/provider.service';
import { AnamnesisCatalogService } from '../../core/services/anamnesis-catalog.service';
import { ClinicBilling } from '../../core/models/clinic-billing.model';
import { Provider, CreateProviderRequest, UpdateProviderProfileRequest } from '../../core/models/provider.model';
import {
  CatalogCategory,
  CatalogItem,
  UpdateCatalogCategoryRequest,
  UpdateCatalogItemRequest
} from '../../core/models/anamnesis-catalog.model';

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
  recallMessageTemplate: 'Gentile {paziente}, la informiamo che è giunto il momento della sua visita di controllo. La invitiamo a contattarci per fissare un appuntamento. Studio {studio}, tel. {telefono}.',
  locale: 'it'
};

const LS_KEY = 'dentalcare_app_settings';

@Component({
  selector: 'app-impostazioni',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './impostazioni.component.html'
})
export class ImpostazioniComponent implements OnInit {
  activeTab = signal<'studio' | 'professionisti' | 'anagrafiche' | 'agenda' | 'preventivi' | 'fatturazione' | 'richiami' | 'sistema'>('studio');

  // ── Studio (Clinic) ────────────────────────────────────────────────────────
  clinic = signal<ClinicBilling | null>(null);
  clinicForm: Partial<ClinicBilling> = {};
  loadingClinic = signal(true);
  savingClinic = signal(false);
  clinicSaved = signal(false);

  // ── Professionisti ─────────────────────────────────────────────────────────
  providers = signal<Provider[]>([]);
  selectedProvider = signal<Provider | null>(null);
  loadingProviders = signal(true);
  savingProvider = signal(false);
  providerSaved = signal(false);
  deletingProvider = signal(false);

  profileForm: UpdateProviderProfileRequest = {
    firstName: '', lastName: '', role: 'dentist', phone: '', email: '', active: true
  };

  billingForm: Partial<Provider> = {};

  showNewProvider = signal(false);
  creatingProvider = signal(false);
  newProviderForm: CreateProviderRequest = {
    firstName: '', lastName: '', role: 'dentist', phone: '', email: ''
  };

  // ── Anagrafiche ────────────────────────────────────────────────────────────
  anagraficaSubTab = signal<'centri' | 'anamnesi'>('centri');

  clinics = signal<ClinicBilling[]>([]);
  loadingClinics = signal(false);
  selectedClinic = signal<ClinicBilling | null>(null);
  showNewClinic = signal(false);
  creatingClinic = signal(false);
  newClinicForm: Partial<ClinicBilling> = { name: '' };
  savingClinicEdit = signal(false);
  clinicEditSaved = signal(false);
  clinicEditForm: Partial<ClinicBilling> = {};

  // ── Anamnesi Catalog ───────────────────────────────────────────────────────
  anamnesisCategories = signal<CatalogCategory[]>([]);
  selectedAnamnesisCategory = signal<CatalogCategory | null>(null);
  anamnesisItems = signal<CatalogItem[]>([]);
  loadingAnamnesisCategories = signal(false);
  loadingAnamnesisItems = signal(false);
  savingAnamnesisCategory = signal(false);
  savingAnamnesisItem = signal(false);

  showNewAnamnesisCategory = signal(false);
  showNewAnamnesisItem = signal(false);
  showEditAnamnesisItem = signal(false);
  editingAnamnesisItem = signal<CatalogItem | null>(null);

  newCategoryForm: { code: string; name: string; description: string; icon: string; sortOrder: number } = {
    code: '', name: '', description: '', icon: '', sortOrder: 99
  };

  editCategoryForm: UpdateCatalogCategoryRequest & { description: string; icon: string } = {
    name: '', description: '', icon: '', sortOrder: 99, enabled: true
  };

  newItemForm: { code: string; label: string; description: string; isAlert: boolean; sortOrder: number } = {
    code: '', label: '', description: '', isAlert: false, sortOrder: 99
  };

  editItemForm: UpdateCatalogItemRequest & { description: string } = {
    label: '', description: '', isAlert: false, sortOrder: 99, enabled: true
  };

  // ── App settings ───────────────────────────────────────────────────────────
  appSettings: AppSettings = { ...DEFAULT_SETTINGS };
  appSettingsSaved = signal(false);
  localePendingReload = signal(false);

  // ── Lookup data ────────────────────────────────────────────────────────────
  readonly providerRoles = [
    { value: 'dentist',      label: 'Dentista' },
    { value: 'hygienist',    label: 'Igienista' },
    { value: 'orthodontist', label: 'Ortodontista' },
    { value: 'surgeon',      label: 'Chirurgo' },
    { value: 'assistant',    label: 'Assistente' },
    { value: 'admin',        label: 'Amministratore' },
    { value: 'other',        label: 'Altro' },
  ];

  readonly localeOptions = [
    { value: 'it', label: 'Italiano' },
    { value: 'en', label: 'English' },
    { value: 'de', label: 'Deutsch' },
    { value: 'fr', label: 'Francais' },
  ];

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
    { key: 'studio',         icon: 'business',             label: 'Studio' },
    { key: 'professionisti', icon: 'badge',                label: 'Professionisti' },
    { key: 'anagrafiche',    icon: 'folder_shared',        label: 'Anagrafiche' },
    { key: 'agenda',         icon: 'event',                label: 'Agenda' },
    { key: 'preventivi',     icon: 'description',          label: 'Preventivi' },
    { key: 'fatturazione',   icon: 'receipt_long',         label: 'Fatturazione' },
    { key: 'richiami',       icon: 'notifications_active', label: 'Richiami' },
    { key: 'sistema',        icon: 'settings',             label: 'Sistema' },
  ] as const;

  constructor(
    private clinicService: ClinicSettingsService,
    private providerService: ProviderService,
    private catalogService: AnamnesisCatalogService
  ) {}

  ngOnInit(): void {
    this.clinicService.get().subscribe({
      next: c => { this.clinic.set(c); this.clinicForm = { ...c }; this.loadingClinic.set(false); },
      error: () => this.loadingClinic.set(false)
    });
    this.loadProviders();
    this.loadAppSettings();
  }

  setTab(key: string): void {
    this.activeTab.set(key as 'studio' | 'professionisti' | 'anagrafiche' | 'agenda' | 'preventivi' | 'fatturazione' | 'richiami' | 'sistema');
    if (key === 'anagrafiche' && this.clinics().length === 0) {
      this.loadClinics();
    }
  }

  setAnagraficaSubTab(tab: 'centri' | 'anamnesi'): void {
    this.anagraficaSubTab.set(tab);
    if (tab === 'anamnesi' && this.anamnesisCategories().length === 0) {
      this.loadAnamnesisCategories();
    }
  }

  // ── Studio ─────────────────────────────────────────────────────────────────
  saveClinic(): void {
    this.savingClinic.set(true);
    this.clinicService.update(this.clinicForm).subscribe({
      next: () => { this.savingClinic.set(false); this.clinicSaved.set(true); setTimeout(() => this.clinicSaved.set(false), 2500); },
      error: () => this.savingClinic.set(false)
    });
  }

  // ── Professionisti ─────────────────────────────────────────────────────────
  loadProviders(): void {
    this.loadingProviders.set(true);
    this.providerService.findAll(false).subscribe({
      next: list => { this.providers.set(list); this.loadingProviders.set(false); },
      error: () => this.loadingProviders.set(false)
    });
  }

  selectProvider(p: Provider): void {
    this.selectedProvider.set(p);
    this.profileForm = {
      firstName: p.firstName,
      lastName: p.lastName,
      role: p.role,
      phone: p.phone ?? '',
      email: p.email ?? '',
      active: p.active
    };
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

  saveProviderProfile(): void {
    const p = this.selectedProvider();
    if (!p) return;
    this.savingProvider.set(true);
    this.providerService.updateProfile(p.providerId, this.profileForm).subscribe({
      next: () => {
        this.savingProvider.set(false);
        this.providerSaved.set(true);
        setTimeout(() => this.providerSaved.set(false), 2500);
        const updated = { ...p, ...this.profileForm,
          fullName: `${this.profileForm.lastName} ${this.profileForm.firstName}` } as Provider;
        this.selectedProvider.set(updated);
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
      },
      error: () => this.savingProvider.set(false)
    });
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

  createProvider(): void {
    if (!this.newProviderForm.firstName || !this.newProviderForm.lastName) return;
    this.creatingProvider.set(true);
    this.providerService.create(this.newProviderForm).subscribe({
      next: p => {
        this.creatingProvider.set(false);
        this.showNewProvider.set(false);
        this.newProviderForm = { firstName: '', lastName: '', role: 'dentist', phone: '', email: '' };
        this.providers.update(list => [...list, p]);
        this.selectProvider(p);
      },
      error: () => this.creatingProvider.set(false)
    });
  }

  deleteProvider(p: Provider): void {
    this.deletingProvider.set(true);
    this.providerService.delete(p.providerId).subscribe({
      next: () => {
        this.deletingProvider.set(false);
        this.providers.update(list => list.filter(x => x.providerId !== p.providerId));
        this.selectedProvider.set(null);
      },
      error: () => this.deletingProvider.set(false)
    });
  }

  roleLabel(role: string): string {
    return this.providerRoles.find(r => r.value === role)?.label ?? role;
  }

  roleColor(role: string): string {
    switch (role) {
      case 'dentist':      return 'bg-teal-100 text-teal-700';
      case 'hygienist':    return 'bg-blue-100 text-blue-700';
      case 'orthodontist': return 'bg-purple-100 text-purple-700';
      case 'surgeon':      return 'bg-red-100 text-red-700';
      case 'assistant':    return 'bg-amber-100 text-amber-700';
      case 'admin':        return 'bg-slate-100 text-slate-700';
      default:             return 'bg-gray-100 text-gray-600';
    }
  }

  // ── Anagrafiche / Centri ───────────────────────────────────────────────────
  loadClinics(): void {
    this.loadingClinics.set(true);
    this.clinicService.findAll().subscribe({
      next: list => { this.clinics.set(list); this.loadingClinics.set(false); },
      error: () => this.loadingClinics.set(false)
    });
  }

  selectClinic(c: ClinicBilling): void {
    this.selectedClinic.set(c);
    this.clinicEditForm = { ...c };
    this.clinicEditSaved.set(false);
  }

  saveClinicEdit(): void {
    const c = this.selectedClinic();
    if (!c) return;
    this.savingClinicEdit.set(true);
    this.savingClinicEdit.set(false);
    this.clinicEditSaved.set(true);
    setTimeout(() => this.clinicEditSaved.set(false), 2500);
    this.clinics.update(list => list.map(x => x.id === c.id ? { ...c, ...this.clinicEditForm } as ClinicBilling : x));
    this.selectedClinic.set({ ...c, ...this.clinicEditForm } as ClinicBilling);
  }

  createClinic(): void {
    if (!this.newClinicForm.name) return;
    this.creatingClinic.set(true);
    this.clinicService.create(this.newClinicForm).subscribe({
      next: c => {
        this.creatingClinic.set(false);
        this.showNewClinic.set(false);
        this.newClinicForm = { name: '' };
        this.clinics.update(list => [...list, c]);
        this.selectClinic(c);
      },
      error: () => this.creatingClinic.set(false)
    });
  }

  // ── Anamnesi Catalog ───────────────────────────────────────────────────────
  loadAnamnesisCategories(): void {
    this.loadingAnamnesisCategories.set(true);
    this.anamnesisCategories.set([]);
    this.catalogService.findAllCategories().subscribe({
      next: list => { this.anamnesisCategories.set(list); this.loadingAnamnesisCategories.set(false); },
      error: () => this.loadingAnamnesisCategories.set(false)
    });
  }

  selectAnamnesisCategory(cat: CatalogCategory): void {
    this.selectedAnamnesisCategory.set(cat);
    this.editCategoryForm = {
      name: cat.name,
      description: cat.description ?? '',
      icon: cat.icon ?? '',
      sortOrder: cat.sortOrder,
      enabled: cat.enabled
    };
    this.loadAnamnesisItems(cat.id);
  }

  loadAnamnesisItems(categoryId: string): void {
    this.loadingAnamnesisItems.set(true);
    this.anamnesisItems.set([]);
    this.catalogService.findItems(categoryId).subscribe({
      next: list => { this.anamnesisItems.set(list); this.loadingAnamnesisItems.set(false); },
      error: () => this.loadingAnamnesisItems.set(false)
    });
  }

  createAnamnesisCategory(): void {
    if (!this.newCategoryForm.name || !this.newCategoryForm.code) return;
    this.savingAnamnesisCategory.set(true);
    this.catalogService.createCategory({
      code: this.newCategoryForm.code,
      name: this.newCategoryForm.name,
      description: this.newCategoryForm.description || undefined,
      icon: this.newCategoryForm.icon || undefined,
      sortOrder: this.newCategoryForm.sortOrder ?? 99
    }).subscribe({
      next: cat => {
        this.savingAnamnesisCategory.set(false);
        this.showNewAnamnesisCategory.set(false);
        this.newCategoryForm = { code: '', name: '', description: '', icon: '', sortOrder: 99 };
        this.anamnesisCategories.update(list => [...list, cat]);
        this.selectAnamnesisCategory(cat);
      },
      error: () => this.savingAnamnesisCategory.set(false)
    });
  }

  saveAnamnesisCategory(): void {
    const cat = this.selectedAnamnesisCategory();
    if (!cat) return;
    this.savingAnamnesisCategory.set(true);
    const req: UpdateCatalogCategoryRequest = {
      name: this.editCategoryForm.name,
      description: this.editCategoryForm.description || undefined,
      icon: this.editCategoryForm.icon || undefined,
      sortOrder: this.editCategoryForm.sortOrder,
      enabled: this.editCategoryForm.enabled
    };
    this.catalogService.updateCategory(cat.id, req).subscribe({
      next: () => {
        this.savingAnamnesisCategory.set(false);
        const updated: CatalogCategory = {
          ...cat,
          name: req.name,
          description: req.description ?? null,
          icon: req.icon ?? null,
          sortOrder: req.sortOrder,
          enabled: req.enabled
        };
        this.selectedAnamnesisCategory.set(updated);
        this.anamnesisCategories.update(list => list.map(c => c.id === cat.id ? updated : c));
      },
      error: () => this.savingAnamnesisCategory.set(false)
    });
  }

  deleteAnamnesisCategory(cat: CatalogCategory): void {
    this.catalogService.deleteCategory(cat.id).subscribe({
      next: () => {
        this.anamnesisCategories.update(list => list.filter(c => c.id !== cat.id));
        this.selectedAnamnesisCategory.set(null);
        this.anamnesisItems.set([]);
      }
    });
  }

  createAnamnesisItem(): void {
    const cat = this.selectedAnamnesisCategory();
    if (!cat || !this.newItemForm.label || !this.newItemForm.code) return;
    this.savingAnamnesisItem.set(true);
    this.catalogService.createItem({
      categoryId: cat.id,
      code: this.newItemForm.code,
      label: this.newItemForm.label,
      description: this.newItemForm.description || undefined,
      isAlert: this.newItemForm.isAlert ?? false,
      sortOrder: this.newItemForm.sortOrder ?? 99
    }).subscribe({
      next: item => {
        this.savingAnamnesisItem.set(false);
        this.showNewAnamnesisItem.set(false);
        this.newItemForm = { code: '', label: '', description: '', isAlert: false, sortOrder: 99 };
        this.anamnesisItems.update(list => [...list, item]);
        this.anamnesisCategories.update(list => list.map(c =>
          c.id === cat.id ? { ...c, itemsCount: c.itemsCount + 1 } : c
        ));
      },
      error: () => this.savingAnamnesisItem.set(false)
    });
  }

  saveAnamnesisItem(item: CatalogItem): void {
    this.savingAnamnesisItem.set(true);
    const req: UpdateCatalogItemRequest = {
      label: this.editItemForm.label,
      description: this.editItemForm.description || undefined,
      isAlert: this.editItemForm.isAlert,
      sortOrder: this.editItemForm.sortOrder,
      enabled: this.editItemForm.enabled
    };
    this.catalogService.updateItem(item.id, req).subscribe({
      next: () => {
        this.savingAnamnesisItem.set(false);
        this.showEditAnamnesisItem.set(false);
        const updated: CatalogItem = {
          ...item,
          label: req.label,
          description: req.description ?? null,
          isAlert: req.isAlert,
          sortOrder: req.sortOrder,
          enabled: req.enabled
        };
        this.anamnesisItems.update(list => list.map(i => i.id === item.id ? updated : i));
      },
      error: () => this.savingAnamnesisItem.set(false)
    });
  }

  deleteAnamnesisItem(item: CatalogItem): void {
    const cat = this.selectedAnamnesisCategory();
    this.catalogService.deleteItem(item.id).subscribe({
      next: () => {
        this.anamnesisItems.update(list => list.filter(i => i.id !== item.id));
        if (cat) {
          this.anamnesisCategories.update(list => list.map(c =>
            c.id === cat.id ? { ...c, itemsCount: Math.max(0, c.itemsCount - 1) } : c
          ));
        }
      }
    });
  }

  openEditItem(item: CatalogItem): void {
    this.editingAnamnesisItem.set(item);
    this.editItemForm = {
      label: item.label,
      description: item.description ?? '',
      isAlert: item.isAlert,
      sortOrder: item.sortOrder,
      enabled: item.enabled
    };
    this.showEditAnamnesisItem.set(true);
  }

  // ── App Settings ───────────────────────────────────────────────────────────
  private loadAppSettings(): void {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (raw) this.appSettings = { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
    } catch { this.appSettings = { ...DEFAULT_SETTINGS }; }
  }

  saveAppSettings(): void {
    localStorage.setItem(LS_KEY, JSON.stringify(this.appSettings));
    this.appSettingsSaved.set(true);
    setTimeout(() => this.appSettingsSaved.set(false), 2500);
  }

  saveLocale(): void {
    localStorage.setItem(LS_KEY, JSON.stringify(this.appSettings));
    this.localePendingReload.set(true);
  }

  reloadApp(): void {
    window.location.reload();
  }

  isWorkDay(d: number): boolean {
    return this.appSettings.workDays.includes(d);
  }

  toggleWorkDay(d: number): void {
    const days = this.appSettings.workDays;
    this.appSettings.workDays = days.includes(d) ? days.filter(x => x !== d) : [...days, d].sort();
  }
}
