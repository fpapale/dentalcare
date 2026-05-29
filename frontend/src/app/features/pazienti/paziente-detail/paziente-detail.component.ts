import { ChangeDetectorRef, Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink, ActivatedRoute, Router } from '@angular/router';
import { PatientService, UpdatePatientRequest } from '../../../core/services/patient.service';
import { ProviderService } from '../../../core/services/provider.service';
import { Provider } from '../../../core/models/provider.model';
import { AppointmentService, RescheduleAppointmentRequest } from '../../../core/services/appointment.service';
import { AppSettingsService } from '../../../core/services/app-settings.service';
import { UserContextService } from '../../../core/services/user-context.service';
import { PatientDetail } from '../../../core/models/patient.model';
import { CartellaClinicalTabComponent } from '../cartella-tab/cartella-tab.component';
import { AnamnesiTabComponent } from '../anamnesi-tab/anamnesi-tab.component';
import { OdontogrammaTabComponent } from '../odontogramma-tab/odontogramma-tab.component';
import { PianoCuraTabComponent } from '../piano-cura-tab/piano-cura-tab.component';
import { RichiamiTabComponent } from '../richiami-tab/richiami-tab.component';

@Component({
  selector: 'app-paziente-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, CartellaClinicalTabComponent, AnamnesiTabComponent, OdontogrammaTabComponent, PianoCuraTabComponent, RichiamiTabComponent],
  templateUrl: './paziente-detail.component.html',
  styleUrl: './paziente-detail.component.css'
})
export class PazienteDetailComponent implements OnInit {
  private readonly userContext = inject(UserContextService);
  private readonly appSettings = inject(AppSettingsService);
  private readonly router = inject(Router);

  readonly role = this.userContext.role;

  activeTab = signal<'overview' | 'cartella' | 'anamnesi' | 'odontogramma' | 'pianiCura' | 'richiami' | 'preventivi' | 'documenti'>('overview');
  loading = signal(true);
  error = signal<string | null>(null);
  editAnagrafica = signal(false);
  saving = signal(false);
  saveError = signal<string | null>(null);
  showPhotoModal = signal(false);
  photoMode = signal<'idle' | 'webcam' | 'upload'>('idle');
  webcamStream: MediaStream | null = null;
  capturedPhoto = signal<string | null>(null);
  savingPhoto = signal(false);
  confirmCancelId  = signal<string | null>(null);
  highlightApptId  = signal<string | null>(null);
  editApptId       = signal<string | null>(null);
  savingAppt       = signal(false);
  apptError        = signal<string | null>(null);
  availableChairs  = signal<string[]>([]);
  editApptForm     = { date: '', startTime: '', endTime: '', chairLabel: '' };
  private editApptDurationMin = 0;

  apptPage = signal(0);
  readonly apptPageSize = computed(() => this.appSettings.get().dashboardApptPageSize);

  paziente: any = null;
  appuntamenti: any[] = [];

  get pagedAppuntamenti(): any[] {
    const p = this.apptPage();
    const size = this.apptPageSize();
    return this.appuntamenti.slice(p * size, (p + 1) * size);
  }

  get apptPageCount(): number {
    return Math.ceil(this.appuntamenti.length / this.apptPageSize());
  }

  prevApptPage(): void { this.apptPage.update(p => Math.max(0, p - 1)); }
  nextApptPage(): void { this.apptPage.update(p => Math.min(this.apptPageCount - 1, p + 1)); }

  providers = signal<Provider[]>([]);

  editForm: UpdatePatientRequest = {
    firstName: '', lastName: '', fiscalCode: '', birthDate: '',
    phone: '', email: '', addressLine1: '', city: '', province: '', postalCode: '', notes: '',
    primaryProviderId: ''
  };

  constructor(
    private route: ActivatedRoute,
    private patientService: PatientService,
    private providerService: ProviderService,
    private appointmentService: AppointmentService,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    const tab = this.route.snapshot.queryParamMap.get('tab');
    const apptId = this.route.snapshot.queryParamMap.get('appointmentId');
    if (tab) this.activeTab.set(tab as any);
    if (apptId) this.highlightApptId.set(apptId);
    this.providerService.findAll().subscribe({ next: list => this.providers.set(list), error: () => {} });
    this.loadPatient(id);
    this.loadAppointments(id, apptId ?? null);
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
      notes: this.paziente.note ?? '',
      primaryProviderId: this.paziente.primaryProviderId ?? ''
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

  private loadAppointments(id: string, highlightId: string | null = null): void {
    const role = this.userContext.role();
    const providerId = role === 'doctor' || role === 'hygienist' ? this.userContext.providerId() : null;
    this.appointmentService.findByPatient(id, providerId).subscribe({
      next: data => {
        this.appuntamenti = data.map(a => ({
          id: a.appointmentId,
          isoDate: new Date(a.startsAt).toISOString().slice(0, 10),
          data: new Date(a.startsAt).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' }),
          ora: new Date(a.startsAt).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
          oraFine: new Date(a.endsAt).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
          durationMin: Math.round((new Date(a.endsAt).getTime() - new Date(a.startsAt).getTime()) / 60000),
          chairLabel: a.chairLabel,
          trattamento: a.serviceName ?? 'Visita',
          medico: a.providerName,
          rawStatus: a.appointmentStatus,
          stato: this.mapStato(a.appointmentStatus)
        }));
        if (highlightId) {
          const idx = this.appuntamenti.findIndex(a => a.id === highlightId);
          if (idx >= 0) {
            this.apptPage.set(Math.floor(idx / this.apptPageSize()));
          }
        }
        this.cdr.markForCheck();
      }
    });
  }

  updateAppointmentStatus(apt: any, newRawStatus: string): void {
    const prev = apt.rawStatus;
    apt.rawStatus = newRawStatus;
    apt.stato = this.mapStato(newRawStatus);
    this.appointmentService.updateStatus(apt.id, newRawStatus).subscribe({
      error: () => {
        apt.rawStatus = prev;
        apt.stato = this.mapStato(prev);
        this.cdr.markForCheck();
      }
    });
  }

  cancelAppointment(apt: any): void {
    this.appointmentService.updateStatus(apt.id, 'cancelled').subscribe({
      next: () => {
        apt.rawStatus = 'cancelled';
        apt.stato = this.mapStato('cancelled');
        this.confirmCancelId.set(null);
        this.cdr.markForCheck();
      }
    });
  }

  openEditAppt(apt: any): void {
    this.editApptId.set(apt.id);
    this.apptError.set(null);
    this.editApptDurationMin = apt.durationMin;
    this.editApptForm = {
      date:       apt.isoDate,
      startTime:  apt.ora,
      endTime:    apt.oraFine,
      chairLabel: apt.chairLabel
    };
    if (this.availableChairs().length === 0) {
      this.appointmentService.findChairLabels().subscribe(c => this.availableChairs.set(c));
    }
  }

  onEditStartTimeChange(): void {
    const [h, m] = this.editApptForm.startTime.split(':').map(Number);
    const totalMin = h * 60 + m + this.editApptDurationMin;
    const endH = Math.floor(totalMin / 60) % 24;
    const endM = totalMin % 60;
    this.editApptForm.endTime = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
  }

  cancelEditAppt(): void {
    this.editApptId.set(null);
    this.apptError.set(null);
  }

  saveEditAppt(apt: any): void {
    if (this.savingAppt()) return;
    const f = this.editApptForm;
    const startsAt = new Date(`${f.date}T${f.startTime}:00`).toISOString();
    const endsAt   = new Date(`${f.date}T${f.endTime}:00`).toISOString();
    const req: RescheduleAppointmentRequest = { startsAt, endsAt, chairLabel: f.chairLabel };
    this.savingAppt.set(true);
    this.apptError.set(null);
    this.appointmentService.reschedule(apt.id, req).subscribe({
      next: () => {
        this.savingAppt.set(false);
        this.editApptId.set(null);
        const patientId = this.route.snapshot.paramMap.get('id')!;
        this.loadAppointments(patientId, this.highlightApptId());
      },
      error: (err) => {
        this.savingAppt.set(false);
        const msg = err?.error?.message ?? 'Errore nel salvataggio';
        this.apptError.set(msg);
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
      photoUrl: d.photoUrl ?? null,
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
      primaryProviderId: d.primaryProviderId,
      medicoRiferimento: d.primaryProviderName ?? '—',
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

  openPhotoModal(): void {
    this.capturedPhoto.set(null);
    this.photoMode.set('idle');
    this.showPhotoModal.set(true);
  }

  closePhotoModal(): void {
    this.stopWebcam();
    this.showPhotoModal.set(false);
    this.photoMode.set('idle');
    this.capturedPhoto.set(null);
  }

  async startWebcam(): Promise<void> {
    this.photoMode.set('webcam');
    this.capturedPhoto.set(null);
    try {
      this.webcamStream = await navigator.mediaDevices.getUserMedia({ video: { width: 400, height: 400, facingMode: 'user' } });
      setTimeout(() => {
        const video = document.getElementById('webcam-video') as HTMLVideoElement;
        if (video) video.srcObject = this.webcamStream;
      }, 100);
    } catch {
      this.photoMode.set('idle');
    }
  }

  captureWebcam(): void {
    const video = document.getElementById('webcam-video') as HTMLVideoElement;
    if (!video) return;
    const canvas = document.createElement('canvas');
    canvas.width = 400;
    canvas.height = 400;
    const ctx = canvas.getContext('2d')!;
    const size = Math.min(video.videoWidth, video.videoHeight);
    const ox = (video.videoWidth - size) / 2;
    const oy = (video.videoHeight - size) / 2;
    ctx.drawImage(video, ox, oy, size, size, 0, 0, 400, 400);
    this.capturedPhoto.set(canvas.toDataURL('image/jpeg', 0.85));
    this.stopWebcam();
    this.photoMode.set('idle');
  }

  stopWebcam(): void {
    if (this.webcamStream) {
      this.webcamStream.getTracks().forEach(t => t.stop());
      this.webcamStream = null;
    }
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const size = 400;
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext('2d')!;
        const s = Math.min(img.width, img.height);
        const ox = (img.width - s) / 2;
        const oy = (img.height - s) / 2;
        ctx.drawImage(img, ox, oy, s, s, 0, 0, size, size);
        this.capturedPhoto.set(canvas.toDataURL('image/jpeg', 0.85));
        this.photoMode.set('idle');
      };
      img.src = reader.result as string;
    };
    reader.readAsDataURL(file);
  }

  savePhoto(): void {
    const photo = this.capturedPhoto();
    if (!photo || this.savingPhoto()) return;
    this.savingPhoto.set(true);
    this.patientService.updatePhoto(this.paziente.id, photo).subscribe({
      next: () => {
        this.paziente = { ...this.paziente, photoUrl: photo };
        this.savingPhoto.set(false);
        this.closePhotoModal();
      },
      error: () => this.savingPhoto.set(false)
    });
  }

  removePhoto(): void {
    if (!confirm('Rimuovere la foto?')) return;
    this.patientService.updatePhoto(this.paziente.id, '').subscribe({
      next: () => {
        this.paziente = { ...this.paziente, photoUrl: null };
      }
    });
  }
}
