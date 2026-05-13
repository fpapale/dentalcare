import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ToothCondition, SaveOdontogramRequest } from '../models/odontogram.model';

@Injectable({ providedIn: 'root' })
export class OdontogramService {
  constructor(private readonly http: HttpClient) {}

  get(patientId: string): Observable<ToothCondition[]> {
    return this.http.get<ToothCondition[]>(
      `${environment.apiBaseUrl}/patients/${patientId}/odontogram`
    );
  }

  save(patientId: string, request: SaveOdontogramRequest): Observable<void> {
    return this.http.put<void>(
      `${environment.apiBaseUrl}/patients/${patientId}/odontogram`,
      request
    );
  }
}
