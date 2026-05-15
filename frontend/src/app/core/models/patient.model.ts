export interface PatientListItem {
  patientId: string;
  patientFullName: string;
  firstName: string;
  lastName: string;
  fiscalCode: string | null;
  birthDate: string | null;
  ageYears: number | null;
  phone: string | null;
  email: string | null;
  city: string | null;
  province: string | null;
  treatmentPlansCount: number;
  openTreatmentItemsCount: number;
  totalAppointments: number;
  acceptedEstimatesAmount: number | null;
}

export interface PatientDetail {
  patientId: string;
  firstName: string;
  lastName: string;
  fullName: string;
  fiscalCode: string | null;
  birthDate: string | null;
  ageYears: number | null;
  phone: string | null;
  email: string | null;
  city: string | null;
  province: string | null;
  addressLine1: string | null;
  postalCode: string | null;
  notes: string | null;
  bloodType: string | null;
  smoker: boolean | null;
  hypertension: boolean | null;
  diabetes: boolean | null;
  heartDisease: boolean | null;
  takingAnticoagulants: boolean | null;
  takingBisphosphonates: boolean | null;
  allergyPenicillin: boolean | null;
  allergyLatex: boolean | null;
  allergyAnesthetic: boolean | null;
  otherAllergies: string | null;
  anamnesisNotes: string | null;
  anamnesisDate: string | null;
  photoUrl?: string | null;
  totalAppointments: number;
  treatmentPlansCount: number;
  openTreatmentItemsCount: number;
}
