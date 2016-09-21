const urlForTaxon = ( t ) => `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}?test=taxon-page`;

export {
  urlForTaxon
};
