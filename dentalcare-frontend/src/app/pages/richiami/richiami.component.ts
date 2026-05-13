import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-richiami',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './richiami.component.html',
  styleUrl: './richiami.component.css'
})
export class RichiamiComponent {
  richiami = signal([
    { paziente: 'Simona Verdi', initials: 'SV', tipo: 'Controllo annuale', ultimaVisita: '12 Nov 2023', scadenza: '12 Nov 2024', telefono: '+39 345 1234567', stato: 'Da contattare', urgenza: 'alta' },
    { paziente: 'Mario Rossi', initials: 'MR', tipo: 'Igiene semestrale', ultimaVisita: '05 Mag 2024', scadenza: '05 Nov 2024', telefono: '+39 347 1122334', stato: 'Contattato', urgenza: 'media' },
    { paziente: 'Laura Neri', initials: 'LN', tipo: 'Controllo ortodontico', ultimaVisita: '18 Ago 2024', scadenza: '18 Feb 2025', telefono: '+39 331 9876543', stato: 'In attesa', urgenza: 'bassa' },
    { paziente: 'Michael Chen', initials: 'MC', tipo: 'Controllo impianto', ultimaVisita: '01 Gen 2024', scadenza: '01 Gen 2025', telefono: '+1 555 987-6543', stato: 'Da contattare', urgenza: 'alta' },
    { paziente: 'Elena Rodriguez', initials: 'ER', tipo: 'Follow-up estrazione', ultimaVisita: '15 Set 2024', scadenza: '15 Mar 2025', telefono: '+1 555 456-7890', stato: 'Confermato', urgenza: 'bassa' },
  ]);

  statoClass(stato: string): string {
    switch (stato) {
      case 'Da contattare': return 'bg-red-100 text-red-700';
      case 'Contattato': return 'bg-yellow-100 text-yellow-700';
      case 'In attesa': return 'bg-blue-100 text-blue-700';
      case 'Confermato': return 'bg-green-100 text-green-700';
      default: return 'bg-slate-100 text-slate-600';
    }
  }

  urgenzaDot(u: string): string {
    switch (u) {
      case 'alta': return 'bg-red-500';
      case 'media': return 'bg-yellow-400';
      default: return 'bg-green-400';
    }
  }
}
