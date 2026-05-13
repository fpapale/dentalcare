import { Appointment } from './appointment.model';

export interface Dashboard {
  clinicName: string;
  city: string;
  patientsCount: number;
  activeProvidersCount: number;
  treatmentPlansInProgress: number;
  sentEstimatesCount: number;
  acceptedEstimatesAmount: number | null;
  todayTotal: number;
  todayConfirmed: number;
  todayCompleted: number;
  todayCancelled: number;
  todayAppointments: Appointment[];
}
