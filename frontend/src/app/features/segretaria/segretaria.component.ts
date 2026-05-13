import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

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
  inputText = '';
  isTyping = signal(false);

  messages = signal<Message[]>([
    {
      role: 'user',
      text: 'Mostrami gli appuntamenti di oggi del dottor Verdi.',
      time: '10:42'
    },
    {
      role: 'ai',
      text: 'Certamente Giulia. Ecco la lista degli appuntamenti previsti per oggi per il Dottor Verdi presso lo studio di Roma. Ci sono 4 visite confermate e 1 in attesa di conferma telefonica.',
      time: 'Ora',
      table: [
        { ora: '09:00', paziente: 'Marco Rossi', prestazione: 'Igiene dentale', stato: 'ARRIVATO' },
        { ora: '10:30', paziente: 'Simona Verdi', prestazione: 'Controllo ortodonzia', stato: 'IN SALA' },
        { ora: '11:15', paziente: 'Luca Bianchi', prestazione: 'Estrazione', stato: 'CONFERMATO' },
        { ora: '12:00', paziente: 'Elena Neri', prestazione: 'Prima visita', stato: 'IN ATTESA' },
      ]
    }
  ]);

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

  sendMessage() {
    const text = this.inputText.trim();
    if (!text) return;
    const now = new Date();
    const time = `${now.getHours()}:${now.getMinutes().toString().padStart(2,'0')}`;
    this.messages.update(msgs => [...msgs, { role: 'user', text, time }]);
    this.inputText = '';
    this.isTyping.set(true);
    setTimeout(() => {
      this.isTyping.set(false);
      this.messages.update(msgs => [...msgs, {
        role: 'ai',
        text: 'Sto elaborando la tua richiesta. Un momento...',
        time: 'Ora'
      }]);
    }, 1200);
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
