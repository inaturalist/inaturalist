declare const I18n: {
  t: ( key: string, options?: Record<string, unknown> ) => string;
  toNumber: ( value: number, options?: Record<string, unknown> ) => string;
};

declare const $: ( selector: string | Element, context?: Element | null ) => {
  on: ( event: string, handler: ( ) => void ) => void;
  off: ( event: string, handler: ( ) => void ) => void;
  carousel: ( command: string ) => void;
  tab: ( command: string ) => void;
};
