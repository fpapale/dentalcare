import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../../core/auth/auth.service';
import { ClinicOption, LoginPreflightResponse } from '../../core/auth/auth.model';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html'
})
export class LoginComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly today = new Date().getFullYear();
  readonly demoChecking = signal(true);

  readonly step = signal<'form' | 'choose'>('form');
  readonly chooseOptions = signal<ClinicOption[]>([]);
  readonly pendingEmail = signal('');
  readonly pendingPassword = signal('');
  readonly confirmingClinicId = signal<string | null>(null);

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]]
  });

  ngOnInit(): void {
    this.auth.getDemoToken().subscribe({
      next: (res) => {
        const dest = res.role === 'tenant_admin' ? '/admin-tenant' : '/dashboard';
        this.router.navigate([dest]);
      },
      error: () => this.demoChecking.set(false)
    });
  }

  onSubmit(): void {
    if (this.form.invalid || this.loading()) {
      this.form.markAllAsTouched();
      return;
    }
    this.error.set(null);
    this.loading.set(true);

    const { email, password } = this.form.getRawValue();
    this.pendingEmail.set(email);
    this.pendingPassword.set(password);

    this.auth.login({ email, password }).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.handlePreflight(res);
      },
      error: (err: HttpErrorResponse) => {
        this.loading.set(false);
        this.handleError(err);
      }
    });
  }

  private handlePreflight(res: LoginPreflightResponse): void {
    if (res.type === 'direct') {
      this.auth.storeDirectLogin(res);
      const dest = res.role === 'tenant_admin' ? '/admin-tenant' : '/dashboard';
      this.router.navigate([dest]);
      return;
    }

    const options = res.options ?? [];
    if (options.length === 1) {
      this.onConfirm(options[0]);
      return;
    }

    this.chooseOptions.set(options);
    this.step.set('choose');
  }

  onConfirm(option: ClinicOption): void {
    if (this.confirmingClinicId() !== null) {
      return;
    }
    this.error.set(null);
    this.confirmingClinicId.set(option.clinicId);

    this.auth.confirmLogin({
      email: this.pendingEmail(),
      password: this.pendingPassword(),
      clinicId: option.clinicId
    }).subscribe({
      next: () => {
        this.confirmingClinicId.set(null);
        const isAdmin = option.isTenantAdmin || option.role === 'tenant_admin';
        this.router.navigate([isAdmin ? '/admin-tenant' : '/dashboard']);
      },
      error: (err: HttpErrorResponse) => {
        this.confirmingClinicId.set(null);
        this.handleError(err);
      }
    });
  }

  backToForm(): void {
    this.step.set('form');
    this.chooseOptions.set([]);
    this.error.set(null);
  }

  private handleError(err: HttpErrorResponse): void {
    if (err.status === 401) {
      this.error.set('Credenziali non valide');
    } else if (err.status === 404) {
      this.error.set('Studio non trovato');
    } else {
      this.error.set('Si è verificato un errore. Riprova più tardi.');
    }
  }
}
