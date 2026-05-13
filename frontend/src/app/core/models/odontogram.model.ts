export interface ToothCondition {
  toothFdi: number;
  surface: string;
  condition: string;
  notes?: string | null;
}

export interface SaveOdontogramRequest {
  conditions: ToothCondition[];
}
