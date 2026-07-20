/** Proposta di slot libero da GET /api/appointments/availability (#31). */
export interface AvailabilitySlot {
  date: string;        // "yyyy-MM-dd"
  startTime: string;   // "HH:mm"
  endTime: string;     // "HH:mm"
  chairLabel: string;
  providerId: string;
  providerName: string;
}

export interface Appointment {
  appointmentId: string;
  startsAt: string;
  endsAt: string;
  chairLabel: string;
  appointmentStatus: string;
  notes: string | null;
  patientId: string;
  patientFullName: string;
  patientPhone: string | null;
  providerId: string;
  providerName: string;
  providerRole: string;
  serviceName: string | null;
  serviceCategory: string | null;
  toothNumber: string | null;
  hasAllergyAlert: boolean;
  hasMedicationAlert: boolean;
  overdueRecallCount: number;
  upcomingRecallCount: number;
  openEstimateCount: number;
  overdueInvoiceCount: number;
}
