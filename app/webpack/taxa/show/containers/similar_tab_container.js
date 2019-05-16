import { connect } from "react-redux";
import SimilarTab from "../components/similar_tab";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  return {
    results: state.taxon.similar,
    place: state.config.chosenPlace,
    config: state.config,
    taxon: state.taxon.taxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const SimilarTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SimilarTab );

export default SimilarTabContainer;
