import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ChatService, ChatSessionDto, ChatMessageDto } from '../../core/services/chat.service';
import { AppSettingsService } from '../../core/services/app-settings.service';
import { MarkdownPipe } from '../../shared/pipes/markdown.pipe';

interface Message {
  role: 'user' | 'ai';
  text: string;
  time: string;
  table?: { ora: string; paziente: string; prestazione: string; stato: string }[];
}

interface Call {
  name: string;
  snippet: string;
  time: string;
  handled: boolean;
}

@Component({
  selector: 'app-segretaria',
  standalone: true,
  imports: [CommonModule, FormsModule, MarkdownPipe],
  templateUrl: './segretaria.component.html',
  styleUrl: './segretaria.component.css'
})
export class SegretariaComponent implements OnInit {
  private readonly chatService = inject(ChatService);
  private readonly appSettingsSvc = inject(AppSettingsService);
  private readonly destroyRef = inject(DestroyRef);

  inputText = '';
  isTyping = signal(false);
  currentSessionId = signal<string | null>(null);
  showHistory = signal(false);
  sessions = signal<ChatSessionDto[]>([]);
  loadingSessions = signal(false);
  loadingSession = signal(false);

  messages = signal<Message[]>([]);

  calls = signal<Call[]>([
    { name: '+39 342 *** 90', snippet: '"Vorrei spostare l\'igiene..."', time: '10:15', handled: false },
    { name: 'Marco Rossi', snippet: 'Gestita da AI', time: '09:42', handled: true },
    { name: '+39 347 *** 12', snippet: '"Appuntamento urgente..."', time: '09:10', handled: false },
  ]);

  tasks = signal([
    { text: 'Richiamare Elena Neri', sub: 'Conferma prima visita 12:00', urgent: true },
    { text: 'Firma preventivo Bianchi', sub: 'Tablet sala 3 pronto', urgent: false },
  ]);

  quickPrompts = [
    'Chi ha chiamato oggi?',
    'Stato preventivo Sig. Rossi',
    'Resoconto chiamate perse',
    'Prossimo slot disponibile chirurgia',
  ];

  private currentTime(): string {
    const now = new Date();
    return `${now.getHours()}:${now.getMinutes().toString().padStart(2, '0')}`;
  }

  ngOnInit(): void {
    this.loadSessions();
  }

  loadSessions(): void {
    this.loadingSessions.set(true);
    const days = this.appSettingsSvc.get().chatHistoryDays ?? 90;
    this.chatService.listSessions(days)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: list => { this.sessions.set(list); this.loadingSessions.set(false); },
        error: () => this.loadingSessions.set(false)
      });
  }

  openSession(session: ChatSessionDto): void {
    this.loadingSession.set(true);
    this.showHistory.set(false);
    this.chatService.getSessionMessages(session.id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (msgs: ChatMessageDto[]) => {
          this.messages.set(msgs.map(m => ({
            role: m.role === 'user' ? 'user' as const : 'ai' as const,
            text: m.content,
            time: new Date(m.createdAt).toLocaleTimeString('it', { hour: '2-digit', minute: '2-digit' })
          })));
          this.currentSessionId.set(session.id);
          this.loadingSession.set(false);
        },
        error: () => this.loadingSession.set(false)
      });
  }

  newChat(): void {
    this.messages.set([]);
    this.currentSessionId.set(null);
    this.showHistory.set(false);
  }

  deleteSession(session: ChatSessionDto, event: Event): void {
    event.stopPropagation();
    if (!confirm('Eliminare questa conversazione?')) return;
    this.chatService.deleteSession(session.id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: () => {
          this.sessions.update(list => list.filter(s => s.id !== session.id));
          if (this.currentSessionId() === session.id) {
            this.newChat();
          }
        }
      });
  }

  sendMessage(): void {
    const text = this.inputText.trim();
    if (!text) return;

    this.messages.update(msgs => [...msgs, { role: 'user', text, time: this.currentTime() }]);
    this.inputText = '';
    this.isTyping.set(true);

    const history = this.messages().slice(0, -1).map(m => ({
      role: m.role === 'user' ? 'user' as const : 'assistant' as const,
      content: m.text
    }));

    this.chatService.send(text, history, this.currentSessionId())
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: response => {
          this.isTyping.set(false);
          this.currentSessionId.set(response.sessionId);
          this.messages.update(msgs => [...msgs, { role: 'ai', text: response.text, time: this.currentTime() }]);
          this.loadSessions();
        },
        error: () => {
          this.isTyping.set(false);
          this.messages.update(msgs => [...msgs, {
            role: 'ai',
            text: 'Si è verificato un errore. Riprova più tardi.',
            time: this.currentTime()
          }]);
        }
      });
  }

  usePrompt(p: string): void {
    this.inputText = p;
  }

  getStatoClass(stato: string): string {
    switch (stato) {
      case 'ARRIVATO':  return 'bg-green-100 text-green-700';
      case 'IN SALA':   return 'bg-teal-100 text-teal-700';
      case 'CONFERMATO':return 'bg-blue-100 text-blue-700';
      case 'IN ATTESA': return 'bg-yellow-100 text-yellow-700';
      default:           return 'bg-slate-100 text-slate-600';
    }
  }

  formatSessionDate(iso: string): string {
    const d = new Date(iso);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(today.getDate() - 1);
    if (d.toDateString() === today.toDateString()) return 'Oggi';
    if (d.toDateString() === yesterday.toDateString()) return 'Ieri';
    return d.toLocaleDateString('it', { day: '2-digit', month: 'short' });
  }
}
