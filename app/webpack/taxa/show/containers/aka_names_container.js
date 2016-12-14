import { connect } from "react-redux";
import _ from "lodash";
import AkaNames from "../components/aka_names";

function mapStateToProps( state ) {
  const taxon = state.taxon.taxon;
  const place = state.config.preferredPlace || state.config.chosenPlace;
  if ( !place ) {
    return { };
  }
  return {
    names: _.filter( state.taxon.names, taxonName =>
      taxonName.lexicon !== "Scientific Names" &&
      taxonName.name !== taxon.preferred_common_name &&
      taxonName.name !== taxon.name &&
      taxonName.place_taxon_names &&
      _.find( taxonName.place_taxon_names, ptn => ptn.place_id === place.id )
    ).slice( 0, 5 )
  };
}

function mapDispatchToProps( ) {
  return { };
}

const AkaNamesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AkaNames );

export default AkaNamesContainer;
