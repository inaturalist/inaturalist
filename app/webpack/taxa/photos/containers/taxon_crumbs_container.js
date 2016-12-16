import { connect } from "react-redux";
import { urlForTaxon } from "../../shared/util";
import TaxonCrumbs from "../../shared/components/taxon_crumbs";
import { setConfig } from "../../../shared/ducks/config";
import { updateSession } from "../../../shared/util";

function mapStateToProps( state ) {
  const taxon = state.taxon.taxon;
  return {
    taxon,
    ancestors: taxon.ancestors,
    url: urlForTaxon( taxon ),
    currentText: I18n.t( "photo_browser" ),
    ancestorsShown: state.config.ancestorsShown
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showAncestors: ( ) => {
      dispatch( setConfig( { ancestorsShown: true } ) );
      updateSession( { preferred_taxon_page_ancestors_shown: true } );
    },
    hideAncestors: ( ) => {
      dispatch( setConfig( { ancestorsShown: false } ) );
      updateSession( { preferred_taxon_page_ancestors_shown: false } );
    }
  };
}

const TaxonCrumbsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonCrumbs );

export default TaxonCrumbsContainer;
