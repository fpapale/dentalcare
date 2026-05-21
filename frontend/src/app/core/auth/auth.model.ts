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
}

export interface AuthUser {
  providerId: string;
  clinicId: string;
  role: string;
  firstName: string;
  lastName: string;
  schemaName: string;
  token: string;
}
