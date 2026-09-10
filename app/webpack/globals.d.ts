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
  textcompleteUsers: ( ) => void;
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

// Rails-injected in the layout; undefined when logged out
declare const CURRENT_USER: {
  roles?: string[];
  testGroups?: string[];
  [key: string]: unknown;
} | undefined;

// v0.33.1 ships no types; @types/react-bootstrap is an empty stub pointing at newer versions
declare module "react-bootstrap";
// @types/react-redux starts at v5; project uses v4.4.9
declare module "react-redux";
// no types available on npm
declare module "react-lazy-load";

// github-hosted, ships no types
declare module "inaturalistjs";

// A taxon as returned by the taxa autocomplete/vision endpoints and wrapped by iNatModels.Taxon
interface INatTaxonRecord {
  id: number;
  name?: string;
  rank?: string;
  rank_level?: number;
  preferred_common_name?: string;
  preferred_common_names?: { name: string }[];
  iconic_taxon_name?: string;
  matched_term?: string;
  default_photo?: { id?: number; url?: string; square_url?: string };
  representative_photo?: { id?: number; url?: string; square_url?: string };
  iconicTaxonName?: ( ) => string;
  preferredCommonName?: ( options?: object ) => string;
}

// Rails-injected inaturalistjs model classes
declare const iNatModels: {
  Taxon: {
    new ( attrs: object ): INatTaxonRecord;
    titleCaseName( name?: string | null ): string;
  };
};

// Rails-injected in the layout from the viewer's place preference
declare const PREFERRED_PLACE: { id: number } | undefined;

// Rails-injected site configuration
declare const CONFIG: { content_freeze_enabled?: boolean } | undefined;
