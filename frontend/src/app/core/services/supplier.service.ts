import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Supplier, CreateSupplierRequest, UpdateSupplierRequest } from '../models/supplier.model';

@Injectable({ providedIn: 'root' })
export class SupplierService {
  private readonly base = `${environment.apiBaseUrl}/suppliers`;

  constructor(private http: HttpClient) {}

  findAll(includeInactive = false): Observable<Supplier[]> {
    const params = new HttpParams().set('includeInactive', String(includeInactive));
    return this.http.get<Supplier[]>(this.base, { params });
  }

  create(request: CreateSupplierRequest): Observable<Supplier> {
    return this.http.post<Supplier>(this.base, request);
  }

  update(id: string, request: UpdateSupplierRequest): Observable<Supplier> {
    return this.http.put<Supplier>(`${this.base}/${id}`, request);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }
}
