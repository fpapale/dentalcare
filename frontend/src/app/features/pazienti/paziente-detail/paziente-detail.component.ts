import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink, ActivatedRoute } from '@angular/router';
import { PatientService } from '../../../core/services/patient.service';
import { AppointmentService } from '../../../core/services/appointment.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { PatientDetail } from '../../../core/models/patient.model';
import { CartellaClinicalTabComponent } from '../cartella-tab/cartella-tab.component';
import { AnamnesiTabComponent } from '../anamnesi-tab/anamnesi-tab.component';

@Component({
  selector: 'app-paziente-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, CartellaClinicalTabComponent, AnamnesiTabComponent],
  templateUrl: './paziente-detail.component.html',
  styleUrl: './paziente-detail.component.css'
})
export class PazienteDetailComponent implements OnInit {
  private readonly userContext = inject(UserContextService);

  readonly role = this.userContext.role;

  activeTab = signal<'overview' | 'cartella' | 'anamnesi' | 'preventivi' | 'documenti'>('overview');
  loading = signal(true);
  error = signal<string | null>(null);

  paziente: any = null;
  appuntamenti: any[] = [];

  constructor(
    private route: ActivatedRoute,
    private patientService: PatientService,
    private appointmentService: AppointmentService
  ) {}

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    this.loadPatient(id);
    this.loadAppointments(id);
  }

  private loadPatient(id: string): void {
    const providerId = this.userContext.providerId();
    this.patientService.findById(id, providerId).subscribe({
      next: detail => {
        this.paziente = this.mapPaziente(detail);
        this.loading.set(false);
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
      dataNascita: d.birthDate ? new Date(d.birthDate).toLocaleDateString('it-IT') : '—',
      eta: d.ageYears ?? '—',
      cf: d.fiscalCode ?? '—',
      telefono: d.phone ?? '—',
      email: d.email ?? '—',
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
