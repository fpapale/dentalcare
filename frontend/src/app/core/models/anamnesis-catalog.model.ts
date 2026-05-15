export interface CatalogCategory {
  id: string;
  code: string;
  name: string;
  description: string | null;
  icon: string | null;
  sortOrder: number;
  enabled: boolean;
  itemsCount: number;
}

export interface CatalogItem {
  id: string;
  categoryId: string;
  code: string;
  label: string;
  description: string | null;
  isAlert: boolean;
  sortOrder: number;
  enabled: boolean;
}

export interface CreateCatalogCategoryRequest {
  code: string;
  name: string;
  description?: string;
  icon?: string;
  sortOrder: number;
}

export interface UpdateCatalogCategoryRequest {
  name: string;
  description?: string;
  icon?: string;
  sortOrder: number;
  enabled: boolean;
}

export interface CreateCatalogItemRequest {
  categoryId: string;
  code: string;
  label: string;
  description?: string;
  isAlert: boolean;
  sortOrder: number;
}

export interface UpdateCatalogItemRequest {
  label: string;
  description?: string;
  isAlert: boolean;
  sortOrder: number;
  enabled: boolean;
}
