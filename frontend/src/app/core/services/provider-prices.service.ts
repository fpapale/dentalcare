import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { ProviderPrice } from '../models/provider-price.model';

/**
 * Tariffe personali per medico (#44). Ogni medico clinico può impostare i propri
 * prezzi che sovrascrivono il listino dello studio; l'assenza di override eredita
 * il prezzo di listino.
 */
@Injectable({ providedIn: 'root' })
export class ProviderPricesService {
  private readonly base = `${environment.apiBaseUrl}/providers`;

  constructor(private http: HttpClient) {}

  /** Listino del medico: tutte le prestazioni con prezzo di listino ed eventuale override. */
  list(providerId: string): Observable<ProviderPrice[]> {
    return this.http.get<ProviderPrice[]>(`${this.base}/${providerId}/prices`);
  }

  /** Imposta (o aggiorna) l'override per una prestazione: crea una nuova versione di prezzo. */
  setOverride(providerId: string, serviceId: string, price: number): Observable<void> {
    return this.http.post<void>(`${this.base}/${providerId}/prices`, { serviceId, price });
  }

  /** Rimuove l'override: la prestazione torna al prezzo di listino. */
  removeOverride(providerId: string, serviceId: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${providerId}/prices/${serviceId}`);
  }
}
