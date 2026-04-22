import { request, expect } from "@playwright/test";
import { envConfig } from "../../shared/env.config";

const contextPromise = request.newContext( {
  baseURL: envConfig.baseUrl
} );

interface CommandPayload {
  name: string;
  options?: Record<string, unknown> | string | unknown[];
}

const appCommands = async ( data: CommandPayload | CommandPayload[] ): Promise<unknown[]> => {
  const context = await contextPromise;
  const response = await context.post( "/__e2e__/command", { data } );
  expect( response.ok() ).toBeTruthy();
  return await response.json();
};

const app = async ( name: string, options: Record<string, unknown> | string | unknown[] = {} ): Promise<unknown> => {
  const results = await appCommands( { name, options } );
  return results[0];
};

const appScenario = ( name: string, options: Record<string, unknown> = {} ): Promise<unknown> =>
  app( "scenarios/" + name, options );

const appEval = ( code: string ): Promise<unknown> =>
  app( "eval", code );

const appFactories = ( options: unknown[] ): Promise<unknown> =>
  app( "factory_bot", options );

/**
 * Call a MakeHelpers method on the server.
 * Returns the record attributes (or array of attributes) created by the helper.
 *
 * @example
 *   const user = await appMachinistHelper("make_curator", { login: "curator1" });
 *   const obs = await appMachinistHelper("make_research_grade_observation");
 */
const appMachinistHelper = (
  method: string,
  args: Record<string, unknown> = {}
): Promise<Record<string, unknown>> =>
  app( "machinist_helper", { method, args } ) as Promise<Record<string, unknown>>;

/**
 * Create a record using Machinist blueprints via SmartFactoryWrapper.
 *
 * @example
 *   const user = await appMake("create", "user", { login: "testuser" });
 *   const obs = await appMake("create", "observation", { description: "Test" });
 */
const appMake = ( factoryMethod: string, ...factoryArgs: unknown[] ): Promise<Record<string, unknown>> =>
  appFactories( [factoryMethod, ...factoryArgs] ) as Promise<Record<string, unknown>>;

const appClean = (): Promise<unknown> => app( "clean" );

const appVcrInsertCassette = async ( cassetteName: string, options?: Record<string, unknown> ) => {
  const context = await contextPromise;
  const opts = options ? Object.fromEntries(
    Object.entries( options ).filter( ( [, v] ) => v !== undefined )
  ) : {};
  const response = await context.post( "/__e2e__/vcr/insert", { data: [cassetteName, opts] } );
  expect( response.ok() ).toBeTruthy();
  return await response.json();
};

const appVcrEjectCassette = async () => {
  const context = await contextPromise;
  const response = await context.post( "/__e2e__/vcr/eject" );
  expect( response.ok() ).toBeTruthy();
  return await response.json();
};

export {
  appCommands,
  app,
  appScenario,
  appEval,
  appFactories,
  appMachinistHelper,
  appMake,
  appClean,
  appVcrInsertCassette,
  appVcrEjectCassette
};
