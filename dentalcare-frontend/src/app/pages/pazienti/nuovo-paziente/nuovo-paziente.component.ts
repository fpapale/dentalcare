import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterLink, Router } from '@angular/router';
import { PatientService } from '../../../core/services/patient.service';
import { ProviderService } from '../../../core/services/provider.service';
import { Provider } from '../../../core/models/provider.model';

@Component({
  selector: 'app-nuovo-paziente',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule, RouterLink],
  templateUrl: './nuovo-paziente.component.html',
  styleUrl: './nuovo-paziente.component.css'
})
export class NuovoPazienteComponent implements OnInit {
  activeStep = signal(1);
  saving = signal(false);
  saveError = signal<string | null>(null);
  providers = signal<Provider[]>([]);

  form: FormGroup;

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private patientService: PatientService,
    private providerService: ProviderService
  ) {
    this.form = this.fb.group({
      cognome: ['', [Validators.required]],
      nome: ['', [Validators.required]],
      dataNascita: ['', [Validators.required]],
      sesso: ['', [Validators.required]],
      cf: ['', [Validators.required, Validators.minLength(16), Validators.maxLength(16)]],
      telefono: ['', [Validators.required]],
      email: ['', [Validators.email]],
      indirizzo: [''],
      citta: [''],
      cap: [''],
      provincia: [''],
      medicoRiferimento: [''],
      note: [''],
      allergie: [''],
    });
  }

  ngOnInit(): void {
    this.providerService.findAll().subscribe({
      next: list => this.providers.set(list),
      error: () => {}
    });
  }

  steps = ['Dati Anagrafici', 'Contatti', 'Note Cliniche'];

  goToStep(n: number) { this.activeStep.set(n); }

  nextStep() {
    if (this.activeStep() < this.steps.length) this.activeStep.update(s => s + 1);
  }

  prevStep() {
    if (this.activeStep() > 1) this.activeStep.update(s => s - 1);
  }

  save() {
    if (this.form.invalid) return;
    this.saving.set(true);
    this.saveError.set(null);

    const v = this.form.value;
    this.patientService.create({
      firstName: v.nome,
      lastName: v.cognome,
      fiscalCode: v.cf || undefined,
      birthDate: v.dataNascita || undefined,
      phone: v.telefono || undefined,
      email: v.email || undefined,
      addressLine1: v.indirizzo || undefined,
      city: v.citta || undefined,
      province: v.provincia || undefined,
      postalCode: v.cap || undefined,
      notes: v.note || undefined,
    }).subscribe({
      next: () => {
        this.saving.set(false);
        this.router.navigate(['/pazienti']);
      },
      error: () => {
        this.saving.set(false);
        this.saveError.set('Errore durante il salvataggio. Riprova.');
      }
    });
  }
}
