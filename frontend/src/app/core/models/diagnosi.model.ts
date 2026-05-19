export interface Diagnosi {
  id: string;
  toothNumber: string | null;
  title: string;
  description: string | null;
  icdCode: string | null;
  status: string;
  providerName: string;
  diagnosedAt: string;
  resolvedAt: string | null;
  createdAt: string;
}

export interface CreateDiagnosiRequest {
  providerId: string;
  toothNumber?: string;
  title: string;
  description?: string;
  icdCode?: string;
  diagnosedAt?: string;
}
