import { connect } from "react-redux";
import App from "../components/app";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;

