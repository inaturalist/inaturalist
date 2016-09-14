const SET_TAXON = "taxa-show/taxon/SET_TAXON";

export default function reducer( state = {}, action ) {
  switch ( action.type ) {
    case SET_TAXON:
      return { taxon: action.taxon };
    default:
      return state;
  }
}

export function setTaxon( taxon ) {
  return {
    type: SET_TAXON,
    taxon
  };
}
