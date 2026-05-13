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

  // Day view
  appointments = signal<Appointment[]>([]);
  loading = signal(true);
  error = signal<string | null>(null);

  // Week / month range view
  rangeAppointments = signal<Appointment[]>([]);
  loadingRange = signal(false);

  // Mini calendar picker
  calendarOpen = signal(false);
  calendarMonth = signal<Date>(new Date());

  readonly role = this.userContext.role;

  readonly hours = ['08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00'];
  readonly dayNames = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];

  // ─── Computed ─────────────────────────────────────────────────────────────

  readonly upcomingAppointments = computed(() => {
    const now = new Date();
    return this.appointments()
      .filter(a => new Date(a.endsAt) >= now)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  });

  readonly weekDays = computed<Date[]>(() => {
    const d = new Date(this.selectedDate());
    const dow = d.getDay();
    const monday = new Date(d);
    monday.setDate(d.getDate() - (dow === 0 ? 6 : dow - 1));
    return Array.from({ length: 7 }, (_, i) => {
      const dd = new Date(monday);
      dd.setDate(monday.getDate() + i);
      return dd;
    });
  });

  // 6×7 grid for mini calendar picker
  readonly calendarGrid = computed<Date[][]>(() => this.buildMonthGrid(this.calendarMonth()));

  // 6×7 grid for month view
  readonly monthGrid = computed<Date[][]>(() => this.buildMonthGrid(this.selectedDate()));

  // Per-day occupancy: count + pct (max = 3 chairs × 8 working hours = 24)
  readonly dayStats = computed<Map<string, { count: number; pct: number }>>(() => {
    const map = new Map<string, { count: number; pct: number }>();
    const MAX = 24;
    for (const a of this.rangeAppointments()) {
      const key = new Date(a.startsAt).toISOString().slice(0, 10);
      const cur = map.get(key) ?? { count: 0, pct: 0 };
      cur.count++;
      cur.pct = Math.min(100, Math.round((cur.count / MAX) * 100));
      map.set(key, cur);
    }
    return map;
  });

  // ─── Constructor / Effects ────────────────────────────────────────────────

  constructor() {
    // Day appointments (giorno + prossimi)
    effect(() => {
      const mode = this.viewMode();
      const d = this.selectedDate();
      const providerId = this.userContext.providerId();
      this.userContext.role();
      if (mode !== 'giorno' && mode !== 'prossimi') return;
      this.loading.set(true);
      this.error.set(null);
      this.appointmentService.findByDate(this.toIso(d), providerId).subscribe({
        next: data => { this.appointments.set(data); this.loading.set(false); },
        error: () => { this.error.set('Errore nel caricamento agenda'); this.loading.set(false); }
      });
    });

    // Range appointments (settimana + mese)
    effect(() => {
      const mode = this.viewMode();
      const d = this.selectedDate();
      const providerId = this.userContext.providerId();
      this.userContext.role();

      let from: Date, to: Date;
      if (mode === 'settimana') {
        const dow = d.getDay();
        const monday = new Date(d);
        monday.setDate(d.getDate() - (dow === 0 ? 6 : dow - 1));
        from = monday;
        to = new Date(monday);
        to.setDate(monday.getDate() + 6);
      } else if (mode === 'mese') {
        from = new Date(d.getFullYear(), d.getMonth(), 1);
        to = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      } else {
        return;
      }

      this.loadingRange.set(true);
      this.error.set(null);
      this.appointmentService.findByDateRange(this.toIso(from), this.toIso(to), providerId).subscribe({
        next: data => { this.rangeAppointments.set(data); this.loadingRange.set(false); },
        error: () => { this.error.set('Errore nel caricamento'); this.loadingRange.set(false); }
      });
    });

    // Reset on provider/role switch
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

  // ─── Calendar picker ──────────────────────────────────────────────────────

  openCalendar(): void {
    this.calendarMonth.set(new Date(this.selectedDate()));
    this.calendarOpen.set(true);
  }

  prevCalMonth(): void {
    const m = new Date(this.calendarMonth());
    m.setMonth(m.getMonth() - 1);
    this.calendarMonth.set(m);
  }

  nextCalMonth(): void {
    const m = new Date(this.calendarMonth());
    m.setMonth(m.getMonth() + 1);
    this.calendarMonth.set(m);
  }

  selectDateFromCalendar(d: Date): void {
    this.selectedDate.set(new Date(d));
    this.calendarOpen.set(false);
    const isToday = d.toDateString() === new Date().toDateString();
    if (this.viewMode() === 'prossimi' && !isToday) this.viewMode.set('giorno');
    if (this.viewMode() === 'mese') this.viewMode.set('giorno');
  }

  calendarDayClass(d: Date): string {
    const selected = this.isSelectedDate(d);
    const today = this.isTodayDate(d);
    const sameMonth = d.getMonth() === this.calendarMonth().getMonth();
    if (selected) return 'bg-teal-600 text-white font-bold';
    if (today) return 'text-teal-600 font-bold ring-1 ring-teal-400 ring-inset';
    if (!sameMonth) return 'text-slate-300';
    return 'text-slate-700 hover:bg-slate-100';
  }

  isSelectedDate(d: Date): boolean {
    return d.toDateString() === this.selectedDate().toDateString();
  }

  isTodayDate(d: Date): boolean {
    return d.toDateString() === new Date().toDateString();
  }

  isSameCalMonth(d: Date): boolean {
    return d.getMonth() === this.calendarMonth().getMonth();
  }

  // ─── Period navigation ────────────────────────────────────────────────────

  changePeriod(dir: -1 | 1): void {
    const d = new Date(this.selectedDate());
    const mode = this.viewMode();
    if (mode === 'settimana') d.setDate(d.getDate() + dir * 7);
    else if (mode === 'mese') d.setMonth(d.getMonth() + dir);
    else d.setDate(d.getDate() + dir);
    this.selectedDate.set(d);
    if (mode !== 'mese' && mode !== 'settimana') {
      const isToday = d.toDateString() === new Date().toDateString();
      if (isToday) this.viewMode.set('prossimi');
      else if (this.viewMode() === 'prossimi') this.viewMode.set('giorno');
    }
  }

  goToToday(): void {
    this.selectedDate.set(new Date());
    this.viewMode.set('prossimi');
  }

  isToday(): boolean {
    return this.selectedDate().toDateString() === new Date().toDateString();
  }

  get dateLabel(): string {
    const d = this.selectedDate();
    const mode = this.viewMode();
    if (mode === 'settimana') {
      const days = this.weekDays();
      const from = days[0], to = days[6];
      if (from.getMonth() === to.getMonth()) {
        return `${from.getDate()} – ${to.getDate()} ${to.toLocaleDateString('it-IT', { month: 'long', year: 'numeric' })}`;
      }
      return `${from.toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })} – ${to.toLocaleDateString('it-IT', { day: 'numeric', month: 'short', year: 'numeric' })}`;
    }
    if (mode === 'mese') return d.toLocaleDateString('it-IT', { month: 'long', year: 'numeric' });
    return d.toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  }

  get calendarMonthLabel(): string {
    return this.calendarMonth().toLocaleDateString('it-IT', { month: 'long', year: 'numeric' });
  }

  // ─── Day view helpers ─────────────────────────────────────────────────────

  get chairs(): string[] {
    const labels = [...new Set(this.appointments().map(a => a.chairLabel))].sort();
    return labels.length > 0 ? labels : ['Poltrona 1', 'Poltrona 2', 'Poltrona 3'];
  }

  getAppointmentsForChair(chair: string): Appointment[] {
    return this.appointments().filter(a => a.chairLabel === chair);
  }

  topPx(a: Appointment): number {
    const start = new Date(a.startsAt);
    return Math.max(0, ((start.getHours() - 8) * 60 + start.getMinutes()) / 60 * 96);
  }

  heightPx(a: Appointment): number {
    const mins = (new Date(a.endsAt).getTime() - new Date(a.startsAt).getTime()) / 60000;
    return Math.max(40, (mins / 60) * 96);
  }

  currentTimeTop(): number {
    const now = new Date();
    return Math.max(0, ((now.getHours() - 8) * 60 + now.getMinutes()) / 60 * 96);
  }

  currentTimeLabel(): string {
    const now = new Date();
    return `${now.getHours().toString().padStart(2,'0')}:${now.getMinutes().toString().padStart(2,'0')}`;
  }

  // ─── Week view helpers ────────────────────────────────────────────────────

  getAppointmentsForDay(date: Date): Appointment[] {
    const key = this.toIso(date);
    return this.rangeAppointments()
      .filter(a => new Date(a.startsAt).toISOString().slice(0, 10) === key)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  }

  isWeekSelected(date: Date): boolean {
    return date.toDateString() === this.selectedDate().toDateString();
  }

  isWeekToday(date: Date): boolean {
    return date.toDateString() === new Date().toDateString();
  }

  navigateToDay(date: Date): void {
    this.selectedDate.set(new Date(date));
    this.viewMode.set(date.toDateString() === new Date().toDateString() ? 'prossimi' : 'giorno');
  }

  // ─── Month view helpers ───────────────────────────────────────────────────

  isCurrentMonth(date: Date): boolean {
    const d = this.selectedDate();
    return date.getMonth() === d.getMonth() && date.getFullYear() === d.getFullYear();
  }

  dayOccupancyPct(date: Date): number {
    return this.dayStats().get(this.toIso(date))?.pct ?? 0;
  }

  dayOccupancyCount(date: Date): number {
    return this.dayStats().get(this.toIso(date))?.count ?? 0;
  }

  dayOccupancyTextClass(date: Date): string {
    const pct = this.dayOccupancyPct(date);
    if (pct === 0) return 'text-slate-400';
    if (pct < 40) return 'text-green-600';
    if (pct < 70) return 'text-yellow-600';
    if (pct < 90) return 'text-orange-600';
    return 'text-red-600';
  }

  dayOccupancyBarClass(date: Date): string {
    const pct = this.dayOccupancyPct(date);
    if (pct === 0) return 'bg-slate-200';
    if (pct < 40) return 'bg-green-400';
    if (pct < 70) return 'bg-yellow-400';
    if (pct < 90) return 'bg-orange-400';
    return 'bg-red-500';
  }

  // Click on month day → find first free day of that month → week view
  openMonthDay(d: Date): void {
    const stats = this.dayStats();
    const MAX = 24;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const year = d.getFullYear();
    const month = d.getMonth();
    const lastDay = new Date(year, month + 1, 0);
    let candidate = new Date(Math.max(new Date(year, month, 1).getTime(), today.getTime()));

    while (candidate <= lastDay) {
      const stat = stats.get(this.toIso(candidate));
      if (!stat || stat.count < MAX) break;
      candidate.setDate(candidate.getDate() + 1);
    }

    if (candidate > lastDay) candidate = new Date(year, month, 1);
    this.selectedDate.set(new Date(candidate));
    this.viewMode.set('settimana');
  }

  // ─── Common helpers ───────────────────────────────────────────────────────

  apptColor(a: Appointment): string {
    switch (a.appointmentStatus) {
      case 'completed':             return 'bg-slate-100 border-slate-300 text-slate-600';
      case 'cancelled': case 'no_show': return 'bg-red-100 border-red-400 text-red-800';
      case 'confirmed':             return 'bg-blue-100 border-blue-400 text-blue-800';
      case 'in_progress':           return 'bg-green-100 border-green-400 text-green-800';
      default:                      return 'bg-yellow-50 border-yellow-300 text-yellow-800';
    }
  }

  statusLabel(a: Appointment): string {
    const map: Record<string, string> = {
      in_progress: 'In corso', completed: 'Completato',
      cancelled: 'Annullato', no_show: 'No show', confirmed: 'Confermato'
    };
    return map[a.appointmentStatus] ?? 'Programmato';
  }

  statusBadgeClass(a: Appointment): string {
    switch (a.appointmentStatus) {
      case 'in_progress': return 'bg-green-100 text-green-700';
      case 'completed':   return 'bg-slate-100 text-slate-500';
      case 'cancelled': case 'no_show': return 'bg-red-100 text-red-700';
      case 'confirmed':   return 'bg-blue-100 text-blue-700';
      default:            return 'bg-yellow-50 text-yellow-700';
    }
  }

  formatTime(iso: string): string {
    return new Date(iso).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  }

  toIso(d: Date): string {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  }

  private buildMonthGrid(ref: Date): Date[][] {
    const firstDay = new Date(ref.getFullYear(), ref.getMonth(), 1);
    const dow = firstDay.getDay();
    const offset = dow === 0 ? 6 : dow - 1;
    const start = new Date(firstDay);
    start.setDate(firstDay.getDate() - offset);
    const weeks: Date[][] = [];
    const cur = new Date(start);
    for (let w = 0; w < 6; w++) {
      const week: Date[] = [];
      for (let d = 0; d < 7; d++) {
        week.push(new Date(cur));
        cur.setDate(cur.getDate() + 1);
      }
      weeks.push(week);
    }
    return weeks;
  }
}
