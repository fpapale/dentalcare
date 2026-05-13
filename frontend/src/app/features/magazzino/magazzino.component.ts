import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-magazzino',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './magazzino.component.html',
  styleUrl: './magazzino.component.css'
})
export class MagazzinoComponent {
  prodotti = signal([
    { nome: 'Anestetico Articaina 4%', categoria: 'Farmaci', scorta: 12, minimo: 20, unita: 'fiale', stato: 'critico' },
    { nome: 'Guanti lattice M', categoria: 'DPI', scorta: 180, minimo: 100, unita: 'pz', stato: 'ok' },
    { nome: 'Mascherine chirurgiche', categoria: 'DPI', scorta: 45, minimo: 50, unita: 'pz', stato: 'basso' },
    { nome: 'Resina composita A2', categoria: 'Materiali', scorta: 8, minimo: 5, unita: 'siringhe', stato: 'ok' },
    { nome: 'Filo da sutura 3-0', categoria: 'Chirurgia', scorta: 3, minimo: 10, unita: 'confezioni', stato: 'critico' },
    { nome: 'Cemento vetroionomero', categoria: 'Materiali', scorta: 6, minimo: 4, unita: 'capsule', stato: 'ok' },
    { nome: 'Bisturi monouso n.15', categoria: 'Chirurgia', scorta: 22, minimo: 15, unita: 'pz', stato: 'ok' },
    { nome: 'Garze sterili 10x10', categoria: 'Medicazione', scorta: 38, minimo: 50, unita: 'conf', stato: 'basso' },
  ]);

  get criticoCount(): number { return this.prodotti().filter(p => p.stato === 'critico').length; }
  get bassoCount(): number { return this.prodotti().filter(p => p.stato === 'basso').length; }
  get okCount(): number { return this.prodotti().filter(p => p.stato === 'ok').length; }
  get hasCritici(): boolean { return this.criticoCount > 0; }

  statoClass(stato: string): string {
    switch (stato) {
      case 'critico': return 'bg-red-100 text-red-700';
      case 'basso': return 'bg-yellow-100 text-yellow-700';
      default: return 'bg-green-100 text-green-700';
    }
  }

  barWidth(scorta: number, minimo: number): number {
    return Math.min(100, Math.round((scorta / (minimo * 2)) * 100));
  }

  barColor(stato: string): string {
    switch (stato) {
      case 'critico': return 'bg-red-400';
      case 'basso': return 'bg-yellow-400';
      default: return 'bg-green-400';
    }
  }
}
