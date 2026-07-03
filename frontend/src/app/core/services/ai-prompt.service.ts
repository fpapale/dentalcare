import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AiPrompt } from '../models/ai-prompt.model';

@Injectable({ providedIn: 'root' })
export class AiPromptService {
  private readonly base = `${environment.apiBaseUrl}/admin/ai-prompts`;

  constructor(private http: HttpClient) {}

  list(): Observable<AiPrompt[]> {
    return this.http.get<AiPrompt[]>(this.base);
  }

  update(key: string, locale: string, value: string): Observable<void> {
    return this.http.put<void>(`${this.base}/${key}/${locale}`, { value });
  }

  reset(key: string, locale: string): Observable<void> {
    return this.http.delete<void>(`${this.base}/${key}/${locale}`);
  }
}
