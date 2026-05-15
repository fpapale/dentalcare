import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Invoice, InvoiceDetail } from '../models/invoice.model';

@Injectable({ providedIn: 'root' })
export class InvoiceService {
  private readonly base = `${environment.apiBaseUrl}/invoices`;

  constructor(private http: HttpClient) {}

  findAll(status?: string, providerId?: string): Observable<Invoice[]> {
    let params = new HttpParams();
    if (status) params = params.set('status', status);
    if (providerId) params = params.set('providerId', providerId);
    return this.http.get<Invoice[]>(this.base, { params });
  }

  findById(id: string): Observable<InvoiceDetail> {
    return this.http.get<InvoiceDetail>(`${this.base}/${id}`);
  }

  createFromEstimate(req: {
    estimateId: string;
    issuerType: string;
    providerId?: string;
    documentType?: string;
    dueDate?: string;
    notes?: string;
    paymentMethod?: string;
  }): Observable<string> {
    return this.http.post<string>(`${this.base}/from-estimate`, req);
  }

  update(id: string, req: {
    documentType?: string;
    invoiceDate?: string;
    dueDate?: string;
    notes?: string;
    paymentMethod?: string;
  }): Observable<void> {
    return this.http.patch<void>(`${this.base}/${id}`, req);
  }

  updateStatus(id: string, status: string): Observable<void> {
    return this.http.patch<void>(`${this.base}/${id}/status`, { status });
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }

  addLine(id: string, req: {
    description: string;
    toothInfo?: string;
    quantity?: number;
    unitPrice?: number;
    discountAmount?: number;
    vatRate?: number;
  }): Observable<string> {
    return this.http.post<string>(`${this.base}/${id}/lines`, req);
  }

  deleteLine(id: string, lineId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}/lines/${lineId}`);
  }
}
