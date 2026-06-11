import type { Preview } from "@storybook/react";

const fa = document.createElement( "link" );
fa.rel = "stylesheet";
fa.href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css";
document.head.appendChild( fa );

const iconFont = document.createElement( "style" );
iconFont.textContent = `
  @font-face {
    font-family: "inaturalisticons";
    src: url("/fonts/inaturalisticons.woff") format("woff"),
         url("/fonts/inaturalisticons.ttf") format("truetype");
    font-weight: normal;
    font-style: normal;
  }
  [class^="icon-"]:before, [class*=" icon-"]:before {
    font-family: "inaturalisticons" !important;
    font-style: normal !important;
    font-weight: normal !important;
    font-variant: normal !important;
    text-transform: none !important;
    speak: none;
    line-height: 1;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
  .icon-iconic-fungi:before { content: "\\e015"; }
`;
document.head.appendChild( iconFont );

const translations: Record<string, string> = {
  view_all_caps: "VIEW ALL",
  previous_taxon_short: "‹",
  next_taxon_short: "›",
  view_photo: "View photo",
  view_taxon: "View taxon",
  "ranks.kingdom": "Kingdom"
};

type WindowWithGlobals = Window & {
  I18n?: unknown;
  iNatModels?: unknown;
};

( window as WindowWithGlobals ).I18n = {
  t: ( key: string ) => translations[key] ?? key
};

( window as WindowWithGlobals ).iNatModels = {
  Taxon: {
    titleCaseName: ( name: string ) => name
      ?.split( " " )
      .map( w => w.charAt( 0 ).toUpperCase( ) + w.slice( 1 ) )
      .join( " " ) ?? name
  }
};

const preview: Preview = {};

export default preview;
