import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AiPromptService } from '../../core/services/ai-prompt.service';
import { AiPrompt } from '../../core/models/ai-prompt.model';

/**
 * Pannello admin per la gestione dei prompt AI (multilingua).
 * L'admin di studio può solo modificare i valori per lingua (override) o ripristinare il
 * default globale. Le chiavi sono definite dagli sviluppatori (non creabili/eliminabili qui).
 */
@Component({
  selector: 'app-ai-prompts',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="space-y-4">
      <div class="flex items-start gap-2">
        <span class="material-symbols-outlined text-[20px] text-teal-600">smart_toy</span>
        <div>
          <h3 class="text-sm font-bold text-slate-800">Prompt Assistente AI</h3>
          <p class="text-xs text-slate-500 mt-0.5">
            Personalizza le istruzioni dell'assistente per il tuo studio, per lingua.
            Le modifiche hanno effetto immediato, senza riavvio.
          </p>
        </div>
      </div>

      @if (loading()) {
        <div class="bg-white rounded-xl border border-slate-200 p-6 animate-pulse">
          <div class="h-4 w-48 bg-slate-200 rounded mb-3"></div>
          <div class="h-24 w-full bg-slate-100 rounded"></div>
        </div>
      } @else {
        @for (p of prompts(); track p.key) {
          <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 space-y-3">
            <div class="flex items-center justify-between gap-2">
              <div>
                <p class="text-sm font-bold text-slate-800">{{ p.description }}</p>
                <p class="text-[11px] text-slate-400 font-mono">{{ p.key }}</p>
              </div>
            </div>

            <!-- Locale tabs -->
            <div class="flex gap-1 border-b border-slate-100">
              @for (loc of p.locales; track loc.locale) {
                <button (click)="setLocale(p.key, loc.locale)"
                  class="px-3 py-1.5 text-xs font-semibold rounded-t-lg transition-colors flex items-center gap-1.5"
                  [class.text-teal-700]="activeLocale(p.key) === loc.locale"
                  [class.border-b-2]="activeLocale(p.key) === loc.locale"
                  [class.border-teal-500]="activeLocale(p.key) === loc.locale"
                  [class.text-slate-400]="activeLocale(p.key) !== loc.locale">
                  {{ localeLabel(loc.locale) }}
                  @if (loc.overridden) {
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400" title="Personalizzato"></span>
                  }
                </button>
              }
            </div>

            @for (loc of p.locales; track loc.locale) {
              @if (activeLocale(p.key) === loc.locale) {
                <div class="space-y-2">
                  @if (loc.overridden) {
                    <span class="inline-flex items-center gap-1 text-[11px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-full">
                      <span class="material-symbols-outlined text-[12px]">edit</span> Personalizzato per lo studio
                    </span>
                  } @else {
                    <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-400 bg-slate-50 px-2 py-0.5 rounded-full">
                      Default globale
                    </span>
                  }
                  <textarea [ngModel]="draft(p.key, loc.locale)"
                    (ngModelChange)="onDraftChange(p.key, loc.locale, $event)"
                    rows="14"
                    class="w-full border border-slate-200 rounded-xl px-3 py-2.5 text-xs font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-teal-400"></textarea>

                  <div class="flex items-center gap-2 flex-wrap">
                    <button (click)="save(p.key, loc.locale)"
                      [disabled]="!isDirty(p.key, loc.locale) || saving() === p.key + '|' + loc.locale"
                      class="px-4 py-2 bg-teal-600 text-white text-xs font-semibold rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5">
                      @if (saving() === p.key + '|' + loc.locale) {
                        <span class="material-symbols-outlined text-[14px] animate-spin">progress_activity</span>
                      }
                      Salva
                    </button>
                    <button (click)="restoreFactory(p.key, loc.locale)"
                      [disabled]="saving() === p.key + '|' + loc.locale"
                      title="Riporta il prompt al testo predefinito di fabbrica e rimuove la personalizzazione dello studio"
                      class="px-4 py-2 border border-slate-200 text-slate-600 text-xs font-semibold rounded-lg hover:bg-slate-50 transition-colors flex items-center gap-1.5">
                      <span class="material-symbols-outlined text-[14px]">restart_alt</span>
                      Ripristina predefinito
                    </button>
                    @if (savedFlag() === p.key + '|' + loc.locale) {
                      <span class="text-xs text-teal-600 font-semibold flex items-center gap-1">
                        <span class="material-symbols-outlined text-[14px]">check_circle</span> Salvato
                      </span>
                    }
                  </div>
                </div>
              }
            }
          </div>
        }
      }
    </div>
  `
})
export class AiPromptsComponent implements OnInit {
  private readonly svc = inject(AiPromptService);

  prompts = signal<AiPrompt[]>([]);
  loading = signal(true);
  saving = signal<string | null>(null);
  savedFlag = signal<string | null>(null);

  private readonly locales = new Map<string, string>();   // key -> active locale
  private readonly drafts = new Map<string, string>();     // key|locale -> draft value

  private readonly localeLabels: Record<string, string> = {
    it: 'Italiano', en: 'English', de: 'Deutsch', fr: 'Français'
  };

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading.set(true);
    this.svc.list().subscribe({
      next: list => {
        this.prompts.set(list);
        for (const p of list) {
          if (!this.locales.has(p.key)) this.locales.set(p.key, p.locales[0]?.locale ?? 'it');
          for (const loc of p.locales) {
            this.drafts.set(p.key + '|' + loc.locale, loc.value);
          }
        }
        this.loading.set(false);
      },
      error: () => this.loading.set(false)
    });
  }

  localeLabel(locale: string): string {
    return this.localeLabels[locale] ?? locale;
  }

  activeLocale(key: string): string {
    return this.locales.get(key) ?? 'it';
  }

  setLocale(key: string, locale: string): void {
    this.locales.set(key, locale);
  }

  draft(key: string, locale: string): string {
    return this.drafts.get(key + '|' + locale) ?? '';
  }

  onDraftChange(key: string, locale: string, value: string): void {
    this.drafts.set(key + '|' + locale, value);
  }

  private effectiveValue(key: string, locale: string): string {
    const p = this.prompts().find(x => x.key === key);
    return p?.locales.find(l => l.locale === locale)?.value ?? '';
  }

  isDirty(key: string, locale: string): boolean {
    return this.draft(key, locale) !== this.effectiveValue(key, locale);
  }

  save(key: string, locale: string): void {
    if (!this.isDirty(key, locale)) return;
    const id = key + '|' + locale;
    this.saving.set(id);
    this.svc.update(key, locale, this.draft(key, locale)).subscribe({
      next: () => {
        this.saving.set(null);
        this.savedFlag.set(id);
        setTimeout(() => { if (this.savedFlag() === id) this.savedFlag.set(null); }, 2500);
        this.load();
      },
      error: () => this.saving.set(null)
    });
  }

  /**
   * Riporta il prompt al testo predefinito di fabbrica (risorsa bundle) per questa lingua e
   * rimuove l'eventuale personalizzazione dello studio. Recupero da modifiche errate.
   */
  restoreFactory(key: string, locale: string): void {
    const p = this.prompts().find(x => x.key === key);
    const loc = p?.locales.find(l => l.locale === locale);
    if (!loc) return;
    if (!confirm('Ripristinare il prompt predefinito di fabbrica per questa lingua? La personalizzazione dello studio verrà rimossa.')) return;
    const id = key + '|' + locale;
    const factory = loc.defaultValue;

    if (loc.overridden) {
      this.saving.set(id);
      this.svc.reset(key, locale).subscribe({
        next: () => {
          this.saving.set(null);
          this.drafts.set(id, factory);
          this.prompts.update(list => list.map(pr => pr.key !== key ? pr : {
            ...pr,
            locales: pr.locales.map(l => l.locale !== locale ? l : { ...l, value: factory, overridden: false })
          }));
        },
        error: () => this.saving.set(null)
      });
    } else {
      // Nessun override: ricarica il testo di fabbrica nell'editor (annulla modifiche non salvate)
      this.drafts.set(id, factory);
    }
  }
}
