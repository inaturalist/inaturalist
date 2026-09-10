const SET_ACTIVE_TAB = "obs-show/comment_id_panel/SET_ACTIVE_TAB";
const SET_NOMINATE_ON_SUBMIT = "obs-show/comment_id_panel/SET_NOMINATE_ON_SUBMIT";
const SET_SUGGESTED_TAXON = "obs-show/comment_id_panel/SET_SUGGESTED_TAXON";

export default function reducer( state = { activeTab: "comment" }, action ) {
  switch ( action.type ) {
    case SET_ACTIVE_TAB:
      return Object.assign( { }, state, { activeTab: action.activeTab } );
    case SET_NOMINATE_ON_SUBMIT:
      return Object.assign( { }, state, { nominate: action.nominate } );
    case SET_SUGGESTED_TAXON:
      return Object.assign( { }, state, { suggestedTaxon: action.taxon } );
    default:
      // nothing to see here
  }
  return state;
}

export function setActiveTab( activeTab ) {
  return {
    type: SET_ACTIVE_TAB,
    activeTab
  };
}

export function setNominateOnSubmit( nominate ) {
  return {
    type: SET_NOMINATE_ON_SUBMIT,
    nominate
  };
}

export function setSuggestedTaxon( taxon ) {
  return {
    type: SET_SUGGESTED_TAXON,
    taxon
  };
}
