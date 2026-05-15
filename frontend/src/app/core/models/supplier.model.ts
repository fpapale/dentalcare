export interface Supplier {
  supplierId: string;
  name: string;
  contactPerson: string | null;
  phone: string | null;
  email: string | null;
  notes: string | null;
  isActive: boolean;
}

export interface CreateSupplierRequest {
  name: string;
  contactPerson?: string;
  phone?: string;
  email?: string;
  notes?: string;
}

export interface UpdateSupplierRequest {
  name: string;
  contactPerson?: string;
  phone?: string;
  email?: string;
  notes?: string;
  isActive?: boolean;
}
