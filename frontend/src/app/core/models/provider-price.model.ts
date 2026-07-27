/**
 * Tariffa di una prestazione per un singolo medico (#44).
 *
 * `catalogPrice` è il prezzo dello studio (listino), `overridePrice` è l'eventuale
 * tariffa personale del medico (null = eredita dal listino). `effectivePrice` è il
 * prezzo effettivamente applicato e `source` indica da dove proviene.
 */
export interface ProviderPrice {
  serviceId: string;
  serviceName: string;
  category: string | null;
  catalogPrice: number;
  overridePrice: number | null;
  effectivePrice: number;
  source: 'override' | 'catalog';
}
