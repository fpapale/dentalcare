import { Component, signal, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { FormsModule } from '@angular/forms';

type PlanType = 'essenziale' | 'professionale' | 'aziendale';

interface StudioForm {
  nome: string;
  telefono: string;
  email: string;
  indirizzo: string;
  citta: string;
  provincia: string;
  partitaIva: string;
}

interface AdminForm {
  nome: string;
  cognome: string;
  email: string;
}

@Component({
  selector: 'app-registrazione',
  standalone: true,
  imports: [RouterLink, FormsModule],
  templateUrl: './registrazione.component.html'
})
export class RegistrazioneComponent {
  private readonly http   = inject(HttpClient);
  private readonly router = inject(Router);

  readonly step          = signal<number>(1);
  readonly selectedPlan  = signal<PlanType>('professionale');
  readonly submitting    = signal(false);
  readonly error         = signal<string | null>(null);

  studioForm: StudioForm = {
    nome: '',
    telefono: '',
    email: '',
    indirizzo: '',
    citta: '',
    provincia: '',
    partitaIva: ''
  };

  adminForm: AdminForm = {
    nome: '',
    cognome: '',
    email: ''
  };

  selectPlan(plan: PlanType): void {
    this.selectedPlan.set(plan);
  }

  planLabel(plan: PlanType): string {
    const labels: Record<PlanType, string> = {
      essenziale: 'Essenziale',
      professionale: 'Professionale',
      aziendale: 'Aziendale'
    };
    return labels[plan];
  }

  goToStep(n: number): void {
    this.error.set(null);
    this.step.set(n);
  }

  submitRegistrazione(): void {
    this.error.set(null);
    this.submitting.set(true);

    this.http.post<{ clinicId: string; studioName: string; message: string }>('/api/public/register', {
      plan: this.selectedPlan(),
      studioName: this.studioForm.nome,
      telefono: this.studioForm.telefono,
      email: this.studioForm.email,
      indirizzo: this.studioForm.indirizzo,
      citta: this.studioForm.citta,
      provincia: this.studioForm.provincia,
      partitaIva: this.studioForm.partitaIva,
      adminNome: this.adminForm.nome,
      adminCognome: this.adminForm.cognome,
      adminEmail: this.adminForm.email
    }).subscribe({
      next: () => {
        this.submitting.set(false);
        this.step.set(4);
      },
      error: () => {
        this.submitting.set(false);
        this.error.set('Si è verificato un errore. Verifica i dati e riprova.');
      }
    });
  }

  goToDashboard(): void {
    this.router.navigate(['/dashboard']);
  }
}
