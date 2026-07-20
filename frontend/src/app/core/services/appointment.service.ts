import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Appointment, AvailabilitySlot } from '../models/appointment.model';

export interface CreateAppointmentRequest {
  patientId: string;
  providerId: string;
  chairLabel: string;
  startsAt: string;   // ISO 8601 offset datetime
  endsAt: string;
  notes?: string;
}

export interface RescheduleAppointmentRequest {
  startsAt: string;   // ISO 8601 offset datetime
  endsAt: string;
  chairLabel: string;
}

@Injectable({ providedIn: 'root' })
export class AppointmentService {
  private readonly base = `${environment.apiBaseUrl}/appointments`;

  constructor(private http: HttpClient) {}

  findByDate(date: string, providerId?: string | null): Observable<Appointment[]> {
    let params = new HttpParams().set('date', date);
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<Appointment[]>(this.base, { params });
  }

  findByDateRange(from: string, to: string, providerId?: string | null): Observable<Appointment[]> {
    let params = new HttpParams().set('from', from).set('to', to);
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<Appointment[]>(this.base, { params });
  }

  findByPatient(patientId: string, providerId?: string | null): Observable<Appointment[]> {
    let params = new HttpParams();
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<Appointment[]>(`${this.base}/patient/${patientId}`, { params });
  }

  updateStatus(appointmentId: string, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${appointmentId}/status`, null, {
      params: new HttpParams().set('status', status)
    });
  }

  findChairLabels(): Observable<string[]> {
    return this.http.get<string[]>(`${this.base}/chairs`);
  }

  /**
   * Primi slot liberi (medico + poltrona) per una durata data.
   * providerId assente = il backend sceglie un medico disponibile e lo restituisce.
   */
  findAvailability(
    durationMin: number,
    providerId?: string | null,
    fromDate?: string | null,
    limit?: number
  ): Observable<AvailabilitySlot[]> {
    let params = new HttpParams().set('durationMin', durationMin);
    if (providerId) params = params.set('providerId', providerId);
    if (fromDate)   params = params.set('fromDate', fromDate);
    if (limit)      params = params.set('limit', limit);
    return this.http.get<AvailabilitySlot[]>(`${this.base}/availability`, { params });
  }

  create(request: CreateAppointmentRequest): Observable<void> {
    return this.http.post<void>(this.base, request);
  }

  reschedule(appointmentId: string, request: RescheduleAppointmentRequest): Observable<void> {
    return this.http.patch<void>(`${this.base}/${appointmentId}/reschedule`, request);
  }
}
