import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ClinicalHistoryEntry, OdontogramSummary, TreatmentPlanSummary } from '../models/clinical-record.model';

@Injectable({ providedIn: 'root' })
export class ClinicalRecordService {
  private base(patientId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/clinical-record`;
  }

  constructor(private http: HttpClient) {}

  getDiary(patientId: string): Observable<ClinicalHistoryEntry[]> {
    return this.http.get<ClinicalHistoryEntry[]>(`${this.base(patientId)}/diary`);
  }

  getTreatmentPlans(patientId: string): Observable<TreatmentPlanSummary[]> {
    return this.http.get<TreatmentPlanSummary[]>(`${this.base(patientId)}/treatment-plans`);
  }

  getOdontogramSummary(patientId: string): Observable<OdontogramSummary> {
    return this.http.get<OdontogramSummary>(`${this.base(patientId)}/odontogram-summary`);
  }
}
