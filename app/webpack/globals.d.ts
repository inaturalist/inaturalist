declare module "*.module.css" {
  const styles: Record<string, string>;
  export default styles;
}

declare const I18n: {
  t: ( key: string, options?: Record<string, unknown> ) => string;
  toNumber: ( value: number, options?: Record<string, unknown> ) => string;
  localize: ( format: string, value: unknown ) => string;
};

declare function $( selector: string | Element, context?: Element | null ): {
  on: ( event: string, handler: ( ) => void ) => void;
  off: ( event: string, handler: ( ) => void ) => void;
  carousel: ( command: string ) => void;
  tab: ( command: string ) => void;
};
declare namespace $ {
  function param( obj: Record<string, unknown> ): string;
  function deparam( str: string ): Record<string, unknown>;
}

declare const iNaturalist: {
  Licenses: Record<string, unknown>;
  [key: string]: unknown;
};

declare module "react-bootstrap";
declare module "react-redux";
declare module "react-infinite-scroller";
