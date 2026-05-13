export interface AnamnesisItemDto {
  id: string;
  code: string;
  label: string;
  description: string | null;
  isAlert: boolean;
  sortOrder: number;
  selected: boolean;
  selectionNotes: string | null;
}

export interface AnamnesisCategoryDto {
  id: string;
  code: string;
  name: string;
  description: string | null;
  icon: string | null;
  sortOrder: number;
  items: AnamnesisItemDto[];
  hasSelections: boolean;
}

export interface SaveAnamnesisRequest {
  selections: { itemId: string; notes: string | null }[];
  bloodType: string | null;
  generalNotes: string | null;
}
