export interface Product {
  productId: string;
  categoryId: string | null;
  categoryName: string | null;
  supplierId: string | null;
  supplierName: string | null;
  name: string;
  description: string | null;
  sku: string | null;
  unit: string;
  minStockQuantity: number;
  reorderQuantity: number;
  unitCost: number | null;
  currentStock: number;
  stockStatus: 'critico' | 'basso' | 'ok';
  isActive: boolean;
}

export interface ProductCategory {
  categoryId: string;
  name: string;
}

export interface CreateProductRequest {
  categoryId?: string;
  supplierId?: string;
  name: string;
  description?: string;
  sku?: string;
  unit: string;
  minStockQuantity: number;
  reorderQuantity: number;
  unitCost?: number;
}

export interface UpdateProductRequest {
  categoryId?: string;
  supplierId?: string;
  name: string;
  description?: string;
  sku?: string;
  unit: string;
  minStockQuantity: number;
  reorderQuantity: number;
  unitCost?: number;
  isActive?: boolean;
}
