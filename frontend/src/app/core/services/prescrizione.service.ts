import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Prescrizione, CreatePrescrizioneRequest } from '../models/prescrizione.model';

@Injectable({ providedIn: 'root' })
export class PrescrizioneService {
  private base(patientId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/prescrizioni`;
  }

  constructor(private http: HttpClient) {}

  findAll(patientId: string): Observable<Prescrizione[]> {
    return this.http.get<Prescrizione[]>(this.base(patientId));
  }

  create(patientId: string, request: CreatePrescrizioneRequest): Observable<Prescrizione> {
    return this.http.post<Prescrizione>(this.base(patientId), request);
  }

  update(patientId: string, prescrizioneId: string, request: Partial<CreatePrescrizioneRequest> & { active?: boolean }): Observable<Prescrizione> {
    return this.http.put<Prescrizione>(`${this.base(patientId)}/${prescrizioneId}`, request);
  }

  delete(patientId: string, prescrizioneId: string): Observable<void> {
    return this.http.delete<void>(`${this.base(patientId)}/${prescrizioneId}`);
  }
}
