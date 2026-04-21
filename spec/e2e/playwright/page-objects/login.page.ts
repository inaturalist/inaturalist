import { Page, Locator, expect } from "@playwright/test";
import { BasePage } from "./base.page";

export class LoginPage extends BasePage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly signupLink: Locator;
  readonly rememberCheckbox: Locator;
  readonly forgotPasswordLink: Locator;
  readonly loginForm: Locator;

  constructor( page: Page ) {
    super( page );
    this.loginForm = page.locator( "form.log-in" );
    this.emailInput = this.loginForm.locator( "input[type='email']" );
    this.passwordInput = this.loginForm.locator( "input[type='password']" );
    this.submitButton = this.loginForm.locator( "input[type='submit'][name='commit']" );
    this.signupLink = this.loginForm.locator( "a.btn.btn-link[href='/signup']" );
    this.rememberCheckbox = this.loginForm.locator( "#user_remember_me" );
    this.forgotPasswordLink = this.loginForm.locator( "a[href='/users/password/new']" );
  }

  async goto(): Promise<void> {
    await super.goto( "/login" );
  }

  async login( email: string, password: string ): Promise<void> {
    await this.emailInput.fill( email );
    await this.passwordInput.fill( password );
    await this.submitButton.click();
  }

  async assertLoginError(): Promise<void> {
    const errorMessage = this.page.locator( ".alert, .error, .flash" ).first();
    await expect( errorMessage ).toBeVisible( { timeout: 10_000 } );
  }

  async assertFormElements(): Promise<void> {
    await expect( this.loginForm ).toBeVisible();
    await expect( this.emailInput ).toBeVisible();
    await expect( this.passwordInput ).toBeVisible();
    await expect( this.submitButton ).toBeVisible();
  }
}
