export interface ToothCondition {
  toothFdi: number;
  surface: string;
  condition: string;
  notes?: string | null;
  source?: string | null;
}

export interface SaveOdontogramRequest {
  conditions: ToothCondition[];
}
