import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Provider, CreateProviderRequest, UpdateProviderProfileRequest } from '../models/provider.model';

@Injectable({ providedIn: 'root' })
export class ProviderService {
  private readonly base = `${environment.apiBaseUrl}/providers`;

  constructor(private http: HttpClient) {}

  findAll(activeOnly = true): Observable<Provider[]> {
    return this.http.get<Provider[]>(this.base, { params: { activeOnly: String(activeOnly) } });
  }

  findById(id: string): Observable<Provider> {
    return this.http.get<Provider>(`${this.base}/${id}`);
  }

  create(req: CreateProviderRequest): Observable<Provider> {
    return this.http.post<Provider>(this.base, req);
  }

  updateProfile(id: string, req: UpdateProviderProfileRequest): Observable<void> {
    return this.http.put<void>(`${this.base}/${id}/profile`, req);
  }

  updateBilling(id: string, req: Partial<Provider>): Observable<void> {
    return this.http.put<void>(`${this.base}/${id}/billing`, req);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }

  updatePhoto(id: string, photoDataUrl: string): Observable<void> {
    return this.http.put<void>(`${this.base}/${id}/photo`, { photoDataUrl });
  }
}
