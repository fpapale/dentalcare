import { ChangeDetectorRef, Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { PatientService, UpdatePatientRequest } from '../../../core/services/patient.service';
import { AppointmentService } from '../../../core/services/appointment.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { PatientDetail } from '../../../core/models/patient.model';
import { CartellaClinicalTabComponent } from '../cartella-tab/cartella-tab.component';
import { AnamnesiTabComponent } from '../anamnesi-tab/anamnesi-tab.component';
import { OdontogrammaTabComponent } from '../odontogramma-tab/odontogramma-tab.component';

@Component({
  selector: 'app-paziente-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, CartellaClinicalTabComponent, AnamnesiTabComponent, OdontogrammaTabComponent],
  templateUrl: './paziente-detail.component.html',
  styleUrl: './paziente-detail.component.css'
})
export class PazienteDetailComponent implements OnInit {
  private readonly userContext = inject(UserContextService);

  readonly role = this.userContext.role;

  activeTab = signal<'overview' | 'cartella' | 'anamnesi' | 'odontogramma' | 'preventivi' | 'documenti'>('overview');
  loading = signal(true);
  error = signal<string | null>(null);
  editAnagrafica = signal(false);
  saving = signal(false);
  saveError = signal<string | null>(null);

  paziente: any = null;
  appuntamenti: any[] = [];

  editForm: UpdatePatientRequest = {
    firstName: '', lastName: '', fiscalCode: '', birthDate: '',
    phone: '', email: '', addressLine1: '', city: '', province: '', postalCode: '', notes: ''
  };

  constructor(
    private route: ActivatedRoute,
    private patientService: PatientService,
    private appointmentService: AppointmentService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    this.loadPatient(id);
    this.loadAppointments(id);
  }

  startEditAnagrafica(): void {
    this.editForm = {
      firstName: this.paziente.firstName,
      lastName: this.paziente.lastName,
      fiscalCode: this.paziente.fiscalCode ?? '',
      birthDate: this.paziente.rawBirthDate ?? '',
      phone: this.paziente.rawPhone ?? '',
      email: this.paziente.rawEmail ?? '',
      addressLine1: this.paziente.addressLine1 ?? '',
      city: this.paziente.city ?? '',
      province: this.paziente.province ?? '',
      postalCode: this.paziente.postalCode ?? '',
      notes: this.paziente.note ?? ''
    };
    this.saveError.set(null);
    this.editAnagrafica.set(true);
  }

  cancelEditAnagrafica(): void {
    this.editAnagrafica.set(false);
    this.saveError.set(null);
  }

  saveAnagrafica(): void {
    if (this.saving()) return;
    this.saving.set(true);
    this.saveError.set(null);
    this.patientService.update(this.paziente.id, this.editForm).subscribe({
      next: () => {
        this.saving.set(false);
        this.editAnagrafica.set(false);
        this.loadPatient(this.paziente.id);
      },
      error: () => {
        this.saving.set(false);
        this.saveError.set('Errore durante il salvataggio');
      }
    });
  }

  private loadPatient(id: string): void {
    const providerId = this.userContext.providerId();
    this.patientService.findById(id, providerId).subscribe({
      next: detail => {
        this.paziente = this.mapPaziente(detail);
        this.loading.set(false);
        this.cdr.markForCheck();
      },
      error: () => {
        this.error.set('Paziente non trovato o accesso non autorizzato');
        this.loading.set(false);
      }
    });
  }

  private loadAppointments(id: string): void {
    this.appointmentService.findByPatient(id).subscribe({
      next: data => {
        this.appuntamenti = data.map(a => ({
          data: new Date(a.startsAt).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' }),
          ora: new Date(a.startsAt).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
          trattamento: a.serviceName ?? 'Visita',
          medico: a.providerName,
          stato: this.mapStato(a.appointmentStatus)
        }));
      }
    });
  }

  private mapPaziente(d: PatientDetail): any {
    const allergie: string[] = [];
    if (d.allergyPenicillin) allergie.push('Penicillina');
    if (d.allergyLatex) allergie.push('Lattice');
    if (d.allergyAnesthetic) allergie.push('Anestetico');
    if (d.otherAllergies) allergie.push(d.otherAllergies);

    const indirizzo = [d.addressLine1, d.city, d.province].filter(Boolean).join(', ');

    return {
      id: d.patientId,
      initials: `${d.firstName?.[0] ?? ''}${d.lastName?.[0] ?? ''}`.toUpperCase(),
      nome: d.fullName,
      firstName: d.firstName,
      lastName: d.lastName,
      dataNascita: d.birthDate ? new Date(d.birthDate).toLocaleDateString('it-IT') : '—',
      rawBirthDate: d.birthDate,
      eta: d.ageYears ?? '—',
      fiscalCode: d.fiscalCode,
      cf: d.fiscalCode ?? '—',
      rawPhone: d.phone,
      telefono: d.phone ?? '—',
      rawEmail: d.email,
      email: d.email ?? '—',
      addressLine1: d.addressLine1,
      city: d.city,
      province: d.province,
      postalCode: d.postalCode,
      indirizzo: indirizzo || '—',
      status: 'Attivo',
      allergie,
      note: d.notes,
      // Anamnesi fields — passati a cartella-tab e anamnesi-tab
      bloodType: d.bloodType,
      anamnesisDate: d.anamnesisDate,
      anamnesisNotes: d.anamnesisNotes,
      allergyPenicillin: d.allergyPenicillin,
      allergyLatex: d.allergyLatex,
      allergyAnesthetic: d.allergyAnesthetic,
      otherAllergies: d.otherAllergies,
      hypertension: d.hypertension,
      diabetes: d.diabetes,
      heartDisease: d.heartDisease,
      smoker: d.smoker,
      takingAnticoagulants: d.takingAnticoagulants,
      takingBisphosphonates: d.takingBisphosphonates,
      // Stats
      totalAppointments: d.totalAppointments,
      treatmentPlansCount: d.treatmentPlansCount,
      openTreatmentItemsCount: d.openTreatmentItemsCount,
    };
  }

  private mapStato(status: string): string {
    const map: Record<string, string> = {
      scheduled: 'Programmato',
      confirmed: 'Confermato',
      completed: 'Completato',
      cancelled: 'Cancellato',
      no_show: 'Non presentato'
    };
    return map[status] ?? status;
  }
}
