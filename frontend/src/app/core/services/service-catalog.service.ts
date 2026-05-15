import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ServiceItem } from '../models/service.model';

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
}
