import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AnamnesisCategoryDto, AnamnesisDiff, SaveAnamnesisRequest } from '../models/anamnesis.model';

@Injectable({ providedIn: 'root' })
export class AnamnesisService {
  constructor(private readonly http: HttpClient) {}

  getAnamnesis(patientId: string): Observable<AnamnesisCategoryDto[]> {
    return this.http.get<AnamnesisCategoryDto[]>(`/api/patients/${patientId}/anamnesis`);
  }

  saveAnamnesis(patientId: string, request: SaveAnamnesisRequest): Observable<void> {
    return this.http.put<void>(`/api/patients/${patientId}/anamnesis`, request);
  }

  getDiff(patientId: string): Observable<AnamnesisDiff> {
    return this.http.get<AnamnesisDiff>(`/api/patients/${patientId}/anamnesis/diff`);
  }
}
