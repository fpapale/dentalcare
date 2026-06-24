import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthService } from '../auth/auth.service';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatStreamEvent {
  event: 'meta' | 'token' | 'done';
  data: string;
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
  private readonly auth = inject(AuthService);
  private readonly baseUrl = `${environment.apiBaseUrl}/chat`;

  send(message: string, history: ChatTurn[], sessionId?: string | null): Observable<ChatResponse> {
    return this.http.post<ChatResponse>(this.baseUrl, { message, history, sessionId: sessionId ?? null });
  }

  /**
   * Streaming SSE via fetch (HttpClient non gestisce stream incrementali).
   * Emette meta (sessionId), token (chunk di testo) e done. Annulla la richiesta su unsubscribe.
   */
  sendStream(message: string, history: ChatTurn[], sessionId?: string | null): Observable<ChatStreamEvent> {
    return new Observable<ChatStreamEvent>(subscriber => {
      const controller = new AbortController();
      const token = this.auth.getToken();

      fetch(`${this.baseUrl}/stream`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        },
        body: JSON.stringify({ message, history, sessionId: sessionId ?? null }),
        signal: controller.signal
      }).then(async response => {
        if (!response.ok || !response.body) {
          subscriber.error(new Error(`stream failed: ${response.status}`));
          return;
        }
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });

          let sep: number;
          while ((sep = buffer.indexOf('\n\n')) >= 0) {
            const raw = buffer.slice(0, sep);
            buffer = buffer.slice(sep + 2);
            let event = 'message';
            const dataLines: string[] = [];
            for (const line of raw.split('\n')) {
              if (line.startsWith('event:')) event = line.slice(6).trim();
              else if (line.startsWith('data:')) dataLines.push(line.slice(5));
            }
            if (event === 'meta' || event === 'token' || event === 'done') {
              subscriber.next({ event, data: dataLines.join('\n') });
            }
          }
        }
        subscriber.complete();
      }).catch(err => {
        if (!controller.signal.aborted) subscriber.error(err);
      });

      return () => controller.abort();
    });
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
