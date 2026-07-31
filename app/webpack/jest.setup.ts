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
    cc0: {},
    cc_by: {},
    cc_by_nc: {},
    cc_by_sa: {},
    cc_by_nd: {},
    cc_by_nc_sa: {},
    cc_by_nc_nd: {}
  }
};

// CURRENT_USER is a Rails-injected global. It is the gate's fallback for components
// whose container maps neither `config` nor `currentUser` (see gated_component.tsx), so
// opt tests into the group to exercise the responsive layouts.
( global as unknown as Record<string, unknown> ).CURRENT_USER = {
  testGroups: ["responsive-taxon-detail"]
};

// jsdom does not implement ResizeObserver (carousel.tsx instantiates one on mount).
const noop = ( ) => undefined;
function ResizeObserverStub( ) {
  return { observe: noop, unobserve: noop, disconnect: noop };
}
( global as unknown as Record<string, unknown> ).ResizeObserver = ResizeObserverStub;
