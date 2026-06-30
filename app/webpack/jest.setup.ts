import "@testing-library/jest-dom";

// I18n is a Rails-injected global; return the raw key so assertions match the
// key string without translation coupling.
( global as unknown as Record<string, unknown> ).I18n = {
  t: ( key: string ) => key,
  toNumber: ( value: number ) => String( value ),
  localize: ( _format: string, value: unknown ) => String( value )
};

// jsdom does not implement ResizeObserver (carousel.tsx instantiates one on mount).
const noop = ( ) => undefined;
function ResizeObserverStub( ) {
  return { observe: noop, unobserve: noop, disconnect: noop };
}
( global as unknown as Record<string, unknown> ).ResizeObserver = ResizeObserverStub;
