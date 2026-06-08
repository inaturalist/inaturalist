import { test, expect } from "@playwright/test";
import { LoginPage } from "../../page-objects/login.page";
import { login } from "../../helpers/auth.helper";
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

  test( "invalid credentials show error", async () => {
    await loginPage.login( "invalid@example.com", "wrongpassword" );
    await loginPage.assertLoginError();
  } );
} );

test.describe( "Login happy path", () => {
  let testEmail: string;

  test.beforeEach( async () => {
    const user = await appMake( "create", "user", {
      password: TEST_PASSWORD
    } );
    testEmail = user.email as string;
  } );

  test( "submitting valid credentials redirects away from /login", async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
    expect( new URL( page.url() ).pathname ).not.toMatch( /^\/(login|session)/ );
  } );

  test( "sets CURRENT_USER on the window after login", async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
    const loginPage = new LoginPage( page );
    expect( await loginPage.isLoggedIn() ).toBe( true );
  } );

  test( "header shows signed-in user menu after login", async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
    await expect( page.locator( "#usernav li.navtab.user.menutab" ) ).toBeVisible();
    await expect( page.locator( "#usernav li.navtab.signedout" ) ).toHaveCount( 0 );
  } );

  test( "persists session on subsequent navigation", async ( { page } ) => {
    await login( page, testEmail, TEST_PASSWORD );
    await page.goto( "/observations" );
    const loginPage = new LoginPage( page );
    expect( await loginPage.isLoggedIn() ).toBe( true );
  } );
} );
