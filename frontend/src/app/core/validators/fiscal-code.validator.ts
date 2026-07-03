import { AbstractControl, ValidationErrors, ValidatorFn } from '@angular/forms';

const CF_RE = /^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$/;
const MONTHS = 'ABCDEHLMPRST';

/**
 * Valida il CF italiano sul FormGroup paziente. Skip se pazienteStraniero=true o CF vuoto.
 * Controlli: formato regex + cross-check mese/giorno/anno con dataNascita.
 */
export const fiscalCodeValidator: ValidatorFn = (group: AbstractControl): ValidationErrors | null => {
  const foreign = group.get('pazienteStraniero')?.value === true;
  if (foreign) return null;

  const cfCtrl = group.get('cf');
  const raw = (cfCtrl?.value ?? '').toString().trim().toUpperCase();
  if (!raw) return null; // 'required' gestito a parte

  if (!CF_RE.test(raw)) return { fiscalCodeFormat: true };

  const birth = group.get('dataNascita')?.value;
  if (!birth) return null;
  const d = new Date(birth);

  const cfYear2 = parseInt(raw.substring(6, 8), 10);
  const month = MONTHS.indexOf(raw.charAt(8)) + 1;
  let day = parseInt(raw.substring(9, 11), 10);
  if (day > 40) day -= 40;

  if (month !== d.getMonth() + 1 || day !== d.getDate() || cfYear2 !== d.getFullYear() % 100) {
    return { fiscalCodeDateMismatch: true };
  }
  return null;
};
