import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { PatientDocumentSummary, UpdatePatientDocumentRequest } from '../models/patient-document.model';

@Injectable({ providedIn: 'root' })
export class PatientDocumentService {
  constructor(private readonly http: HttpClient) {}

  private base(patientId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/documents`;
  }

  findAll(patientId: string): Observable<PatientDocumentSummary[]> {
    return this.http.get<PatientDocumentSummary[]>(this.base(patientId));
  }

  upload(patientId: string, formData: FormData): Observable<PatientDocumentSummary> {
    return this.http.post<PatientDocumentSummary>(this.base(patientId), formData);
  }

  update(patientId: string, docId: string, req: UpdatePatientDocumentRequest): Observable<PatientDocumentSummary> {
    return this.http.put<PatientDocumentSummary>(`${this.base(patientId)}/${docId}`, req);
  }

  delete(patientId: string, docId: string): Observable<void> {
    return this.http.delete<void>(`${this.base(patientId)}/${docId}`);
  }

  getContent(patientId: string, docId: string): Observable<Blob> {
    return this.http.get(`${this.base(patientId)}/${docId}/content`, { responseType: 'blob' });
  }
}
