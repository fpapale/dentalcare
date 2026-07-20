/**
 * Orari di apertura dello studio (#31), configurabili dall'amministratore.
 * Campi null = usa i default applicativi lato backend.
 * workingDays: numeri ISO separati da virgola, 1 = lunedì … 7 = domenica.
 */
export interface ClinicSchedule {
  workStartTime: string | null;   // "HH:mm"
  workEndTime: string | null;     // "HH:mm"
  slotMinutes: number | null;
  workingDays: string | null;     // es. "1,2,3,4,5"
}
