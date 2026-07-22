export interface ToothCondition {
  toothFdi: number;
  surface: string;
  condition: string;
  notes?: string | null;
  source?: string | null;
}

/** A tooth/surface whose AI-sourced finding the clinician cleared (judged wrong). */
export interface ToothRef {
  toothFdi: number;
  surface: string;
}

export interface SaveOdontogramRequest {
  conditions: ToothCondition[];
  removedAi?: ToothRef[];
}
