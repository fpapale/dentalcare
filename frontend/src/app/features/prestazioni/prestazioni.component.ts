import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { ServiceCatalogService } from '../../core/services/service-catalog.service';
import {
  ConditionDefault,
  CreateConditionDefaultRequest,
  CreateServiceRequest,
  ServiceAdmin,
  ServiceCategory,
  UpdateServiceCategoryRequest,
  UpdateServiceRequest
} from '../../core/models/service.model';

interface ServiceForm {
  code: string;
  name: string;
  category: string;
  description: string;
  defaultPrice: number | null;
  defaultVatRate: number | null;
  durationMinutes: number | null;
  minToothDigit: number | null;
  maxToothDigit: number | null;
  applicableToDeciduous: boolean;
  active: boolean;
}

const EMPTY_SERVICE_FORM: ServiceForm = {
  code: '', name: '', category: '', description: '',
  defaultPrice: null, defaultVatRate: 22, durationMinutes: null,
  minToothDigit: null, maxToothDigit: null, applicableToDeciduous: false, active: true
};

@Component({
  selector: 'app-prestazioni',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './prestazioni.component.html'
})
export class PrestazioniComponent implements OnInit {
  private readonly catalogService = inject(ServiceCatalogService);

  readonly conditionOptions: { value: string; label: string }[] = [
    { value: 'cavity',        label: 'Carie' },
    { value: 'crown',         label: 'Corona' },
    { value: 'missing',       label: 'Assente' },
    { value: 'root_canal',    label: 'Devitalizzazione' },
    { value: 'to_extract',    label: 'Da estrarre' },
    { value: 'bridge_pillar', label: 'Pilastro ponte' },
    { value: 'bridge_pontic', label: 'Elemento ponte' },
    { value: 'implant',       label: 'Impianto' },
    { value: 'impacted',      label: 'Incluso' }
  ];

  services = signal<ServiceAdmin[]>([]);
  conditionDefaults = signal<ConditionDefault[]>([]);
  categories = signal<ServiceCategory[]>([]);
  readonly activeCategories = computed(() => this.categories().filter(c => c.active));

  showCategoryPanel = signal(false);
  savingCategory = signal(false);
  newCategoryName = '';
  editingCategoryId = signal<string | null>(null);
  editCategoryName = '';
  confirmDeleteCategoryId = signal<string | null>(null);

  loading = signal(true);
  error = signal<string | null>(null);
  saving = signal(false);

  showServiceForm = signal(false);
  editingService = signal<ServiceAdmin | null>(null);
  serviceForm: ServiceForm = { ...EMPTY_SERVICE_FORM };

  confirmDeleteId = signal<string | null>(null);

  savingConditionDefault = signal(false);
  newConditionDefaultForm: { conditionName: string; serviceId: string; sortOrder: number } = {
    conditionName: '', serviceId: '', sortOrder: 0
  };

  readonly servicesByCategory = computed(() => {
    const groups = new Map<string, ServiceAdmin[]>();
    for (const s of this.services()) {
      const key = s.category ?? 'Senza categoria';
      const list = groups.get(key) ?? [];
      list.push(s);
      groups.set(key, list);
    }
    return Array.from(groups.entries())
      .map(([category, items]) => ({ category, items: items.sort((a, b) => a.name.localeCompare(b.name)) }))
      .sort((a, b) => a.category.localeCompare(b.category));
  });

  readonly activeServices = computed(() => this.services().filter(s => s.active));

  ngOnInit(): void {
    this.loadAll();
  }

  loadAll(): void {
    this.loading.set(true);
    this.error.set(null);
    forkJoin({
      services: this.catalogService.listAdmin(),
      conditionDefaults: this.catalogService.listConditionDefaults(),
      categories: this.catalogService.listCategories()
    }).subscribe({
      next: ({ services, conditionDefaults, categories }) => {
        this.services.set(services);
        this.conditionDefaults.set(conditionDefaults);
        this.categories.set(categories);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Errore nel caricamento delle prestazioni.');
        this.loading.set(false);
      }
    });
  }

  loadServices(): void {
    this.catalogService.listAdmin().subscribe({
      next: list => this.services.set(list),
      error: () => this.error.set('Errore nel caricamento delle prestazioni.')
    });
  }

  loadConditionDefaults(): void {
    this.catalogService.listConditionDefaults().subscribe({
      next: list => this.conditionDefaults.set(list),
      error: () => this.error.set('Errore nel caricamento dei default per condizione.')
    });
  }

  conditionLabel(condition: string): string {
    return this.conditionOptions.find(c => c.value === condition)?.label ?? condition;
  }

  openNewService(): void {
    this.editingService.set(null);
    this.serviceForm = { ...EMPTY_SERVICE_FORM };
    this.showServiceForm.set(true);
  }

  openEditService(service: ServiceAdmin): void {
    this.editingService.set(service);
    this.serviceForm = {
      code: service.code,
      name: service.name,
      category: service.category ?? '',
      description: service.description ?? '',
      defaultPrice: service.defaultPrice,
      defaultVatRate: service.defaultVatRate,
      durationMinutes: service.durationMinutes,
      minToothDigit: service.minToothDigit,
      maxToothDigit: service.maxToothDigit,
      applicableToDeciduous: service.applicableToDeciduous,
      active: service.active
    };
    this.showServiceForm.set(true);
  }

  closeServiceForm(): void {
    this.showServiceForm.set(false);
    this.editingService.set(null);
  }

  saveService(): void {
    if (!this.serviceForm.name || this.serviceForm.defaultPrice == null) return;
    const editing = this.editingService();
    this.saving.set(true);
    this.error.set(null);

    if (editing) {
      const req: UpdateServiceRequest = {
        name: this.serviceForm.name,
        category: this.serviceForm.category || undefined,
        description: this.serviceForm.description || undefined,
        defaultPrice: this.serviceForm.defaultPrice,
        defaultVatRate: this.serviceForm.defaultVatRate ?? undefined,
        durationMinutes: this.serviceForm.durationMinutes ?? undefined,
        minToothDigit: this.serviceForm.minToothDigit ?? undefined,
        maxToothDigit: this.serviceForm.maxToothDigit ?? undefined,
        applicableToDeciduous: this.serviceForm.applicableToDeciduous,
        active: this.serviceForm.active
      };
      this.catalogService.updateService(editing.serviceId, req).subscribe({
        next: updated => {
          this.saving.set(false);
          this.services.update(list => list.map(s => s.serviceId === updated.serviceId ? updated : s));
          this.closeServiceForm();
        },
        error: () => {
          this.saving.set(false);
          this.error.set('Errore nel salvataggio della prestazione.');
        }
      });
    } else {
      if (!this.serviceForm.code) return;
      const req: CreateServiceRequest = {
        code: this.serviceForm.code,
        name: this.serviceForm.name,
        category: this.serviceForm.category || undefined,
        description: this.serviceForm.description || undefined,
        defaultPrice: this.serviceForm.defaultPrice,
        defaultVatRate: this.serviceForm.defaultVatRate ?? undefined,
        durationMinutes: this.serviceForm.durationMinutes ?? undefined,
        minToothDigit: this.serviceForm.minToothDigit ?? undefined,
        maxToothDigit: this.serviceForm.maxToothDigit ?? undefined,
        applicableToDeciduous: this.serviceForm.applicableToDeciduous
      };
      this.catalogService.createService(req).subscribe({
        next: created => {
          this.saving.set(false);
          this.services.update(list => [...list, created]);
          this.closeServiceForm();
        },
        error: () => {
          this.saving.set(false);
          this.error.set('Errore nella creazione della prestazione.');
        }
      });
    }
  }

  askDeleteService(id: string): void {
    this.confirmDeleteId.set(id);
  }

  cancelDeleteService(): void {
    this.confirmDeleteId.set(null);
  }

  confirmDeleteService(id: string): void {
    this.catalogService.deleteService(id).subscribe({
      next: () => {
        this.services.update(list => list.filter(s => s.serviceId !== id));
        this.confirmDeleteId.set(null);
      },
      error: () => {
        this.error.set('Errore nell\'eliminazione della prestazione.');
        this.confirmDeleteId.set(null);
      }
    });
  }

  toggleServiceActive(service: ServiceAdmin): void {
    const req: UpdateServiceRequest = {
      name: service.name,
      category: service.category ?? undefined,
      description: service.description ?? undefined,
      defaultPrice: service.defaultPrice,
      defaultVatRate: service.defaultVatRate ?? undefined,
      durationMinutes: service.durationMinutes ?? undefined,
      minToothDigit: service.minToothDigit ?? undefined,
      maxToothDigit: service.maxToothDigit ?? undefined,
      applicableToDeciduous: service.applicableToDeciduous,
      active: !service.active
    };
    this.catalogService.updateService(service.serviceId, req).subscribe({
      next: updated => this.services.update(list => list.map(s => s.serviceId === updated.serviceId ? updated : s)),
      error: () => this.error.set('Errore nell\'aggiornamento dello stato.')
    });
  }

  addConditionDefault(): void {
    if (!this.newConditionDefaultForm.conditionName || !this.newConditionDefaultForm.serviceId) return;
    this.savingConditionDefault.set(true);
    const req: CreateConditionDefaultRequest = {
      conditionName: this.newConditionDefaultForm.conditionName,
      serviceId: this.newConditionDefaultForm.serviceId,
      sortOrder: this.newConditionDefaultForm.sortOrder || undefined
    };
    this.catalogService.addConditionDefault(req).subscribe({
      next: created => {
        this.savingConditionDefault.set(false);
        this.conditionDefaults.update(list => [...list, created]);
        this.newConditionDefaultForm = { conditionName: '', serviceId: '', sortOrder: 0 };
      },
      error: () => {
        this.savingConditionDefault.set(false);
        this.error.set('Errore nell\'aggiunta del default per condizione.');
      }
    });
  }

  deleteConditionDefault(id: string): void {
    if (!confirm('Rimuovere questo default per condizione?')) return;
    this.catalogService.deleteConditionDefault(id).subscribe({
      next: () => this.conditionDefaults.update(list => list.filter(c => c.id !== id)),
      error: () => this.error.set('Errore nella rimozione del default per condizione.')
    });
  }

  // ── Categorie ────────────────────────────────────────────────────────────

  loadCategories(): void {
    this.catalogService.listCategories().subscribe({
      next: list => this.categories.set(list),
      error: () => this.error.set('Errore nel caricamento delle categorie.')
    });
  }

  addCategory(): void {
    const name = this.newCategoryName.trim();
    if (!name || this.savingCategory()) return;
    this.savingCategory.set(true);
    this.catalogService.createCategory({ name }).subscribe({
      next: created => {
        this.savingCategory.set(false);
        this.categories.update(list => [...list, created]);
        this.newCategoryName = '';
      },
      error: () => { this.savingCategory.set(false); this.error.set('Errore nella creazione della categoria (nome duplicato?).'); }
    });
  }

  startEditCategory(cat: ServiceCategory): void {
    this.editingCategoryId.set(cat.id);
    this.editCategoryName = cat.name;
  }

  cancelEditCategory(): void {
    this.editingCategoryId.set(null);
    this.editCategoryName = '';
  }

  saveCategory(cat: ServiceCategory): void {
    const name = this.editCategoryName.trim();
    if (!name || this.savingCategory()) return;
    this.savingCategory.set(true);
    const req: UpdateServiceCategoryRequest = { name, sortOrder: cat.sortOrder, active: cat.active };
    this.catalogService.updateCategory(cat.id, req).subscribe({
      next: () => {
        this.savingCategory.set(false);
        this.editingCategoryId.set(null);
        this.editCategoryName = '';
        // il rename propaga alle prestazioni -> ricarica categorie e prestazioni
        this.loadCategories();
        this.loadServices();
      },
      error: () => { this.savingCategory.set(false); this.error.set('Errore nel salvataggio della categoria.'); }
    });
  }

  askDeleteCategory(id: string): void { this.confirmDeleteCategoryId.set(id); }
  cancelDeleteCategory(): void { this.confirmDeleteCategoryId.set(null); }

  confirmDeleteCategory(id: string): void {
    this.catalogService.deleteCategory(id).subscribe({
      next: () => { this.confirmDeleteCategoryId.set(null); this.loadCategories(); },
      error: () => { this.confirmDeleteCategoryId.set(null); this.error.set('Errore nell\'eliminazione della categoria.'); }
    });
  }
}
