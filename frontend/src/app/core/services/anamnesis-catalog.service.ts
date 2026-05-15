import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  CatalogCategory,
  CatalogItem,
  CreateCatalogCategoryRequest,
  UpdateCatalogCategoryRequest,
  CreateCatalogItemRequest,
  UpdateCatalogItemRequest
} from '../models/anamnesis-catalog.model';

@Injectable({ providedIn: 'root' })
export class AnamnesisCatalogService {
  private readonly base = `${environment.apiBaseUrl}/admin/anamnesis`;

  constructor(private http: HttpClient) {}

  findAllCategories(): Observable<CatalogCategory[]> {
    return this.http.get<CatalogCategory[]>(`${this.base}/categories`);
  }

  createCategory(req: CreateCatalogCategoryRequest): Observable<CatalogCategory> {
    return this.http.post<CatalogCategory>(`${this.base}/categories`, req);
  }

  updateCategory(id: string, req: UpdateCatalogCategoryRequest): Observable<void> {
    return this.http.put<void>(`${this.base}/categories/${id}`, req);
  }

  deleteCategory(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/categories/${id}`);
  }

  findItems(categoryId: string): Observable<CatalogItem[]> {
    return this.http.get<CatalogItem[]>(`${this.base}/categories/${categoryId}/items`);
  }

  createItem(req: CreateCatalogItemRequest): Observable<CatalogItem> {
    return this.http.post<CatalogItem>(`${this.base}/items`, req);
  }

  updateItem(id: string, req: UpdateCatalogItemRequest): Observable<void> {
    return this.http.put<void>(`${this.base}/items/${id}`, req);
  }

  deleteItem(id: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/items/${id}`);
  }
}
