import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { StockMovement, CreateStockMovementRequest } from '../models/stock-movement.model';

@Injectable({ providedIn: 'root' })
export class StockMovementService {
  private readonly base = `${environment.apiBaseUrl}/stock-movements`;

  constructor(private http: HttpClient) {}

  findAll(productId?: string): Observable<StockMovement[]> {
    let params = new HttpParams();
    if (productId) params = params.set('productId', productId);
    return this.http.get<StockMovement[]>(this.base, { params });
  }

  create(request: CreateStockMovementRequest): Observable<StockMovement> {
    return this.http.post<StockMovement>(this.base, request);
  }
}
