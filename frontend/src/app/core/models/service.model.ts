export interface ServiceItem {
  serviceId: string;
  code: string;
  name: string;
  category: string | null;
  defaultPrice: number;
  durationMinutes: number | null;
}
