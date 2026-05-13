import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Dashboard } from '../models/dashboard.model';

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly base = `${environment.apiBaseUrl}/dashboard`;

  constructor(private http: HttpClient) {}

  getDashboard(providerId?: string | null): Observable<Dashboard> {
    const params = providerId ? new HttpParams().set('providerId', providerId) : undefined;
    return this.http.get<Dashboard>(this.base, { params });
  }
}
