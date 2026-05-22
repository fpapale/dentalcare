export interface LoginRequest {
  clinicId: string;
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  providerId: string;
  clinicId: string;
  role: string;
  firstName: string;
  lastName: string;
  schemaName: string;
  tenantName: string;
}

export interface AuthUser {
  providerId: string;
  clinicId: string;
  role: string;
  firstName: string;
  lastName: string;
  schemaName: string;
  tenantName: string;
  token: string;
}

export interface ClinicOption {
  clinicId: string;
  clinicName: string;
  role: string;
  isTenantAdmin: boolean;
  schemaName: string;
  tenantName: string;
}

export interface LoginPreflightResponse {
  type: 'direct' | 'choose';
  email: string;
  token?: string;
  providerId?: string;
  clinicId?: string;
  role?: string;
  firstName?: string;
  lastName?: string;
  schemaName?: string;
  tenantName?: string;
  options?: ClinicOption[];
}

export interface LoginConfirmRequest {
  email: string;
  password: string;
  clinicId: string;
}
