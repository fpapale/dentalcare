import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Estimate } from '../models/estimate.model';

@Injectable({ providedIn: 'root' })
export class EstimateService {
  private readonly base = `${environment.apiBaseUrl}/estimates`;

  constructor(private http: HttpClient) {}

  findAll(status?: string): Observable<Estimate[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    return this.http.get<Estimate[]>(this.base, { params });
  }

  findByPatient(patientId: string): Observable<Estimate[]> {
    return this.http.get<Estimate[]>(`${this.base}/patient/${patientId}`);
  }
}
