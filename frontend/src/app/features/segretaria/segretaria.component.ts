import { Component, DestroyRef, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ChatService } from '../../core/services/chat.service';

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
  imports: [CommonModule, FormsModule],
  templateUrl: './segretaria.component.html',
  styleUrl: './segretaria.component.css'
})
export class SegretariaComponent {
  private readonly chatService = inject(ChatService);
  private readonly destroyRef = inject(DestroyRef);

  inputText = '';
  isTyping = signal(false);

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

  sendMessage() {
    const text = this.inputText.trim();
    if (!text) return;

    this.messages.update(msgs => [...msgs, { role: 'user', text, time: this.currentTime() }]);
    this.inputText = '';
    this.isTyping.set(true);

    const history = this.messages().slice(0, -1).map(m => ({
      role: m.role === 'user' ? 'user' as const : 'assistant' as const,
      content: m.text
    }));

    this.chatService.send(text, history).pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: response => {
        this.isTyping.set(false);
        this.messages.update(msgs => [...msgs, { role: 'ai', text: response.text, time: this.currentTime() }]);
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

  usePrompt(p: string) {
    this.inputText = p;
  }

  getStatoClass(stato: string): string {
    switch (stato) {
      case 'ARRIVATO': return 'bg-green-100 text-green-700';
      case 'IN SALA': return 'bg-teal-100 text-teal-700';
      case 'CONFERMATO': return 'bg-blue-100 text-blue-700';
      case 'IN ATTESA': return 'bg-yellow-100 text-yellow-700';
      default: return 'bg-slate-100 text-slate-600';
    }
  }
}
