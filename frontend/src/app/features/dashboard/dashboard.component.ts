import { Component, DestroyRef, effect, inject, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Subject } from 'rxjs';
import { distinctUntilChanged, switchMap } from 'rxjs/operators';
import { DashboardService } from '../../core/services/dashboard.service';
import { UserContextService } from '../../core/services/user-context.service';
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
  private readonly destroyRef       = inject(DestroyRef);

  today     = new Date();
  dashboard = signal<Dashboard | null>(null);
  loading   = signal(true);
  error     = signal<string | null>(null);

  readonly role = this.userContext.role;

  constructor() {
    const trigger$ = new Subject<string | null>();

    trigger$.pipe(
      takeUntilDestroyed(this.destroyRef),
      distinctUntilChanged(),
      switchMap(providerId => {
        this.loading.set(true);
        this.error.set(null);
        return this.dashboardService.getDashboard(providerId);
      })
    ).subscribe({
      next: data => { this.dashboard.set(data); this.loading.set(false); },
      error: ()  => { this.error.set('Errore nel caricamento dashboard'); this.loading.set(false); }
    });

    // Caricamento immediato con valori correnti (sincrono, nessun ritardo)
    trigger$.next(this.userContext.providerId());

    // Ricarica quando providerId cambia (es. selezione dottore)
    effect(() => {
      const providerId = this.userContext.providerId();
      this.userContext.role(); // tracked per reattività
      untracked(() => trigger$.next(providerId));
    });
  }

  statusLabel(status: string): string {
    const map: Record<string, string> = {
      scheduled: 'PREVISTO', confirmed: 'CONFERMATO',
      in_progress: 'IN CORSO', completed: 'COMPLETATO',
      cancelled: 'CANCELLATO', no_show: 'NON VENUTO'
    };
    return map[status] ?? status.toUpperCase();
  }

  statusClass(status: string): string {
    switch (status) {
      case 'in_progress': return 'bg-green-100 text-green-700';
      case 'confirmed':   return 'bg-blue-100 text-blue-700';
      case 'completed':   return 'bg-slate-100 text-slate-600';
      case 'cancelled': case 'no_show': return 'bg-red-100 text-red-600';
      default:            return 'bg-yellow-100 text-yellow-700';
    }
  }

  statusBadgeLabel(status: string): string {
    const map: Record<string, string> = {
      in_progress: 'In corso', confirmed: 'Confermato',
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

  upcomingAppts(appts: Appointment[]): Appointment[] {
    const now = new Date();
    return appts
      .filter(a => new Date(a.endsAt) >= now)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  }

  alertAppts(appts: Appointment[]): Appointment[] {
    return appts.filter(a => a.hasAllergyAlert || a.hasMedicationAlert).slice(0, 3);
  }
}
