import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { LoginResponse } from '../../core/auth/auth.model';
import {
  CreateTenantClinicRequest,
  CreateTenantUserRequest,
  DeleteTenantRequest,
  TenantClinicDto,
  TenantDeletionPrepareResponse,
  TenantDeletionScheduledResponse,
  TenantUserDto
} from './admin-tenant.model';

@Injectable({ providedIn: 'root' })
export class AdminTenantService {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiBaseUrl}/tenant-admin`;

  getClinics(): Observable<TenantClinicDto[]> {
    return this.http.get<TenantClinicDto[]>(`${this.base}/clinics`);
  }

  createClinic(req: CreateTenantClinicRequest): Observable<TenantClinicDto> {
    return this.http.post<TenantClinicDto>(`${this.base}/clinics`, req);
  }

  updateClinic(clinicId: string, req: CreateTenantClinicRequest): Observable<TenantClinicDto> {
    return this.http.put<TenantClinicDto>(`${this.base}/clinics/${clinicId}`, req);
  }

  deleteClinic(clinicId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/clinics/${clinicId}`);
  }

  deleteTenant(): Observable<void> {
    return this.http.delete<void>(`${this.base}/tenant`);
  }

  prepareTenantDeletion(): Observable<TenantDeletionPrepareResponse> {
    return this.http.post<TenantDeletionPrepareResponse>(`${this.base}/tenant/deletion/prepare`, {});
  }

  deleteTenantGuarded(req: DeleteTenantRequest): Observable<TenantDeletionScheduledResponse> {
    return this.http.delete<TenantDeletionScheduledResponse>(`${this.base}/tenant`, { body: req });
  }

  cancelTenantDeletion(): Observable<void> {
    return this.http.post<void>(`${this.base}/tenant/deletion/cancel`, {});
  }

  getUsers(clinicId: string): Observable<TenantUserDto[]> {
    return this.http.get<TenantUserDto[]>(`${this.base}/clinics/${clinicId}/users`);
  }

  createUser(clinicId: string, req: CreateTenantUserRequest): Observable<TenantUserDto> {
    return this.http.post<TenantUserDto>(`${this.base}/clinics/${clinicId}/users`, req);
  }

  getSelfAdminClinicIds(): Observable<string[]> {
    return this.http.get<string[]>(`${this.base}/clinics/self-admin`);
  }

  addSelfAsAdmin(clinicId: string): Observable<TenantUserDto> {
    return this.http.post<TenantUserDto>(`${this.base}/clinics/${clinicId}/self-admin`, {});
  }

  removeSelfAsAdmin(clinicId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/clinics/${clinicId}/self-admin`);
  }

  enterClinic(clinicId: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.base}/clinics/${clinicId}/enter`, {});
  }
}
