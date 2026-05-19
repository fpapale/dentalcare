import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Diagnosi, CreateDiagnosiRequest } from '../models/diagnosi.model';

@Injectable({ providedIn: 'root' })
export class DiagnosiService {
  private base(patientId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/diagnosi`;
  }

  constructor(private http: HttpClient) {}

  findAll(patientId: string): Observable<Diagnosi[]> {
    return this.http.get<Diagnosi[]>(this.base(patientId));
  }

  create(patientId: string, request: CreateDiagnosiRequest): Observable<Diagnosi> {
    return this.http.post<Diagnosi>(this.base(patientId), request);
  }

  update(patientId: string, diagnosiId: string, request: Partial<CreateDiagnosiRequest> & { status?: string }): Observable<Diagnosi> {
    return this.http.put<Diagnosi>(`${this.base(patientId)}/${diagnosiId}`, request);
  }

  delete(patientId: string, diagnosiId: string): Observable<void> {
    return this.http.delete<void>(`${this.base(patientId)}/${diagnosiId}`);
  }
}
