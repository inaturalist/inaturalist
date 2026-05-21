import { test, expect } from "@playwright/test";
import { LoginPage } from "../../page-objects/login.page";
import { appMake } from "../../support/on-rails";

const TEST_PASSWORD = "TestPass123!";

test.describe( "Login page", () => {
  let loginPage: LoginPage;

  test.beforeEach( async ( { page } ) => {
    loginPage = new LoginPage( page );
    await loginPage.goto();
  } );

  test( "displays all form elements", async () => {
    await loginPage.assertFormElements();
  } );

  test( "shows email and password inputs", async () => {
    await expect( loginPage.emailInput ).toBeVisible();
    await expect( loginPage.passwordInput ).toBeVisible();
  } );

  test( "shows submit button", async () => {
    await expect( loginPage.submitButton ).toBeVisible();
  } );

  test( "shows signup link", async () => {
    await expect( loginPage.signupLink ).toBeVisible();
  } );

  test( "shows forgot password link", async () => {
    await expect( loginPage.forgotPasswordLink ).toBeVisible();
  } );

  test( "invalid credentials show error", async () => {
    await loginPage.login( "invalid@example.com", "wrongpassword" );
    await loginPage.assertLoginError();
  } );
} );

test.describe( "Login happy path", () => {
  let testEmail: string;

  test.beforeEach( async ( { page } ) => {
    const user = await appMake( "create", "user", {
      email: `e2e_login_${Date.now()}@gmail.com`,
      password: TEST_PASSWORD
    } );
    testEmail = user.email as string;
    const loginPage = new LoginPage( page );
    await loginPage.goto();
  } );

  test( "submitting valid credentials redirects away from /login", async ( { page } ) => {
    const loginPage = new LoginPage( page );
    await Promise.all( [
      page.waitForURL( url => !url.pathname.startsWith( "/login" )
        && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
      loginPage.login( testEmail, TEST_PASSWORD )
    ] );
    expect( new URL( page.url() ).pathname ).not.toMatch( /^\/(login|session)/ );
  } );

  test( "sets CURRENT_USER on the window after login", async ( { page } ) => {
    const loginPage = new LoginPage( page );
    await Promise.all( [
      page.waitForURL( url => !url.pathname.startsWith( "/login" )
        && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
      loginPage.login( testEmail, TEST_PASSWORD )
    ] );
    expect( await loginPage.isLoggedIn() ).toBe( true );
  } );

  test( "header shows signed-in user menu after login", async ( { page } ) => {
    const loginPage = new LoginPage( page );
    await Promise.all( [
      page.waitForURL( url => !url.pathname.startsWith( "/login" )
        && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
      loginPage.login( testEmail, TEST_PASSWORD )
    ] );
    await expect( page.locator( "#usernav li.navtab.user.menutab" ) ).toBeVisible();
    await expect( page.locator( "#usernav li.navtab.signedout" ) ).toHaveCount( 0 );
  } );

  test( "persists session on subsequent navigation", async ( { page } ) => {
    const loginPage = new LoginPage( page );
    await Promise.all( [
      page.waitForURL( url => !url.pathname.startsWith( "/login" )
        && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
      loginPage.login( testEmail, TEST_PASSWORD )
    ] );
    await page.goto( "/observations" );
    expect( await loginPage.isLoggedIn() ).toBe( true );
  } );

  test( "remember-me checkbox can be toggled before submit", async ( { page } ) => {
    const loginPage = new LoginPage( page );
    await expect( loginPage.rememberCheckbox ).not.toBeChecked();
    await loginPage.rememberCheckbox.check();
    await expect( loginPage.rememberCheckbox ).toBeChecked();
    await Promise.all( [
      page.waitForURL( url => !url.pathname.startsWith( "/login" )
        && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
      loginPage.login( testEmail, TEST_PASSWORD )
    ] );
    expect( await loginPage.isLoggedIn() ).toBe( true );
  } );
} );
