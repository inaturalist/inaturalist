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
  .icon-iconic-animalia:before  { content: "\\e00a"; }
  .icon-iconic-aves:before      { content: "\\e00c"; }
  .icon-iconic-arachnida:before { content: "\\e00b"; }
  .icon-iconic-actinopterygii:before { content: "\\e00d"; }
  .icon-iconic-reptilia:before  { content: "\\e00e"; }
  .icon-iconic-protozoa:before  { content: "\\e00f"; }
  .icon-iconic-plantae:before   { content: "\\e010"; }
  .icon-iconic-mollusca:before  { content: "\\e011"; }
  .icon-iconic-mammalia:before  { content: "\\e012"; }
  .icon-iconic-chromista:before { content: "\\e013"; }
  .icon-iconic-insecta:before   { content: "\\e014"; }
  .icon-iconic-fungi:before     { content: "\\e015"; }
  .icon-iconic-unknown:before   { content: "\\e01a"; }
  .icon-iconic-amphibia:before  { content: "\\e01b"; }
`;
document.head.appendChild( iconFont );

const translations: Record<string, string> = {
  view_all_caps: "VIEW ALL",
  previous_taxon_short: "‹",
  next_taxon_short: "›",
  view_photo: "View photo",
  view_taxon: "View taxon",
  "ranks.stateofmatter": "State of matter",
  "ranks.kingdom": "Kingdom",
  "ranks.subkingdom": "Subkingdom",
  "ranks.phylum": "Phylum",
  "ranks.subphylum": "Subphylum",
  "ranks.superclass": "Superclass",
  "ranks.class": "Class",
  "ranks.subclass": "Subclass",
  "ranks.infraclass": "Infraclass",
  "ranks.superorder": "Superorder",
  "ranks.order": "Order",
  "ranks.suborder": "Suborder",
  "ranks.infraorder": "Infraorder",
  "ranks.superfamily": "Superfamily",
  "ranks.epifamily": "Epifamily",
  "ranks.family": "Family",
  "ranks.subfamily": "Subfamily",
  "ranks.tribe": "Tribe",
  "ranks.subtribe": "Subtribe",
  "ranks.genus": "Genus",
  "ranks.genushybrid": "Genushybrid",
  "ranks.subgenus": "Subgenus",
  "ranks.section": "Section",
  "ranks.subsection": "Subsection",
  "ranks.complex": "Complex",
  "ranks.species": "Species",
  "ranks.hybrid": "Hybrid",
  "ranks.subspecies": "Subspecies",
  "ranks.variety": "Variety",
  "ranks.form": "Form",
  "ranks.infrahybrid": "Infrahybrid"
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
