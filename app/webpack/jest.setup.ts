import "@testing-library/jest-dom";

// I18n is a Rails-injected global; return the raw key so assertions match the
// key string without translation coupling.
( global as unknown as Record<string, unknown> ).I18n = {
  t: ( key: string ) => key,
  toNumber: ( value: number ) => String( value ),
  localize: ( _format: string, value: unknown ) => String( value )
};

// iNaturalist is a Rails-injected global with static lookup tables.
( global as unknown as Record<string, unknown> ).iNaturalist = {
  Licenses: {
    cc0: {}, cc_by: {}, cc_by_nc: {}, cc_by_sa: {}, cc_by_nd: {},
    cc_by_nc_sa: {}, cc_by_nc_nd: {}
  }
};

// jsdom does not implement ResizeObserver (carousel.tsx instantiates one on mount).
const noop = ( ) => undefined;
function ResizeObserverStub( ) {
  return { observe: noop, unobserve: noop, disconnect: noop };
}
( global as unknown as Record<string, unknown> ).ResizeObserver = ResizeObserverStub;
