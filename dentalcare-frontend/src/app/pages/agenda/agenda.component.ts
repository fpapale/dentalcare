import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AppointmentService } from '../../core/services/appointment.service';
import { UserContextService } from '../../core/services/user-context.service';
import { Appointment } from '../../core/models/appointment.model';

@Component({
  selector: 'app-agenda',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './agenda.component.html',
  styleUrl: './agenda.component.css'
})
export class AgendaComponent {
  private readonly appointmentService = inject(AppointmentService);
  private readonly userContext = inject(UserContextService);

  today = new Date();
  selectedDate = signal<Date>(new Date());
  viewMode = signal<'giorno' | 'settimana' | 'mese' | 'prossimi'>('prossimi');
  appointments = signal<Appointment[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  readonly role = this.userContext.role;

  hours = ['08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00'];

  // Appointments from now onwards (endsAt >= now), sorted by startsAt
  readonly upcomingAppointments = computed(() => {
    const now = new Date();
    return this.appointments()
      .filter(a => new Date(a.endsAt) >= now)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  });

  constructor() {
    // Load appointments whenever date, provider or role changes
    effect(() => {
      const providerId = this.userContext.providerId();
      this.userContext.role();
      const d = this.selectedDate();
      const iso = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
      this.loadAppointments(iso, providerId);
    });

    // When provider/role switches: snap back to today + prossimi view
    effect(() => {
      this.userContext.providerId();
      this.userContext.role();
      untracked(() => {
        const today = new Date();
        if (this.selectedDate().toDateString() !== today.toDateString()) {
          this.selectedDate.set(today);
        }
        this.viewMode.set('prossimi');
      });
    });
  }

  private loadAppointments(date: string, providerId: string | null): void {
    this.loading.set(true);
    this.error.set(null);
    this.appointmentService.findByDate(date, providerId).subscribe({
      next: data => { this.appointments.set(data); this.loading.set(false); },
      error: () => { this.error.set('Errore nel caricamento agenda'); this.loading.set(false); }
    });
  }

  get dateLabel(): string {
    return this.selectedDate().toLocaleDateString('it-IT', {
      weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
    });
  }

  get chairs(): string[] {
    const labels = [...new Set(this.appointments().map(a => a.chairLabel))].sort();
    return labels.length > 0 ? labels : ['Poltrona 1', 'Poltrona 2', 'Poltrona 3'];
  }

  changeDate(days: number): void {
    const d = new Date(this.selectedDate());
    d.setDate(d.getDate() + days);
    this.selectedDate.set(d);
    const isToday = d.toDateString() === new Date().toDateString();
    if (isToday) {
      this.viewMode.set('prossimi');
    } else if (this.viewMode() === 'prossimi') {
      this.viewMode.set('giorno');
    }
  }

  goToToday(): void {
    this.selectedDate.set(new Date());
    this.viewMode.set('prossimi');
  }

  getAppointmentsForChair(chair: string): Appointment[] {
    return this.appointments().filter(a => a.chairLabel === chair);
  }

  topPx(a: Appointment): number {
    const start = new Date(a.startsAt);
    const minutes = (start.getHours() - 8) * 60 + start.getMinutes();
    return Math.max(0, (minutes / 60) * 96);
  }

  heightPx(a: Appointment): number {
    const start = new Date(a.startsAt);
    const end = new Date(a.endsAt);
    const mins = (end.getTime() - start.getTime()) / 60000;
    return Math.max(40, (mins / 60) * 96);
  }

  apptColor(a: Appointment): string {
    switch (a.appointmentStatus) {
      case 'in_progress': return 'bg-green-100 border-green-400 text-green-800';
      case 'completed':   return 'bg-slate-100 border-slate-300 text-slate-600';
      case 'cancelled': case 'no_show': return 'bg-red-100 border-red-400 text-red-800';
      case 'confirmed':   return 'bg-blue-100 border-blue-400 text-blue-800';
      default:            return 'bg-yellow-50 border-yellow-300 text-yellow-800';
    }
  }

  statusLabel(a: Appointment): string {
    switch (a.appointmentStatus) {
      case 'in_progress': return 'In corso';
      case 'completed':   return 'Completato';
      case 'cancelled':   return 'Annullato';
      case 'no_show':     return 'No show';
      case 'confirmed':   return 'Confermato';
      default:            return 'Programmato';
    }
  }

  statusBadgeClass(a: Appointment): string {
    switch (a.appointmentStatus) {
      case 'in_progress': return 'bg-green-100 text-green-700';
      case 'completed':   return 'bg-slate-100 text-slate-500';
      case 'cancelled':
      case 'no_show':     return 'bg-red-100 text-red-700';
      case 'confirmed':   return 'bg-blue-100 text-blue-700';
      default:            return 'bg-yellow-50 text-yellow-700';
    }
  }

  formatTime(iso: string): string {
    return new Date(iso).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  }

  currentTimeTop(): number {
    const now = new Date();
    const minutes = (now.getHours() - 8) * 60 + now.getMinutes();
    return Math.max(0, (minutes / 60) * 96);
  }

  currentTimeLabel(): string {
    const now = new Date();
    return `${now.getHours().toString().padStart(2,'0')}:${now.getMinutes().toString().padStart(2,'0')}`;
  }

  isToday(): boolean {
    const t = new Date();
    const s = this.selectedDate();
    return t.toDateString() === s.toDateString();
  }
}
