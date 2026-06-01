import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Holiday } from '../models/holiday.model';

@Injectable({ providedIn: 'root' })
export class HolidayService {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiBaseUrl}/holidays`;

  findInRange(from: string, to: string): Observable<Holiday[]> {
    return this.http.get<Holiday[]>(this.base, {
      params: new HttpParams().set('from', from).set('to', to)
    });
  }
}
