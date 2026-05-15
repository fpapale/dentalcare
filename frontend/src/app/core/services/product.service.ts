import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Product, ProductCategory, CreateProductRequest, UpdateProductRequest } from '../models/product.model';

@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly base = `${environment.apiBaseUrl}/products`;
  private readonly categoryBase = `${environment.apiBaseUrl}/product-categories`;

  constructor(private http: HttpClient) {}

  findAll(lowStockOnly = false): Observable<Product[]> {
    const params = new HttpParams().set('lowStockOnly', String(lowStockOnly));
    return this.http.get<Product[]>(this.base, { params });
  }

  findCategories(): Observable<ProductCategory[]> {
    return this.http.get<ProductCategory[]>(this.categoryBase);
  }

  create(request: CreateProductRequest): Observable<Product> {
    return this.http.post<Product>(this.base, request);
  }

  update(id: string, request: UpdateProductRequest): Observable<Product> {
    return this.http.put<Product>(`${this.base}/${id}`, request);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${id}`);
  }
}
