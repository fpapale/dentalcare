import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ClinicBilling } from '../models/clinic-billing.model';
import { ClinicSchedule } from '../models/clinic-schedule.model';

@Injectable({ providedIn: 'root' })
export class ClinicSettingsService {
  private readonly base = `${environment.apiBaseUrl}/settings/clinic`;

  constructor(private http: HttpClient) {}

  get(): Observable<ClinicBilling> {
    return this.http.get<ClinicBilling>(this.base);
  }

  update(data: Partial<ClinicBilling>): Observable<void> {
    return this.http.put<void>(this.base, data);
  }

  findAll(): Observable<ClinicBilling[]> {
    return this.http.get<ClinicBilling[]>(`${environment.apiBaseUrl}/settings/clinics`);
  }

  create(data: Partial<ClinicBilling>): Observable<ClinicBilling> {
    return this.http.post<ClinicBilling>(`${environment.apiBaseUrl}/settings/clinics`, data);
  }

  /** Orari studio usati dalla proposta di disponibilità appuntamenti (#31). */
  getSchedule(): Observable<ClinicSchedule> {
    return this.http.get<ClinicSchedule>(`${environment.apiBaseUrl}/settings/schedule`);
  }

  updateSchedule(data: ClinicSchedule): Observable<void> {
    return this.http.put<void>(`${environment.apiBaseUrl}/settings/schedule`, data);
  }
}
