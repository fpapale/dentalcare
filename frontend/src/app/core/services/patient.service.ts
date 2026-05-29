import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { PatientDetail, PatientListItem } from '../models/patient.model';

export interface CreatePatientRequest {
  firstName: string;
  lastName: string;
  fiscalCode?: string;
  birthDate?: string;
  phone?: string;
  email?: string;
  addressLine1?: string;
  city?: string;
  province?: string;
  postalCode?: string;
  notes?: string;
  primaryProviderId?: string;
}

export interface UpdatePatientRequest {
  firstName: string;
  lastName: string;
  fiscalCode?: string;
  birthDate?: string;
  phone?: string;
  email?: string;
  addressLine1?: string;
  city?: string;
  province?: string;
  postalCode?: string;
  notes?: string;
  primaryProviderId?: string;
}

@Injectable({ providedIn: 'root' })
export class PatientService {
  private readonly base = `${environment.apiBaseUrl}/patients`;

  constructor(private http: HttpClient) {}

  findAll(search?: string, providerId?: string | null): Observable<PatientListItem[]> {
    let params = new HttpParams();
    if (search) params = params.set('search', search);
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<PatientListItem[]>(this.base, { params });
  }

  findById(id: string, providerId?: string | null): Observable<PatientDetail> {
    let params = new HttpParams();
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<PatientDetail>(`${this.base}/${id}`, { params });
  }

  create(request: CreatePatientRequest): Observable<void> {
    return this.http.post<void>(this.base, request);
  }

  update(id: string, request: UpdatePatientRequest): Observable<void> {
    return this.http.put<void>(`${this.base}/${id}`, request);
  }

  updatePhoto(patientId: string, photoDataUrl: string): Observable<void> {
    return this.http.put<void>(`${this.base}/${patientId}/photo`, { photoDataUrl });
  }
}
