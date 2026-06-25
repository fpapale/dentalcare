import { Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { AppointmentService } from '../../core/services/appointment.service';
import { UserContextService } from '../../core/services/user-context.service';
import { HolidayService } from '../../core/services/holiday.service';
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
  private readonly holidayService = inject(HolidayService);

  today = new Date();
  selectedDate = signal<Date>(new Date());
  viewMode = signal<'giorno' | 'settimana' | 'mese' | 'prossimi'>('prossimi');

  // Day view
  appointments  = signal<Appointment[]>([]);
  loading       = signal(true);
  error         = signal<string | null>(null);
  showingNextDay = signal(false);

  // Week / month range view
  rangeAppointments = signal<Appointment[]>([]);
  loadingRange = signal(false);

  // Mini calendar picker
  calendarOpen = signal(false);
  calendarMonth = signal<Date>(new Date());

  // Holidays (key 'YYYY-MM-DD' → name)
  holidays = signal<Map<string, string>>(new Map());
  private lastHolidayMonth = '';

  readonly role = this.userContext.role;

  readonly hours = ['08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00'];
  readonly dayNames = ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'];

  // ─── Computed ─────────────────────────────────────────────────────────────

  apptStatusFilter    = signal<string[]>(['confirmed', 'presente']);
  dayStatusFilter     = signal<string[]>(['scheduled', 'confirmed', 'presente']);

  readonly upcomingAppointments = computed(() => {
    const now = new Date();
    return this.appointments()
      .filter(a => new Date(a.endsAt) >= now)
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  });

  readonly filteredUpcoming = computed(() => {
    const f = this.apptStatusFilter();
    const all = this.upcomingAppointments();
    return f.length === 0 ? all : all.filter(a => f.includes(a.appointmentStatus));
  });

  toggleFilter(status: string): void {
    this.apptStatusFilter.update(f =>
      f.includes(status) ? f.filter(s => s !== status) : [...f, status]
    );
  }

  isFilterActive(status: string): boolean {
    return this.apptStatusFilter().includes(status);
  }

  toggleDayFilter(status: string): void {
    this.dayStatusFilter.update(f =>
      f.includes(status) ? f.filter(s => s !== status) : [...f, status]
    );
  }

  isDayFilterActive(status: string): boolean {
    return this.dayStatusFilter().includes(status);
  }

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
      if (a.appointmentStatus === 'cancelled' || a.appointmentStatus === 'no_show') continue;
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
      this.showingNextDay.set(false);
      this.appointmentService.findByDate(this.toIso(d), providerId).subscribe({
        next: data => {
          const now = new Date();
          const isToday = d.toDateString() === now.toDateString();
          const hasUpcoming = data.some(a => new Date(a.endsAt) >= now);

          if (isToday && !hasUpcoming) {
            const tomorrow = new Date(d);
            tomorrow.setDate(d.getDate() + 1);

            if (mode === 'prossimi') {
              this.showingNextDay.set(true);
              this.appointmentService.findByDate(this.toIso(tomorrow), providerId).subscribe({
                next: td => { this.appointments.set(td); this.loading.set(false); },
                error: ()  => { this.appointments.set([]); this.loading.set(false); }
              });
              return;
            }

            if (mode === 'giorno') {
              this.showingNextDay.set(true);
              this.appointmentService.findByDate(this.toIso(tomorrow), providerId).subscribe({
                next: td => { this.appointments.set(td); this.loading.set(false); },
                error: ()  => { this.appointments.set([]); this.loading.set(false); }
              });
              return;
            }
          }

          this.appointments.set(data);
          this.loading.set(false);
        },
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

    // Holidays: fetch the full monthGrid range; refetch only when month changes
    effect(() => {
      const d = this.selectedDate();
      const monthKey = `${d.getFullYear()}-${d.getMonth()}`;
      if (monthKey === untracked(() => this.lastHolidayMonth)) return;
      this.lastHolidayMonth = monthKey;
      const grid = untracked(() => this.monthGrid());
      const from = grid[0][0];
      const last = grid[grid.length - 1];
      const to = last[last.length - 1];
      this.holidayService.findInRange(this.toIso(from), this.toIso(to)).subscribe({
        next: list => this.holidays.set(new Map(list.map(h => [h.date, h.name]))),
        error: () => {}
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
    if (this.isHoliday(d)) return 'text-rose-600 bg-rose-50 hover:bg-rose-100';
    if (this.isWeekend(d)) return 'text-slate-400 bg-slate-100 hover:bg-slate-200';
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
    const f = this.dayStatusFilter();
    return this.appointments().filter(a =>
      a.chairLabel === chair && (f.length === 0 || f.includes(a.appointmentStatus))
    );
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
    const f = this.dayStatusFilter();
    return this.rangeAppointments()
      .filter(a => new Date(a.startsAt).toISOString().slice(0, 10) === key
        && (f.length === 0 || f.includes(a.appointmentStatus)))
      .sort((a, b) => new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime());
  }

  getWeekLayoutForDay(day: Date): Array<{
    apt: Appointment;
    topPx: number;
    heightPx: number;
    left: string;
    width: string;
  }> {
    const apts = this.getAppointmentsForDay(day);
    if (apts.length === 0) return [];

    const colEnds: number[] = [];
    const colOf = new Map<string, number>();

    for (const apt of apts) {
      const s = new Date(apt.startsAt).getTime();
      let col = colEnds.findIndex(end => end <= s);
      if (col === -1) col = colEnds.length;
      colOf.set(apt.appointmentId, col);
      colEnds[col] = new Date(apt.endsAt).getTime();
    }

    return apts.map(apt => {
      const s = new Date(apt.startsAt).getTime();
      const e = new Date(apt.endsAt).getTime();
      const col = colOf.get(apt.appointmentId)!;

      const overlapping = apts.filter(b =>
        new Date(b.startsAt).getTime() < e && new Date(b.endsAt).getTime() > s
      );
      const maxCol = Math.max(...overlapping.map(b => colOf.get(b.appointmentId)!));
      const total = maxCol + 1;

      const leftPct = (col / total) * 100;
      const widthPct = (1 / total) * 100;

      return {
        apt,
        topPx: this.topPx(apt) * (64 / 96),
        heightPx: this.heightPx(apt) * (64 / 96),
        left: col === 0 ? `${leftPct}%` : `calc(${leftPct}% + 1px)`,
        width: total === 1 ? 'calc(100% - 2px)' : `calc(${widthPct}% - 2px)`
      };
    });
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

  // ─── Weekend / holiday helpers ────────────────────────────────────────────

  isWeekend(d: Date): boolean {
    const dow = d.getDay();
    return dow === 0 || dow === 6;
  }

  isHoliday(d: Date): boolean {
    return this.holidays().has(this.toIso(d));
  }

  holidayName(d: Date): string | null {
    return this.holidays().get(this.toIso(d)) ?? null;
  }

  dayTint(d: Date): string {
    if (this.isHoliday(d)) return 'bg-rose-50 dark:bg-rose-900/20';
    if (this.isWeekend(d)) return 'bg-slate-100 dark:bg-slate-900/40';
    return '';
  }

  // ─── Common helpers ───────────────────────────────────────────────────────

  private readonly chairPalette = [
    'bg-blue-100 border-blue-400 text-blue-900',
    'bg-violet-100 border-violet-400 text-violet-900',
    'bg-emerald-100 border-emerald-400 text-emerald-900',
    'bg-orange-100 border-orange-400 text-orange-900',
    'bg-pink-100 border-pink-400 text-pink-900',
    'bg-cyan-100 border-cyan-400 text-cyan-900',
    'bg-amber-100 border-amber-400 text-amber-900',
    'bg-teal-100 border-teal-400 text-teal-900',
  ];

  private chairColor(label: string): string {
    if (!label) return this.chairPalette[0];
    let h = 0;
    for (let i = 0; i < label.length; i++) h = (h * 31 + label.charCodeAt(i)) & 0xffff;
    return this.chairPalette[h % this.chairPalette.length];
  }

  apptColor(a: Appointment): string {
    if (a.appointmentStatus === 'completed')  return 'bg-slate-100 border-slate-300 text-slate-500';
    if (a.appointmentStatus === 'cancelled' || a.appointmentStatus === 'no_show')
                                              return 'bg-red-100 border-red-400 text-red-800';
    return this.chairColor(a.chairLabel ?? '');
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
