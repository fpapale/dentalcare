import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Provider } from '../models/provider.model';

@Injectable({ providedIn: 'root' })
export class ProviderService {
  private readonly base = `${environment.apiBaseUrl}/providers`;

  constructor(private http: HttpClient) {}

  findAll(activeOnly = true): Observable<Provider[]> {
    return this.http.get<Provider[]>(this.base, { params: { activeOnly: String(activeOnly) } });
  }
}
