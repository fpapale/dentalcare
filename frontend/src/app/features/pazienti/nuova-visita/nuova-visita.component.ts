import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { UserContextService } from '../../../core/services/user-context.service';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-nuova-visita',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './nuova-visita.component.html'
})
export class NuovaVisitaComponent implements OnInit {
  private readonly userContext = inject(UserContextService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly http = inject(HttpClient);

  patientId = signal('');
  saving = signal(false);
  error = signal<string | null>(null);

  form = {
    toothNumber: '',
    serviceName: '',
    clinicalNotes: '',
    nextVisitNotes: '',
    materialsUsed: ''
  };

  ngOnInit(): void {
    this.patientId.set(this.route.snapshot.paramMap.get('id') ?? '');
  }

  save(): void {
    if (!this.form.clinicalNotes.trim() || this.saving()) return;
    const providerId = this.userContext.providerId();
    if (!providerId) { this.error.set('Provider non identificato'); return; }
    this.saving.set(true);
    this.error.set(null);
    this.http.post(
      `${environment.apiBaseUrl}/patients/${this.patientId()}/clinical-record/diary`,
      {
        providerId,
        toothNumber: this.form.toothNumber || null,
        serviceName: this.form.serviceName || null,
        clinicalNotes: this.form.clinicalNotes,
        nextVisitNotes: this.form.nextVisitNotes || null,
        materialsUsed: this.form.materialsUsed || null
      }
    ).subscribe({
      next: () => this.router.navigate(['/pazienti', this.patientId()], { queryParams: { tab: 'cartella' } }),
      error: () => { this.error.set('Errore durante il salvataggio'); this.saving.set(false); }
    });
  }
}
