import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-fatturazione',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="flex flex-col items-center justify-center h-full text-slate-400 gap-4 p-10">
      <span class="material-symbols-outlined text-[64px] text-slate-300">receipt_long</span>
      <h2 class="text-xl font-bold text-slate-600">Fatturazione</h2>
      <p class="text-sm text-center max-w-sm">Il modulo di fatturazione è in fase di sviluppo. Sarà disponibile nella prossima versione.</p>
      <div class="mt-4 px-4 py-2 bg-teal-50 border border-teal-200 rounded-lg text-xs text-teal-700 font-semibold">
        🚧 Coming soon
      </div>
    </div>
  `
})
export class FatturazioneComponent {}
