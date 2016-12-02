import { connect } from "react-redux";
import { urlForTaxon } from "../../shared/util";
import TaxonCrumbs from "../../shared/components/taxon_crumbs";

function mapStateToProps( state ) {
  const taxon = state.taxon.taxon;
  return {
    taxon,
    ancestors: taxon.ancestors,
    url: urlForTaxon( taxon ),
    currentText: I18n.t( "photo_browser" )
  };
}

function mapDispatchToProps( ) {
  return { };
}

const TaxonCrumbsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxonCrumbs );

export default TaxonCrumbsContainer;
