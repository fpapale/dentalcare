import { Component, EventEmitter, Input, OnInit, Output, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AnamnesisService } from '../../../core/services/anamnesis.service';
import { AnamnesisCategoryDto, AnamnesisItemDto } from '../../../core/models/anamnesis.model';

@Component({
  selector: 'app-anamnesi-tab',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './anamnesi-tab.component.html',
})
export class AnamnesiTabComponent implements OnInit {
  @Input({ required: true }) patientId!: string;
  @Input() bloodType: string | null = null;
  @Input() anamnesisNotes: string | null = null;
  @Input() anamnesisDate: string | null = null;
  @Output() readonly saved = new EventEmitter<void>();

  categories = signal<AnamnesisCategoryDto[]>([]);
  loading = signal(true);
  saving = signal(false);
  errorMsg = signal<string | null>(null);
  editMode = signal(false);
  openSections = signal<Set<string>>(new Set());

  selectedIds = signal<Set<string>>(new Set());
  notesMap = signal<Map<string, string>>(new Map());
  editBloodType = signal('');
  editGeneralNotes = signal('');

  readonly bloodTypeOptions = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];

  constructor(private readonly anamnesisService: AnamnesisService) {}

  ngOnInit(): void {
    this.loadAnamnesis();
  }

  private loadAnamnesis(): void {
    this.loading.set(true);
    this.errorMsg.set(null);
    this.anamnesisService.getAnamnesis(this.patientId).subscribe({
      next: cats => {
        this.categories.set(cats);
        const open = new Set(cats.filter(c => c.hasSelections).map(c => c.id));
        this.openSections.set(open);
        this.loading.set(false);
      },
      error: () => {
        this.errorMsg.set("Errore nel caricamento dell'anamnesi");
        this.loading.set(false);
      }
    });
  }

  toggleSection(id: string): void {
    const s = new Set(this.openSections());
    if (s.has(id)) { s.delete(id); } else { s.add(id); }
    this.openSections.set(s);
  }

  isOpen(id: string): boolean {
    return this.openSections().has(id);
  }

  enterEditMode(): void {
    const ids = new Set<string>();
    const notes = new Map<string, string>();
    for (const cat of this.categories()) {
      for (const item of cat.items) {
        if (item.selected) {
          ids.add(item.id);
          if (item.selectionNotes) notes.set(item.id, item.selectionNotes);
        }
      }
    }
    this.selectedIds.set(ids);
    this.notesMap.set(notes);
    this.editBloodType.set(this.bloodType ?? '');
    this.editGeneralNotes.set(this.anamnesisNotes ?? '');
    this.editMode.set(true);
  }

  cancelEdit(): void {
    this.editMode.set(false);
  }

  toggleItemSelection(itemId: string): void {
    const ids = new Set(this.selectedIds());
    if (ids.has(itemId)) { ids.delete(itemId); } else { ids.add(itemId); }
    this.selectedIds.set(ids);
  }

  isItemSelected(item: AnamnesisItemDto): boolean {
    return this.editMode() ? this.selectedIds().has(item.id) : item.selected;
  }

  getItemNotes(itemId: string): string {
    return this.notesMap().get(itemId) ?? '';
  }

  setItemNotes(itemId: string, value: string): void {
    const m = new Map(this.notesMap());
    if (value) { m.set(itemId, value); } else { m.delete(itemId); }
    this.notesMap.set(m);
  }

  onBloodTypeChange(event: Event): void {
    this.editBloodType.set((event.target as HTMLSelectElement).value);
  }

  onGeneralNotesChange(event: Event): void {
    this.editGeneralNotes.set((event.target as HTMLTextAreaElement).value);
  }

  selectedCountForCategory(cat: AnamnesisCategoryDto): number {
    if (this.editMode()) {
      return cat.items.filter(i => this.selectedIds().has(i.id)).length;
    }
    return cat.items.filter(i => i.selected).length;
  }

  alertCountForCategory(cat: AnamnesisCategoryDto): number {
    if (this.editMode()) {
      return cat.items.filter(i => i.isAlert && this.selectedIds().has(i.id)).length;
    }
    return cat.items.filter(i => i.isAlert && i.selected).length;
  }

  saveAnamnesis(): void {
    this.saving.set(true);
    this.errorMsg.set(null);
    const request = {
      selections: Array.from(this.selectedIds()).map(id => ({
        itemId: id,
        notes: this.notesMap().get(id) ?? null
      })),
      bloodType: this.editBloodType() || null,
      generalNotes: this.editGeneralNotes() || null
    };
    this.anamnesisService.saveAnamnesis(this.patientId, request).subscribe({
      next: () => {
        this.saving.set(false);
        this.editMode.set(false);
        this.loadAnamnesis();
        this.saved.emit();
      },
      error: () => {
        this.errorMsg.set('Errore nel salvataggio. Riprova.');
        this.saving.set(false);
      }
    });
  }

  formatDate(d: string | null): string {
    if (!d) return 'Non compilata';
    return new Date(d).toLocaleDateString('it-IT', { day: '2-digit', month: 'long', year: 'numeric' });
  }
}
