export interface TenantClinicDto {
  id: string;
  name: string;
  legalName: string | null;
  city: string | null;
  province: string | null;
  addressLine1: string | null;
  postalCode: string | null;
  phone: string | null;
  email: string | null;
  active: boolean;
}

export interface CreateTenantClinicRequest {
  name: string;
  legalName?: string;
  city?: string;
  province?: string;
  addressLine1?: string;
  postalCode?: string;
  phone?: string;
  email?: string;
}

export interface TenantUserDto {
  id: string;
  clinicId: string;
  firstName: string;
  lastName: string;
  email: string;
  role: string;
  active: boolean;
}

export interface CreateTenantUserRequest {
  firstName: string;
  lastName: string;
  email: string;
  role: string;
}
