import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  Recall,
  RecallContact,
  CreateRecallRequest,
  CreateRecallContactRequest,
  UpdateRecallRequest,
  GenerateRecallsResponse
} from '../models/recall.model';

@Injectable({ providedIn: 'root' })
export class RecallService {
  private readonly base = `${environment.apiBaseUrl}/recalls`;

  constructor(private http: HttpClient) {}

  findAll(status?: string, priority?: string, patientId?: string): Observable<Recall[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (priority) params = params.set('priority', priority);
    if (patientId) params = params.set('patientId', patientId);
    return this.http.get<Recall[]>(this.base, { params });
  }

  findByPatient(patientId: string): Observable<Recall[]> {
    return this.findAll(undefined, undefined, patientId);
  }

  create(req: CreateRecallRequest): Observable<Recall> {
    return this.http.post<Recall>(this.base, req);
  }

  update(id: string, req: UpdateRecallRequest): Observable<Recall> {
    return this.http.put<Recall>(`${this.base}/${id}`, req);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }

  generate(intervalMonths: number = 6): Observable<GenerateRecallsResponse> {
    const params = new HttpParams().set('intervalMonths', intervalMonths.toString());
    return this.http.post<GenerateRecallsResponse>(`${this.base}/generate`, null, { params });
  }

  findContacts(recallId: string): Observable<RecallContact[]> {
    return this.http.get<RecallContact[]>(`${this.base}/${recallId}/contacts`);
  }

  addContact(recallId: string, req: CreateRecallContactRequest): Observable<RecallContact> {
    return this.http.post<RecallContact>(`${this.base}/${recallId}/contacts`, req);
  }
}
