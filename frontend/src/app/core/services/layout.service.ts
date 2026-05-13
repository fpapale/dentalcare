import { Injectable, signal, TemplateRef } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class LayoutService {
  readonly rightPanel = signal<TemplateRef<unknown> | null>(null);

  setRightPanel(template: TemplateRef<unknown> | null): void {
    this.rightPanel.set(template);
  }
}
