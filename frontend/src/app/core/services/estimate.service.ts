import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Estimate, EstimateDetail, PlanItemCoverage } from '../models/estimate.model';

@Injectable({ providedIn: 'root' })
export class EstimateService {
  private readonly base = `${environment.apiBaseUrl}/estimates`;

  constructor(private http: HttpClient) {}

  findAll(status?: string, providerId?: string): Observable<Estimate[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<Estimate[]>(this.base, { params });
  }

  findByPatient(patientId: string): Observable<Estimate[]> {
    return this.http.get<Estimate[]>(`${this.base}/patient/${patientId}`);
  }

  findByPlan(planId: string): Observable<Estimate[]> {
    return this.http.get<Estimate[]>(`${this.base}/by-plan/${planId}`);
  }

  findById(estimateId: string): Observable<EstimateDetail> {
    return this.http.get<EstimateDetail>(`${this.base}/${estimateId}`);
  }

  create(request: {
    patientId: string;
    treatmentPlanId?: string;
    createdByProviderId?: string;
    title?: string;
    notes?: string;
    validUntil?: string;
  }): Observable<string> {
    return this.http.post<string>(this.base, request);
  }

  updateHeader(estimateId: string, request: {
    title?: string;
    notes?: string;
    validUntil?: string;
  }): Observable<void> {
    return this.http.patch<void>(`${this.base}/${estimateId}`, request);
  }

  updateStatus(estimateId: string, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${estimateId}/status`, { status });
  }

  addLine(estimateId: string, request: {
    serviceId: string;
    treatmentPlanItemId?: string;
    descriptionOverride?: string;
    toothSnapshot?: string;
    quantity?: number;
    unitPrice?: number;
    discountAmount?: number;
    vatRate?: number;
  }): Observable<string> {
    return this.http.post<string>(`${this.base}/${estimateId}/lines`, request);
  }

  deleteLine(estimateId: string, lineId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${estimateId}/lines/${lineId}`);
  }

  delete(estimateId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${estimateId}`);
  }

  getPlanCoverage(planId: string): Observable<PlanItemCoverage[]> {
    return this.http.get<PlanItemCoverage[]>(`${this.base}/plan-coverage/${planId}`);
  }
}
