import { Component, AfterViewInit, OnDestroy, OnInit, TemplateRef, ViewChild, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { LayoutService } from '../../core/services/layout.service';
import { ProductService } from '../../core/services/product.service';
import { SupplierService } from '../../core/services/supplier.service';
import { StockMovementService } from '../../core/services/stock-movement.service';
import { Product, ProductCategory, CreateProductRequest } from '../../core/models/product.model';
import { Supplier, CreateSupplierRequest } from '../../core/models/supplier.model';
import { StockMovement, CreateStockMovementRequest } from '../../core/models/stock-movement.model';

@Component({
  selector: 'app-magazzino',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './magazzino.component.html'
})
export class MagazzinoComponent implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild('rightPanel') rightPanelTpl!: TemplateRef<unknown>;

  private readonly layout = inject(LayoutService);
  private readonly productService = inject(ProductService);
  private readonly supplierService = inject(SupplierService);
  private readonly movementService = inject(StockMovementService);

  activeTab = signal<'prodotti' | 'movimenti' | 'fornitori'>('prodotti');

  products = signal<Product[]>([]);
  categories = signal<ProductCategory[]>([]);
  suppliers = signal<Supplier[]>([]);
  movements = signal<StockMovement[]>([]);

  loading = signal(true);
  error = signal<string | null>(null);
  saving = signal(false);

  showNewProduct = signal(false);
  showNewMovement = signal(false);
  showNewSupplier = signal(false);

  selectedProduct = signal<Product | null>(null);
  movementType = signal<'carico' | 'scarico'>('carico');

  searchQuery = signal('');
  selectedCategoryId = signal<string | null>(null);
  movementProductFilter = signal('');
  movementCategoryFilter = signal<string | null>(null);

  newProductForm: {
    name: string; unit: string; minStockQuantity: number; reorderQuantity: number;
    categoryId: string; supplierId: string; description: string; sku: string; unitCost: number | undefined;
  } = {
    name: '', unit: 'pz', minStockQuantity: 0, reorderQuantity: 0,
    categoryId: '', supplierId: '', description: '', sku: '', unitCost: undefined
  };

  newSupplierForm: CreateSupplierRequest = {
    name: '', contactPerson: '', phone: '', email: '', notes: ''
  };

  newMovementForm: CreateStockMovementRequest = {
    productId: '', movementType: 'carico', quantity: 1,
    unitCost: undefined, notes: '', referenceDoc: ''
  };

  readonly criticoCount = computed(() => this.products().filter(p => p.stockStatus === 'critico').length);
  readonly bassoCount = computed(() => this.products().filter(p => p.stockStatus === 'basso').length);
  readonly okCount = computed(() => this.products().filter(p => p.stockStatus === 'ok').length);

  readonly criticiList = computed(() => this.products().filter(p => p.stockStatus === 'critico'));

  readonly filteredProducts = computed(() => {
    const q = this.searchQuery().toLowerCase().trim();
    const catId = this.selectedCategoryId();
    return this.products().filter(p => {
      const matchCat = !catId || p.categoryId === catId;
      const matchQ = !q || p.name.toLowerCase().includes(q) || (p.categoryName ?? '').toLowerCase().includes(q);
      return matchCat && matchQ;
    });
  });

  readonly productsByCategoryMap = computed(() => {
    const map = new Map<string, string | null>();
    for (const p of this.products()) map.set(p.productId, p.categoryId);
    return map;
  });

  readonly movementFilteredProducts = computed(() => {
    const catId = this.movementCategoryFilter();
    if (!catId) return this.products();
    return this.products().filter(p => p.categoryId === catId);
  });

  readonly filteredMovements = computed(() => {
    const productId = this.movementProductFilter();
    const catId = this.movementCategoryFilter();
    const catMap = this.productsByCategoryMap();
    return this.movements().filter(m => {
      if (productId && m.productId !== productId) return false;
      if (catId && catMap.get(m.productId) !== catId) return false;
      return true;
    });
  });

  ngOnInit(): void {
    this.loadAll();
  }

  ngAfterViewInit(): void {
    this.layout.setRightPanel(this.rightPanelTpl);
  }

  ngOnDestroy(): void {
    this.layout.setRightPanel(null);
  }

  loadAll(): void {
    this.loading.set(true);
    this.error.set(null);
    forkJoin({
      products: this.productService.findAll(),
      categories: this.productService.findCategories(),
      suppliers: this.supplierService.findAll()
    }).subscribe({
      next: ({ products, categories, suppliers }) => {
        this.products.set(products);
        this.categories.set(categories);
        this.suppliers.set(suppliers);
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Errore nel caricamento dati magazzino');
        this.loading.set(false);
      }
    });
  }

  loadProducts(): void {
    this.productService.findAll().subscribe({
      next: data => this.products.set(data),
      error: () => this.error.set('Errore nel caricamento prodotti')
    });
  }

  loadMovements(): void {
    this.movementService.findAll().subscribe({
      next: data => this.movements.set(data),
      error: () => this.error.set('Errore nel caricamento movimenti')
    });
  }

  loadSuppliers(): void {
    this.supplierService.findAll().subscribe({
      next: data => this.suppliers.set(data),
      error: () => this.error.set('Errore nel caricamento fornitori')
    });
  }

  setTab(tab: 'prodotti' | 'movimenti' | 'fornitori'): void {
    this.activeTab.set(tab);
    if (tab === 'movimenti' && this.movements().length === 0) {
      this.loadMovements();
    }
  }

  openMovement(product: Product, type: 'carico' | 'scarico'): void {
    this.selectedProduct.set(product);
    this.movementType.set(type);
    this.newMovementForm = {
      productId: product.productId,
      movementType: type,
      quantity: 1,
      unitCost: product.unitCost ?? undefined,
      notes: '',
      referenceDoc: ''
    };
    this.showNewMovement.set(true);
  }

  saveProduct(): void {
    if (!this.newProductForm.name || !this.newProductForm.unit) return;
    this.saving.set(true);
    const req: CreateProductRequest = {
      name: this.newProductForm.name,
      unit: this.newProductForm.unit,
      minStockQuantity: this.newProductForm.minStockQuantity,
      reorderQuantity: this.newProductForm.reorderQuantity,
      categoryId: this.newProductForm.categoryId || undefined,
      supplierId: this.newProductForm.supplierId || undefined,
      description: this.newProductForm.description || undefined,
      sku: this.newProductForm.sku || undefined,
      unitCost: this.newProductForm.unitCost || undefined
    };
    this.productService.create(req).subscribe({
      next: () => {
        this.saving.set(false);
        this.showNewProduct.set(false);
        this.resetProductForm();
        this.loadProducts();
      },
      error: () => {
        this.saving.set(false);
        this.error.set('Errore nel salvataggio prodotto');
      }
    });
  }

  saveSupplier(): void {
    if (!this.newSupplierForm.name) return;
    this.saving.set(true);
    const req: CreateSupplierRequest = {
      name: this.newSupplierForm.name,
      contactPerson: this.newSupplierForm.contactPerson || undefined,
      phone: this.newSupplierForm.phone || undefined,
      email: this.newSupplierForm.email || undefined,
      notes: this.newSupplierForm.notes || undefined
    };
    this.supplierService.create(req).subscribe({
      next: () => {
        this.saving.set(false);
        this.showNewSupplier.set(false);
        this.resetSupplierForm();
        this.loadSuppliers();
      },
      error: () => {
        this.saving.set(false);
        this.error.set('Errore nel salvataggio fornitore');
      }
    });
  }

  saveMovement(): void {
    if (!this.newMovementForm.productId || this.newMovementForm.quantity <= 0) return;
    this.saving.set(true);
    const req: CreateStockMovementRequest = {
      productId: this.newMovementForm.productId,
      movementType: this.newMovementForm.movementType,
      quantity: this.newMovementForm.quantity,
      unitCost: this.newMovementForm.unitCost || undefined,
      notes: this.newMovementForm.notes || undefined,
      referenceDoc: this.newMovementForm.referenceDoc || undefined
    };
    this.movementService.create(req).subscribe({
      next: () => {
        this.saving.set(false);
        this.showNewMovement.set(false);
        this.selectedProduct.set(null);
        this.loadProducts();
        this.loadMovements();
      },
      error: () => {
        this.saving.set(false);
        this.error.set('Errore nel salvataggio movimento');
      }
    });
  }

  deleteProduct(id: string): void {
    if (!confirm('Eliminare questo prodotto?')) return;
    this.productService.delete(id).subscribe({
      next: () => this.loadProducts(),
      error: () => this.error.set('Errore nell\'eliminazione prodotto')
    });
  }

  deleteSupplier(id: string): void {
    if (!confirm('Eliminare questo fornitore?')) return;
    this.supplierService.delete(id).subscribe({
      next: () => this.loadSuppliers(),
      error: () => this.error.set('Errore nell\'eliminazione fornitore')
    });
  }

  barWidth(product: Product): number {
    const max = product.minStockQuantity * 2 || 1;
    return Math.min(100, Math.round((product.currentStock / max) * 100));
  }

  barColor(status: 'critico' | 'basso' | 'ok'): string {
    switch (status) {
      case 'critico': return 'bg-red-400';
      case 'basso': return 'bg-yellow-400';
      default: return 'bg-green-400';
    }
  }

  statoClass(status: 'critico' | 'basso' | 'ok'): string {
    switch (status) {
      case 'critico': return 'bg-red-100 text-red-700';
      case 'basso': return 'bg-yellow-100 text-yellow-700';
      default: return 'bg-green-100 text-green-700';
    }
  }

  movementTypeClass(type: string): string {
    switch (type) {
      case 'carico': return 'bg-green-100 text-green-700';
      case 'scarico': return 'bg-red-100 text-red-700';
      case 'rettifica': return 'bg-blue-100 text-blue-700';
      case 'rientro': return 'bg-teal-100 text-teal-700';
      default: return 'bg-slate-100 text-slate-600';
    }
  }

  formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  private resetProductForm(): void {
    this.newProductForm = {
      name: '', unit: 'pz', minStockQuantity: 0, reorderQuantity: 0,
      categoryId: '', supplierId: '', description: '', sku: '', unitCost: undefined
    };
  }

  private resetSupplierForm(): void {
    this.newSupplierForm = { name: '', contactPerson: '', phone: '', email: '', notes: '' };
  }
}
