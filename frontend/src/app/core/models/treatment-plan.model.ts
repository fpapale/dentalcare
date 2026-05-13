export interface TreatmentPlanSummary {
  planId: string;
  name: string;
  status: TreatmentPlanStatus;
  totalItems: number;
  completedItems: number;
  openItems: number;
  createdAt: string;
  updatedAt: string;
}

export interface TreatmentPlanItem {
  itemId: string;
  serviceId: string;
  serviceName: string;
  serviceCategory: string | null;
  durationMinutes: number | null;
  providerId: string | null;
  providerName: string | null;
  toothNumber: string | null;
  quadrant: number | null;
  plannedPrice: number;
  status: TreatmentItemStatus;
  priority: number;
  plannedDate: string | null;
  clinicalNotes: string | null;
  createdAt: string;
}

export interface TreatmentPlan {
  planId: string;
  name: string;
  description: string | null;
  status: TreatmentPlanStatus;
  patientId: string;
  patientFullName: string;
  createdByProviderId: string | null;
  createdByProviderName: string | null;
  createdAt: string;
  updatedAt: string;
  items: TreatmentPlanItem[];
}

export type TreatmentPlanStatus = 'draft' | 'proposed' | 'accepted' | 'completed' | 'rejected';
export type TreatmentItemStatus = 'planned' | 'accepted' | 'scheduled' | 'completed' | 'cancelled';
