export interface ClinicalHistoryEntry {
  entryId: string;
  entryDate: string;
  providerName: string;
  toothNumber: string | null;
  serviceName: string | null;
  clinicalNotes: string;
  nextVisitNotes: string | null;
}

export interface TreatmentPlanSummary {
  planId: string;
  name: string;
  status: string;
  totalItems: number;
  completedItems: number;
  openItems: number;
  createdAt: string;
  updatedAt: string;
}

export interface OdontogramSummary {
  exists: boolean;
  totalTeeth: number;
  healthyTeeth: number;
  missingTeeth: number;
  treatedTeeth: number;
  lastUpdatedAt: string | null;
}
