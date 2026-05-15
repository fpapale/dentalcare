import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { CreatePlanFromOdontogramRequest, TreatmentPlan, TreatmentPlanSummary } from '../models/treatment-plan.model';

@Injectable({ providedIn: 'root' })
export class TreatmentPlanService {
  private readonly base = `${environment.apiBaseUrl}/treatment-plans`;

  constructor(private http: HttpClient) {}

  findByPatient(patientId: string): Observable<TreatmentPlanSummary[]> {
    return this.http.get<TreatmentPlanSummary[]>(this.base, { params: { patientId } });
  }

  findById(planId: string): Observable<TreatmentPlan> {
    return this.http.get<TreatmentPlan>(`${this.base}/${planId}`);
  }

  create(patientId: string, name: string, description?: string): Observable<string> {
    return this.http.post<string>(this.base, { patientId, name, description });
  }

  updateName(planId: string, name: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${planId}/name`, { name });
  }

  updateStatus(planId: string, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${planId}/status`, { status });
  }

  addItem(planId: string, item: {
    serviceId: string;
    providerId?: string;
    toothNumber?: string;
    quadrant?: number;
    plannedPrice?: number;
    priority?: number;
    plannedDate?: string;
    clinicalNotes?: string;
  }): Observable<string> {
    return this.http.post<string>(`${this.base}/${planId}/items`, item);
  }

  updateItemStatus(planId: string, itemId: string, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${planId}/items/${itemId}/status`, { status });
  }

  deleteItem(planId: string, itemId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${planId}/items/${itemId}`);
  }

  deletePlan(planId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${planId}`);
  }

  createFromOdontogram(request: CreatePlanFromOdontogramRequest): Observable<string> {
    return this.http.post<string>(`${this.base}/from-odontogram`, request);
  }
}
