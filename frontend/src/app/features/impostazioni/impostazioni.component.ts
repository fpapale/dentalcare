import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AiPromptsComponent } from './ai-prompts.component';
import { ClinicSettingsService } from '../../core/services/clinic-settings.service';
import { UserContextService } from '../../core/services/user-context.service';
import { ProviderService } from '../../core/services/provider.service';
import { ProviderPricesService } from '../../core/services/provider-prices.service';
import { ProviderPrice } from '../../core/models/provider-price.model';
import { AnamnesisCatalogService } from '../../core/services/anamnesis-catalog.service';
import { AppSettingsService, AppSettings, DEFAULT_SETTINGS } from '../../core/services/app-settings.service';
import { ClinicBilling } from '../../core/models/clinic-billing.model';
import { Provider, CreateProviderRequest, UpdateProviderProfileRequest } from '../../core/models/provider.model';
import {
  CatalogCategory,
  CatalogItem,
  UpdateCatalogCategoryRequest,
  UpdateCatalogItemRequest
} from '../../core/models/anamnesis-catalog.model';

export type { AppSettings };

@Component({
  selector: 'app-impostazioni',
  standalone: true,
  imports: [CommonModule, FormsModule, AiPromptsComponent],
  templateUrl: './impostazioni.component.html'
})
export class ImpostazioniComponent implements OnInit {
  activeTab = signal<'studio' | 'professionisti' | 'anagrafiche' | 'agenda' | 'preventivi' | 'fatturazione' | 'tariffe' | 'richiami' | 'ai' | 'sistema'>('studio');

  // ── Studio (Clinic) ────────────────────────────────────────────────────────
  clinic = signal<ClinicBilling | null>(null);
  clinicForm: Partial<ClinicBilling> = {};
  loadingClinic = signal(true);
  savingClinic = signal(false);
  clinicSaved = signal(false);
  clinicError = signal<string | null>(null);

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

  togglingActive = signal(false);

  // ── Riassegnazione pazienti ─────────────────────────────────────────────────
  showReassign = signal(false);
  reassignFrom = signal<Provider | null>(null);
  reassignToId = signal<string>('');
  reassigning = signal(false);
  reassignError = signal<string | null>(null);
  reassignResult = signal<string | null>(null);

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

  newItemForm: { code: string; label: string; description: string; severity: 'normale' | 'grave' | 'severa'; sortOrder: number } = {
    code: '', label: '', description: '', severity: 'normale', sortOrder: 99
  };

  editItemForm: UpdateCatalogItemRequest & { description: string } = {
    label: '', description: '', severity: 'normale', sortOrder: 99, enabled: true
  };

  // ── App settings ───────────────────────────────────────────────────────────
  appSettings: AppSettings = { ...DEFAULT_SETTINGS };
  appSettingsSaved = signal(false);
  appSettingsError = signal(false);

  // #42 — visibilità pazienti per ruolo (per_provider | shared), modificabile solo dall'admin.
  patientVisibilityMode = signal<'per_provider' | 'shared'>('per_provider');
  visibilitySaved = signal(false);
  visibilityError = signal(false);
  canEditVisibility = () => this.userContext.authRole() === 'admin' || this.userContext.authRole() === 'tenant_admin';
  localePendingReload = signal(false);

  // #44 — modalità di fatturazione: 'studio' (fatture allo studio) | 'provider' (parcella del medico). Solo admin.
  billingMode = signal<'studio' | 'provider'>('studio');
  billingModeSaved = signal(false);
  billingModeError = signal(false);
  canEditBillingMode = () => this.userContext.authRole() === 'admin' || this.userContext.authRole() === 'tenant_admin';

  // #44 — "Le mie tariffe": override di prezzo per il medico loggato.
  isClinicalProvider = () => !!this.userContext.providerId();
  myPrices = signal<ProviderPrice[]>([]);
  loadingPrices = signal(false);
  priceInput: Record<string, number | null> = {};
  savingPriceId = signal<string | null>(null);
  savedPriceId = signal<string | null>(null);
  pricesError = signal(false);

  // ── Lookup data ────────────────────────────────────────────────────────────
  readonly providerRoles = [
    { value: 'dentist',      label: 'Dentista' },
    { value: 'hygienist',    label: 'Igienista' },
    { value: 'orthodontist', label: 'Ortodontista' },
    { value: 'surgeon',      label: 'Chirurgo' },
    { value: 'assistant',    label: 'Assistente' },
    { value: 'secretary',    label: 'Segreteria' },
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
    { key: 'tariffe',        icon: 'payments',             label: 'Le mie tariffe' },
    { key: 'richiami',       icon: 'notifications_active', label: 'Richiami' },
    { key: 'ai',             icon: 'smart_toy',            label: 'AI' },
    { key: 'sistema',        icon: 'settings',             label: 'Sistema' },
  ] as const;

  /** La tab "Le mie tariffe" è visibile solo ai medici clinici (con un providerId). */
  visibleTabs = () => this.tabs.filter(t => t.key !== 'tariffe' || this.isClinicalProvider());

  constructor(
    private clinicService: ClinicSettingsService,
    private providerService: ProviderService,
    private catalogService: AnamnesisCatalogService,
    private appSettingsSvc: AppSettingsService,
    private userContext: UserContextService,
    private providerPricesService: ProviderPricesService
  ) {}

  ngOnInit(): void {
    this.clinicService.get().subscribe({
      next: c => { this.clinic.set(c); this.clinicForm = { ...c }; this.loadingClinic.set(false); },
      error: () => this.loadingClinic.set(false)
    });
    this.loadProviders();
    this.loadAppSettings();
    // #44 — modalità di fatturazione della sede (default 'studio' finché non configurata).
    this.clinicService.getBillingMode().subscribe({
      next: v => this.billingMode.set(v.mode === 'provider' ? 'provider' : 'studio'),
      error: () => { /* impostazione non ancora presente: resta il default 'studio' */ }
    });
  }

  setTab(key: string): void {
    this.activeTab.set(key as 'studio' | 'professionisti' | 'anagrafiche' | 'agenda' | 'preventivi' | 'fatturazione' | 'tariffe' | 'richiami' | 'ai' | 'sistema');
    if (key === 'anagrafiche' && this.clinics().length === 0) {
      this.loadClinics();
    }
    if (key === 'tariffe' && this.myPrices().length === 0) {
      this.loadMyPrices();
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
    this.clinicError.set(null);
    this.clinicService.update(this.clinicForm).subscribe({
      next: () => {
        this.savingClinic.set(false);
        this.clinicSaved.set(true);
        setTimeout(() => this.clinicSaved.set(false), 2500);
      },
      error: (err) => {
        this.savingClinic.set(false);
        this.clinicError.set(err?.error?.message || 'Errore nel salvataggio. Riprova.');
      }
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

  toggleProviderActive(p: Provider): void {
    if (p.active) {
      const base = 'Disattivare il professionista? Non sara piu selezionabile.';
      const warn = `Questo medico ha ${p.assignedPatientCount} pazienti assegnati. Conviene riassegnarli prima. Disattivare comunque?`;
      const msg = p.assignedPatientCount > 0 ? warn : base;
      if (!confirm(msg)) return;
    }
    this.togglingActive.set(true);
    this.providerService.setActive(p.providerId, !p.active).subscribe({
      next: () => {
        this.togglingActive.set(false);
        const updated = { ...p, active: !p.active };
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
        if (this.selectedProvider()?.providerId === p.providerId) {
          this.selectedProvider.set(updated);
          this.profileForm = { ...this.profileForm, active: updated.active };
        }
      },
      error: () => this.togglingActive.set(false)
    });
  }

  reassignTargets(): Provider[] {
    const fromId = this.reassignFrom()?.providerId ?? null;
    return this.providers().filter(p => p.active && p.role !== 'tenant_admin' && p.providerId !== fromId);
  }

  openReassign(from: Provider | null): void {
    this.reassignFrom.set(from);
    this.reassignToId.set('');
    this.reassignError.set(null);
    this.reassignResult.set(null);
    this.showReassign.set(true);
  }

  closeReassign(): void {
    this.showReassign.set(false);
    this.reassignFrom.set(null);
    this.reassignToId.set('');
    this.reassignError.set(null);
    this.reassignResult.set(null);
  }

  confirmReassign(): void {
    const toId = this.reassignToId();
    if (!toId) return;
    const fromId = this.reassignFrom()?.providerId ?? null;
    this.reassigning.set(true);
    this.reassignError.set(null);
    this.providerService.reassignPatients(fromId, toId).subscribe({
      next: res => {
        this.reassigning.set(false);
        this.reassignResult.set(`${res.reassignedCount} pazienti riassegnati`);
        this.loadProviders();
      },
      error: err => {
        this.reassigning.set(false);
        this.reassignError.set(err?.error?.message || 'Riassegnazione non valida. Verifica il professionista di destinazione.');
      }
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
      case 'secretary':    return 'bg-pink-100 text-pink-700';
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
      severity: this.newItemForm.severity ?? 'normale',
      sortOrder: this.newItemForm.sortOrder ?? 99
    }).subscribe({
      next: item => {
        this.savingAnamnesisItem.set(false);
        this.showNewAnamnesisItem.set(false);
        this.newItemForm = { code: '', label: '', description: '', severity: 'normale', sortOrder: 99 };
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
      severity: this.editItemForm.severity,
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
          severity: req.severity,
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
      severity: item.severity,
      sortOrder: item.sortOrder,
      enabled: item.enabled
    };
    this.showEditAnamnesisItem.set(true);
  }

  // ── App Settings ───────────────────────────────────────────────────────────
  private loadAppSettings(): void {
    this.appSettings = { ...this.appSettingsSvc.get() };
    // #31 — gli orari studio vivono sul tenant, non nel browser: il backend è la
    // fonte di verità. I valori locali restano il fallback finché non è configurato.
    this.clinicService.getSchedule().subscribe({
      next: s => {
        if (s.workStartTime) this.appSettings.workStartTime   = s.workStartTime;
        if (s.workEndTime)   this.appSettings.workEndTime     = s.workEndTime;
        if (s.slotMinutes)   this.appSettings.slotDurationMin = s.slotMinutes;
        if (s.workingDays)   this.appSettings.workDays        = this.isoToWorkDays(s.workingDays);
      },
      error: () => { /* tenant senza orari configurati: restano i default locali */ }
    });
    // #42 — modalità di visibilità pazienti della sede
    this.clinicService.getPatientVisibility().subscribe({
      next: v => this.patientVisibilityMode.set(v.mode === 'shared' ? 'shared' : 'per_provider'),
      error: () => { /* colonna non ancora presente: resta il default per_provider */ }
    });
  }

  /** #42 — cambia e persiste la modalità di visibilità (solo admin, il server rifiuta gli altri). */
  setPatientVisibility(mode: 'per_provider' | 'shared'): void {
    if (mode === this.patientVisibilityMode()) return;
    const previous = this.patientVisibilityMode();
    this.patientVisibilityMode.set(mode);
    this.visibilityError.set(false);
    this.clinicService.updatePatientVisibility(mode).subscribe({
      next: () => {
        this.visibilitySaved.set(true);
        setTimeout(() => this.visibilitySaved.set(false), 2500);
      },
      error: () => {
        this.patientVisibilityMode.set(previous);
        this.visibilityError.set(true);
      }
    });
  }

  /** #44 — cambia e persiste la modalità di fatturazione (solo admin, il server rifiuta gli altri). */
  setBillingMode(mode: 'studio' | 'provider'): void {
    if (mode === this.billingMode()) return;
    const previous = this.billingMode();
    this.billingMode.set(mode);
    this.billingModeError.set(false);
    this.clinicService.updateBillingMode(mode).subscribe({
      next: () => {
        this.billingModeSaved.set(true);
        setTimeout(() => this.billingModeSaved.set(false), 2500);
      },
      error: () => {
        this.billingMode.set(previous);
        this.billingModeError.set(true);
      }
    });
  }

  // ── Le mie tariffe (#44) ─────────────────────────────────────────────────────
  loadMyPrices(): void {
    const providerId = this.userContext.providerId();
    if (!providerId) return;
    this.loadingPrices.set(true);
    this.pricesError.set(false);
    this.providerPricesService.list(providerId).subscribe({
      next: rows => {
        this.myPrices.set(rows);
        this.priceInput = {};
        for (const r of rows) this.priceInput[r.serviceId] = r.overridePrice;
        this.loadingPrices.set(false);
      },
      error: () => {
        this.pricesError.set(true);
        this.loadingPrices.set(false);
      }
    });
  }

  /** Salva l'override di una riga: valore vuoto = elimina l'override (torna al listino). */
  savePrice(row: ProviderPrice): void {
    const providerId = this.userContext.providerId();
    if (!providerId) return;
    const raw = this.priceInput[row.serviceId];
    const empty = raw === null || raw === undefined || (raw as unknown as string) === '';
    this.savingPriceId.set(row.serviceId);
    this.pricesError.set(false);
    const req = empty
      ? this.providerPricesService.removeOverride(providerId, row.serviceId)
      : this.providerPricesService.setOverride(providerId, row.serviceId, Number(raw));
    req.subscribe({
      next: () => {
        this.savingPriceId.set(null);
        this.savedPriceId.set(row.serviceId);
        setTimeout(() => { if (this.savedPriceId() === row.serviceId) this.savedPriceId.set(null); }, 2500);
        this.loadMyPrices();
      },
      error: () => {
        this.savingPriceId.set(null);
        this.pricesError.set(true);
      }
    });
  }

  saveAppSettings(): void {
    this.appSettingsSvc.save(this.appSettings);
    this.appSettingsError.set(false);
    // #31 — l'orario vale per tutto lo studio (lo usa la proposta di disponibilità
    // appuntamenti lato server), quindi va persistito sul tenant, non solo in locale.
    this.clinicService.updateSchedule({
      workStartTime: this.appSettings.workStartTime || null,
      workEndTime:   this.appSettings.workEndTime || null,
      slotMinutes:   this.appSettings.slotDurationMin ?? null,
      workingDays:   this.workDaysToIso(this.appSettings.workDays),
    }).subscribe({
      next: () => {},
      error: () => this.appSettingsError.set(true)
    });
    // Il salvataggio locale è già avvenuto: lo confermiamo subito. Se il sync col
    // server fallisce lo dice il messaggio d'errore, senza smentire questo.
    this.appSettingsSaved.set(true);
    setTimeout(() => this.appSettingsSaved.set(false), 2500);
  }

  /** UI (0=Dom … 6=Sab) → ISO backend (1=Lun … 7=Dom). */
  private workDaysToIso(days: number[]): string {
    return days.map(d => (d === 0 ? 7 : d)).sort((a, b) => a - b).join(',');
  }

  /** ISO backend (1=Lun … 7=Dom) → UI (0=Dom … 6=Sab). */
  private isoToWorkDays(csv: string): number[] {
    return csv.split(',')
      .map(p => Number(p.trim()))
      .filter(n => n >= 1 && n <= 7)
      .map(n => (n === 7 ? 0 : n))
      .sort((a, b) => a - b);
  }

  saveLocale(): void {
    this.appSettingsSvc.save(this.appSettings);
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

  // ── Provider photo ─────────────────────────────────────────────────────────
  showProviderPhotoModal = signal(false);
  providerPhotoMode = signal<'idle' | 'webcam'>('idle');
  providerWebcamStream: MediaStream | null = null;
  capturedProviderPhoto = signal<string | null>(null);
  savingProviderPhoto = signal(false);

  openProviderPhotoModal(): void {
    this.capturedProviderPhoto.set(null);
    this.providerPhotoMode.set('idle');
    this.showProviderPhotoModal.set(true);
  }

  closeProviderPhotoModal(): void {
    this.stopProviderWebcam();
    this.showProviderPhotoModal.set(false);
    this.capturedProviderPhoto.set(null);
    this.providerPhotoMode.set('idle');
  }

  async startProviderWebcam(): Promise<void> {
    this.providerPhotoMode.set('webcam');
    this.capturedProviderPhoto.set(null);
    try {
      this.providerWebcamStream = await navigator.mediaDevices.getUserMedia({ video: { width: 400, height: 400, facingMode: 'user' } });
      setTimeout(() => {
        const video = document.getElementById('provider-webcam-video') as HTMLVideoElement;
        if (video) video.srcObject = this.providerWebcamStream;
      }, 100);
    } catch {
      this.providerPhotoMode.set('idle');
    }
  }

  captureProviderWebcam(): void {
    const video = document.getElementById('provider-webcam-video') as HTMLVideoElement;
    if (!video) return;
    const canvas = document.createElement('canvas');
    canvas.width = 400;
    canvas.height = 400;
    const ctx = canvas.getContext('2d')!;
    const size = Math.min(video.videoWidth, video.videoHeight);
    const ox = (video.videoWidth - size) / 2;
    const oy = (video.videoHeight - size) / 2;
    ctx.drawImage(video, ox, oy, size, size, 0, 0, 400, 400);
    this.capturedProviderPhoto.set(canvas.toDataURL('image/jpeg', 0.85));
    this.stopProviderWebcam();
    this.providerPhotoMode.set('idle');
  }

  stopProviderWebcam(): void {
    if (this.providerWebcamStream) {
      this.providerWebcamStream.getTracks().forEach(t => t.stop());
      this.providerWebcamStream = null;
    }
  }

  onProviderFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = 400; canvas.height = 400;
        const ctx = canvas.getContext('2d')!;
        const s = Math.min(img.width, img.height);
        const ox = (img.width - s) / 2;
        const oy = (img.height - s) / 2;
        ctx.drawImage(img, ox, oy, s, s, 0, 0, 400, 400);
        this.capturedProviderPhoto.set(canvas.toDataURL('image/jpeg', 0.85));
        this.providerPhotoMode.set('idle');
      };
      img.src = reader.result as string;
    };
    reader.readAsDataURL(file);
  }

  saveProviderPhoto(): void {
    const p = this.selectedProvider();
    const photo = this.capturedProviderPhoto();
    if (!p || !photo || this.savingProviderPhoto()) return;
    this.savingProviderPhoto.set(true);
    this.providerService.updatePhoto(p.providerId, photo).subscribe({
      next: () => {
        const updated = { ...p, photoUrl: photo };
        this.selectedProvider.set(updated);
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
        this.savingProviderPhoto.set(false);
        this.closeProviderPhotoModal();
      },
      error: () => this.savingProviderPhoto.set(false)
    });
  }

  removeProviderPhoto(): void {
    const p = this.selectedProvider();
    if (!p || !confirm('Rimuovere la foto?')) return;
    this.providerService.updatePhoto(p.providerId, '').subscribe({
      next: () => {
        const updated = { ...p, photoUrl: null };
        this.selectedProvider.set(updated);
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
      }
    });
  }
}
