/// <reference types="google.maps" />

declare module "*.module.css" {
  const styles: Record<string, string>;
  export default styles;
}

interface MomentjsI18n {
  shortRelativeTime?: Record<string, string>;
}

declare const I18n: {
  locale: string;
  t( key: "momentjs", options?: Record<string, unknown> ): MomentjsI18n;
  t( key: string, options?: Record<string, unknown> ): string;
  toNumber( value: number, options?: Record<string, unknown> ): string;
  localize( format: string, value: unknown ): string;
};

// Intentionally narrow — jQuery is a Rails-injected global, not a webpack dep. $.deparam is also
// a non-standard plugin absent from @types/jquery, so a minimal stub beats the full type package.
interface JQueryStubResult {
  on: ( event: string, handler: ( ) => void ) => void;
  off: ( event: string, handler: ( ) => void ) => void;
  carousel: ( command: string ) => void;
  tab: ( command: string ) => void;
  data: ( key: string ) => unknown;
  get: ( index: number ) => Element | undefined;
  taxonMap: ( options?: unknown ) => void;
  animate: ( properties: Record<string, unknown>, duration?: number ) => JQueryStubResult;
  offset: ( ) => { top: number; left: number };
  val: ( value?: string ) => string;
  find: ( selector: string ) => JQueryStubResult;
}
interface JQueryDeparam {
  ( str: string ): Record<string, unknown>;
  querystring( ): Record<string, unknown>;
}
interface JQueryStub {
  ( selector: string | Element, context?: Element | null ): JQueryStubResult;
  ajax( url: string, settings?: Record<string, unknown> ): unknown;
  each<T>(
    collection: ArrayLike<T> | Record<string, T>,
    callback: ( indexOrKey: number | string, value: T ) => void
  ): void;
  scrollTo(
    target: string | number | Element,
    duration?: number,
    options?: Record<string, unknown>
  ): void;
  param( obj: Record<string, unknown> ): string;
  deparam: JQueryDeparam;
}
declare const $: JQueryStub;

declare const iNaturalist: {
  Licenses: Record<string, unknown>;
  [key: string]: unknown;
};

// v0.33.1 ships no types; @types/react-bootstrap is an empty stub pointing at newer versions
declare module "react-bootstrap";
// @types/react-redux starts at v5; project uses v4.4.9
declare module "react-redux";
// no types available on npm
declare module "react-lazy-load";
