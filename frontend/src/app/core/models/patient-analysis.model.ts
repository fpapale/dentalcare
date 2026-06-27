export interface AnalysisLabel {
  id: string;
  toothFdi: string | null;
  disease: string;
  diseaseConfidence: number | null;
  fdiConfidence: number | null;
  bboxX1: number; bboxY1: number; bboxX2: number; bboxY2: number;
  matchingMethod: string;
  matchingScore: number | null;
  needsReview: boolean;
  source: string;
  action: string | null;
}

export interface PatientAnalysis {
  id: string;
  patientId: string;
  documentId: string;
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  detectionsCount: number;
  needsReview: boolean;
  reviewStatus: string;
  resultBucket: string | null;
  resultObjectKey: string | null;
  annotatedObjectKey: string | null;
  errorMessage: string | null;
  createdAt: string | null;
  labels: AnalysisLabel[];
}

export interface ReviewAnalysisRequest {
  reviewStatus: 'reviewed' | 'approved_for_training' | 'excluded';
  labels: AnalysisLabel[];
}

export const DISEASE_LABELS: Record<string, string> = {
  Caries: 'Carie',
  Deep_Caries: 'Carie profonda',
  Periapical_Lesion: 'Lesione periapicale',
  Impacted: 'Incluso',
};

/** Quadrant colors mirror the ai-service annotated image (DENTEX). */
export function quadrantColor(tooth: string | null): string {
  if (!tooth) return '#9E9E9E';
  switch (tooth[0]) {
    case '1': return '#57C84D';
    case '2': return '#E84D4D';
    case '3': return '#4DC8E8';
    case '4': return '#E8C84D';
    default: return '#9E9E9E';
  }
}
