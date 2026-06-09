import { Component, DestroyRef, computed, effect, inject, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Subject } from 'rxjs';
import { distinctUntilChanged, switchMap } from 'rxjs/operators';
import { DashboardService } from '../../core/services/dashboard.service';
import { UserContextService } from '../../core/services/user-context.service';
import { AppSettingsService } from '../../core/services/app-settings.service';
import { Dashboard } from '../../core/models/dashboard.model';
import { Appointment } from '../../core/models/appointment.model';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.css'
})
export class DashboardComponent {
  private readonly dashboardService = inject(DashboardService);
  private readonly userContext      = inject(UserContextService);
  private readonly appSettings      = inject(AppSettingsService);
  private readonly destroyRef       = inject(DestroyRef);

  dashboard    = signal<Dashboard | null>(null);
  loading      = signal(true);
  error        = signal<string | null>(null);
  hoveredAppt      = signal<Appointment | null>(null);
  apptPage         = signal(0);
  apptStatusFilter = signal<string[]>(['scheduled', 'confirmed', 'presente']);
  readonly pageSize = computed(() => this.appSettings.get().dashboardApptPageSize);

  readonly role = this.userContext.role;

  constructor() {
    const trigger$ = new Subject<string | null>();

    trigger$.pipe(
      takeUntilDestroyed(this.destroyRef),
      distinctUntilChanged(),
      switchMap(pid => {
        this.loading.set(true);
        this.error.set(null);
        return this.dashboardService.getDashboard(pid);
      })
    ).subscribe({
      next: data => {
        this.dashboard.set(data);
        this.loading.set(false);
        this.apptPage.set(0);
        this.userContext.setClinicName(data.clinicName);
      },
      error: ()  => { this.error.set('Errore nel caricamento dashboard'); this.loading.set(false); }
    });

    const effectivePid = () => {
      const r = this.userContext.role();
      return (r === 'secretary' || r === 'admin') ? null : this.userContext.providerId();
    };

    trigger$.next(effectivePid());

    effect(() => {
      const pid = effectivePid();
      untracked(() => trigger$.next(pid));
    });

    effect(() => {
      this.pageSize(); // track
      untracked(() => this.apptPage.set(0));
    });
  }

  statusLabel(status: string): string {
    const map: Record<string, string> = {
      scheduled: 'PREVISTO', confirmed: 'CONFERMATO', presente: 'PRESENTE',
      in_progress: 'IN CORSO', completed: 'COMPLETATO',
      cancelled: 'CANCELLATO', no_show: 'NON VENUTO'
    };
    return map[status] ?? status.toUpperCase();
  }

  statusClass(status: string): string {
    switch (status) {
      case 'in_progress': return 'bg-green-100 text-green-700';
      case 'confirmed':   return 'bg-blue-100 text-blue-700';
      case 'presente':    return 'bg-teal-100 text-teal-700';
      case 'completed':   return 'bg-slate-100 text-slate-600';
      case 'cancelled': case 'no_show': return 'bg-red-100 text-red-600';
      default:            return 'bg-yellow-100 text-yellow-700';
    }
  }

  statusBadgeLabel(status: string): string {
    const map: Record<string, string> = {
      in_progress: 'In corso', confirmed: 'Confermato', presente: 'Presente',
      completed: 'Completato', cancelled: 'Annullato',
      no_show: 'No show', scheduled: 'Programmato',
    };
    return map[status] ?? status;
  }

  formatTime(iso: string): string {
    return new Date(iso).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  }

  get occupancyPct(): number {
    const d = this.dashboard();
    if (!d || d.todayTotal === 0) return 0;
    return Math.round(((d.todayCompleted + d.todayConfirmed) / d.todayTotal) * 100);
  }

  get dashArray(): string {
    const v = this.occupancyPct;
    return `${v} ${100 - v}`;
  }

  upcomingAppts(appts: Appointment[], nextDay = false): Appointment[] {
    const now = new Date();
    return appts
      .filter(a => nextDay || new Date(a.endsAt) >= now)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  }

  filteredAppts(appts: Appointment[], nextDay = false): Appointment[] {
    const upcoming = this.upcomingAppts(appts, nextDay);
    const f = this.apptStatusFilter();
    return f.length === 0 ? upcoming : upcoming.filter(a => f.includes(a.appointmentStatus));
  }

  toggleFilter(status: string): void {
    this.apptStatusFilter.update(f =>
      f.includes(status) ? f.filter(s => s !== status) : [...f, status]
    );
    this.apptPage.set(0);
  }

  isFilterActive(status: string): boolean {
    return this.apptStatusFilter().includes(status);
  }

  alertAppts(appts: Appointment[]): Appointment[] {
    return appts.filter(a => a.hasAllergyAlert || a.hasMedicationAlert || a.overdueRecallCount > 0).slice(0, 3);
  }

  shownAppt(appts: Appointment[]): Appointment | null {
    return this.hoveredAppt() ?? (appts.length > 0 ? appts[0] : null);
  }

  pagedAppts(appts: Appointment[]): Appointment[] {
    const p = this.apptPage();
    const size = this.pageSize();
    return appts.slice(p * size, (p + 1) * size);
  }

  apptPageCount(appts: Appointment[]): number {
    return Math.ceil(appts.length / this.pageSize());
  }

  prevPage(): void { this.apptPage.update(p => Math.max(0, p - 1)); }
  nextPage(count: number): void { this.apptPage.update(p => Math.min(count - 1, p + 1)); }

  plansTotal(d: Dashboard): number {
    return d.plansDraft + d.plansProposed + d.plansAccepted + d.plansRejected;
  }

  planBarFlex(count: number, d: Dashboard): number {
    const total = this.plansTotal(d);
    return total === 0 ? 0 : count;
  }
}
