import { Component, OnInit, signal, ElementRef, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { RouterLink, Router, ActivatedRoute } from '@angular/router';
import { Subject } from 'rxjs';
import { debounceTime, distinctUntilChanged, switchMap } from 'rxjs/operators';

import { PatientService } from '../../../core/services/patient.service';
import { ProviderService } from '../../../core/services/provider.service';
import { ServiceCatalogService } from '../../../core/services/service-catalog.service';
import { AppointmentService } from '../../../core/services/appointment.service';
import { PatientListItem } from '../../../core/models/patient.model';
import { Provider } from '../../../core/models/provider.model';
import { ServiceItem } from '../../../core/models/service.model';

@Component({
  selector: 'app-nuovo-appuntamento',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule, RouterLink],
  templateUrl: './nuovo-appuntamento.component.html',
  styleUrl: './nuovo-appuntamento.component.css'
})
export class NuovoAppuntamentoComponent implements OnInit {
  @ViewChild('patientInput') patientInput!: ElementRef<HTMLInputElement>;

  saving = signal(false);
  saveError = signal<string | null>(null);

  // Patient autocomplete
  patientQuery = '';
  patientResults = signal<PatientListItem[]>([]);
  patientDropdownOpen = signal(false);
  selectedPatient = signal<PatientListItem | null>(null);
  private patientSearch$ = new Subject<string>();

  // Lookup data
  providers = signal<Provider[]>([]);
  services = signal<ServiceItem[]>([]);
  chairLabels = signal<string[]>([]);

  readonly durate = [15, 30, 45, 60, 90, 120];

  form: FormGroup;

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private route: ActivatedRoute,
    private patientService: PatientService,
    private providerService: ProviderService,
    private serviceCatalogService: ServiceCatalogService,
    private appointmentService: AppointmentService
  ) {
    const today = new Date().toISOString().split('T')[0];
    this.form = this.fb.group({
      data: [today, Validators.required],
      ora: ['', Validators.required],
      durata: [30, Validators.required],
      providerId: ['', Validators.required],
      chairLabel: ['', Validators.required],
      serviceId: [''],
      note: [''],
      inviaRicordatorio: [true],
    });
  }

  ngOnInit(): void {
    this.providerService.findAll().subscribe(data => this.providers.set(data));
    this.serviceCatalogService.findAll().subscribe(data => this.services.set(data));
    this.appointmentService.findChairLabels().subscribe({
      next: data => this.chairLabels.set(data),
      error: () => this.chairLabels.set(['Poltrona 1', 'Poltrona 2', 'Poltrona 3'])
    });

    this.patientSearch$.pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap(q => this.patientService.findAll(q || undefined))
    ).subscribe(results => {
      this.patientResults.set(results.slice(0, 8));
      this.patientDropdownOpen.set(results.length > 0);
    });

    // Pre-seleziona il paziente se arriva dalla scheda paziente
    const patientId = this.route.snapshot.queryParamMap.get('patientId');
    if (patientId) {
      this.patientService.findById(patientId).subscribe(detail => {
        const asListItem: PatientListItem = {
          patientId: detail.patientId,
          patientFullName: detail.fullName,
          firstName: detail.firstName,
          lastName: detail.lastName,
          fiscalCode: detail.fiscalCode,
          birthDate: detail.birthDate,
          ageYears: detail.ageYears,
          phone: detail.phone,
          email: detail.email,
          city: detail.city,
          province: detail.province,
          treatmentPlansCount: detail.treatmentPlansCount,
          openTreatmentItemsCount: detail.openTreatmentItemsCount,
          totalAppointments: detail.totalAppointments,
          acceptedEstimatesAmount: null,
        };
        this.selectedPatient.set(asListItem);
        this.patientQuery = detail.fullName;
      });
    }
  }

  onPatientInput(event: Event): void {
    const q = (event.target as HTMLInputElement).value;
    this.patientQuery = q;
    this.selectedPatient.set(null);
    if (q.trim().length >= 2) {
      this.patientSearch$.next(q.trim());
    } else {
      this.patientResults.set([]);
      this.patientDropdownOpen.set(false);
    }
  }

  selectPatient(p: PatientListItem): void {
    this.selectedPatient.set(p);
    this.patientQuery = p.patientFullName;
    this.patientDropdownOpen.set(false);
  }

  closeDropdown(): void {
    // Delayed so click on list item fires first
    setTimeout(() => this.patientDropdownOpen.set(false), 150);
  }

  get formValid(): boolean {
    return this.form.valid && this.selectedPatient() !== null;
  }

  save(): void {
    if (!this.formValid) return;
    this.saving.set(true);
    this.saveError.set(null);

    const v = this.form.value;
    const patient = this.selectedPatient()!;

    const dateStr = v.data as string;
    const timeStr = v.ora as string;
    const durationMin = v.durata as number;

    const starts = new Date(`${dateStr}T${timeStr}:00`);
    const ends = new Date(starts.getTime() + durationMin * 60000);

    const toIso = (d: Date) => d.toISOString().replace('Z', '+00:00');

    // Build notes combining selected service name + user note
    const selectedService = this.services().find(s => s.serviceId === v.serviceId);
    const notesParts: string[] = [];
    if (selectedService) notesParts.push(selectedService.name);
    if (v.note?.trim()) notesParts.push(v.note.trim());

    this.appointmentService.create({
      patientId: patient.patientId,
      providerId: v.providerId,
      chairLabel: v.chairLabel,
      startsAt: toIso(starts),
      endsAt: toIso(ends),
      notes: notesParts.join(' — ') || undefined,
    }).subscribe({
      next: () => {
        this.saving.set(false);
        this.router.navigate(['/agenda']);
      },
      error: (err) => {
        this.saving.set(false);
        const msg = err?.error?.message;
        this.saveError.set(msg ?? 'Errore durante il salvataggio. Verifica i dati e riprova.');
      }
    });
  }
}
