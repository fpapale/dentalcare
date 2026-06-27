import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { PatientAnalysis, ReviewAnalysisRequest } from '../models/patient-analysis.model';
import { AuthService } from '../auth/auth.service';

@Injectable({ providedIn: 'root' })
export class PatientAnalysisService {
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);

  private base(patientId: string, docId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/documents/${docId}/analyses`;
  }

  start(patientId: string, docId: string): Observable<PatientAnalysis> {
    return this.http.post<PatientAnalysis>(this.base(patientId, docId), {});
  }

  list(patientId: string, docId: string): Observable<PatientAnalysis[]> {
    return this.http.get<PatientAnalysis[]>(this.base(patientId, docId));
  }

  get(patientId: string, docId: string, analysisId: string): Observable<PatientAnalysis> {
    return this.http.get<PatientAnalysis>(`${this.base(patientId, docId)}/${analysisId}`);
  }

  review(patientId: string, docId: string, analysisId: string, req: ReviewAnalysisRequest): Observable<PatientAnalysis> {
    return this.http.put<PatientAnalysis>(`${this.base(patientId, docId)}/${analysisId}/review`, req);
  }

  /** SSE stream of analysis status. Caller must call .close() when done.
   *  JWT is passed as ?token= query param because EventSource cannot send headers.
   *  The backend JwtAuthenticationFilter already supports this query parameter. */
  streamStatus(patientId: string, docId: string, analysisId: string): EventSource {
    const token = this.auth.getToken() ?? '';
    const url = `${this.base(patientId, docId)}/${analysisId}/stream?token=${encodeURIComponent(token)}`;
    return new EventSource(url);
  }
}
