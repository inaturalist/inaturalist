import { connect } from "react-redux";
import { urlForTaxon } from "../util";
import TaxonCrumbs from "../components/taxon_crumbs";
import { setConfig } from "../../../shared/ducks/config";
import { updateSession } from "../../../shared/util";

function mapStateToProps( state, ownProps ) {
  const { taxon } = state.taxon;
  return {
    taxon,
    ancestors: taxon.ancestors,
    url: urlForTaxon( taxon ),
    currentText: ownProps.currentText,
    ancestorsShown: state.config.ancestorsShown,
    config: state.config
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    showAncestors: ( ) => {
      dispatch( setConfig( { ancestorsShown: true } ) );
      updateSession( { preferred_taxon_page_ancestors_shown: true } );
    },
    hideAncestors: ( ) => {
      dispatch( setConfig( { ancestorsShown: false } ) );
      updateSession( { preferred_taxon_page_ancestors_shown: false } );
    },
    ...( ownProps.showNewTaxon ? { showNewTaxon: ownProps.showNewTaxon } : {} )
  };
}

const TaxonCrumbsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonCrumbs );

export default TaxonCrumbsContainer;
