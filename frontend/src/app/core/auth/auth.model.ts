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
  mustChangePassword: boolean;
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
  mustChangePassword?: boolean;
}

export interface ClinicOption {
  providerId: string;
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
  mustChangePassword?: boolean;
}

export interface LoginConfirmRequest {
  email: string;
  password: string;
  clinicId: string;
  providerId?: string;
}

export interface DemoConfigResponse {
  enabled: boolean;
  email?: string;
  password?: string;
}
