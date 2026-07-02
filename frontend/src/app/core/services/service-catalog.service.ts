import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AddBundleItemRequest,
  ConditionDefault,
  CreateConditionDefaultRequest,
  CreateServiceRequest,
  ServiceAdmin,
  ServiceItem,
  UpdateServiceRequest
} from '../models/service.model';

@Injectable({ providedIn: 'root' })
export class ServiceCatalogService {
  private readonly base = `${environment.apiBaseUrl}/services`;

  constructor(private http: HttpClient) {}

  findAll(toothFdi?: number): Observable<ServiceItem[]> {
    if (toothFdi != null) {
      return this.http.get<ServiceItem[]>(this.base, { params: { toothFdi: String(toothFdi) } });
    }
    return this.http.get<ServiceItem[]>(this.base);
  }

  findConditionDefaults(condition: string): Observable<ServiceItem[]> {
    return this.http.get<ServiceItem[]>(`${this.base}/condition-defaults`, { params: { condition } });
  }

  findBundle(serviceId: string): Observable<ServiceItem[]> {
    return this.http.get<ServiceItem[]>(`${this.base}/${serviceId}/bundle`);
  }

  listAdmin(): Observable<ServiceAdmin[]> {
    return this.http.get<ServiceAdmin[]>(`${this.base}/admin`);
  }

  createService(req: CreateServiceRequest): Observable<ServiceAdmin> {
    return this.http.post<ServiceAdmin>(this.base, req);
  }

  updateService(id: string, req: UpdateServiceRequest): Observable<ServiceAdmin> {
    return this.http.put<ServiceAdmin>(`${this.base}/${id}`, req);
  }

  deleteService(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }

  listConditionDefaults(): Observable<ConditionDefault[]> {
    return this.http.get<ConditionDefault[]>(`${this.base}/condition-defaults/all`);
  }

  addConditionDefault(req: CreateConditionDefaultRequest): Observable<ConditionDefault> {
    return this.http.post<ConditionDefault>(`${this.base}/condition-defaults`, req);
  }

  deleteConditionDefault(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/condition-defaults/${id}`);
  }

  addBundleItem(serviceId: string, req: AddBundleItemRequest): Observable<void> {
    return this.http.post<void>(`${this.base}/${serviceId}/bundle`, req);
  }

  deleteBundleItem(itemId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/bundle/${itemId}`);
  }
}
