import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ServiceItem } from '../models/service.model';

@Injectable({ providedIn: 'root' })
export class ServiceCatalogService {
  private readonly base = `${environment.apiBaseUrl}/services`;

  constructor(private http: HttpClient) {}

  findAll(): Observable<ServiceItem[]> {
    return this.http.get<ServiceItem[]>(this.base);
  }
}
