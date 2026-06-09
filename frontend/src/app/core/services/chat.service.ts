import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatRequest {
  message: string;
  history: ChatTurn[];
}

export interface ChatResponse {
  text: string;
  sessionId: string;
}

export interface ChatSessionDto {
  id: string;
  title: string;
  messageCount: number;
  createdAt: string;
}

export interface ChatMessageDto {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  createdAt: string;
}

@Injectable({ providedIn: 'root' })
export class ChatService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiBaseUrl}/chat`;

  send(message: string, history: ChatTurn[], sessionId?: string | null): Observable<ChatResponse> {
    return this.http.post<ChatResponse>(this.baseUrl, { message, history, sessionId: sessionId ?? null });
  }

  listSessions(retentionDays: number): Observable<ChatSessionDto[]> {
    return this.http.get<ChatSessionDto[]>(`${this.baseUrl}/sessions`, {
      params: { retentionDays: retentionDays.toString() }
    });
  }

  getSessionMessages(sessionId: string): Observable<ChatMessageDto[]> {
    return this.http.get<ChatMessageDto[]>(`${this.baseUrl}/sessions/${sessionId}/messages`);
  }

  deleteSession(sessionId: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/sessions/${sessionId}`);
  }
}
