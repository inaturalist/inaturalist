import { connect } from "react-redux";
import TaxaTree from "../components/taxa_tree";
import { toggleTaxon, setDetailsTaxon } from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    taxa: state.lifelist.taxa,
    children: state.lifelist.children,
    openTaxa: state.lifelist.openTaxa,
    showPhotos: state.lifelist.showPhotos
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    toggleTaxon: ( taxonID, options ) => dispatch( toggleTaxon( taxonID, options ) ),
    setDetailsTaxon: taxonID => dispatch( setDetailsTaxon( taxonID ) )
  };
}

const TreeTaxaContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxaTree );

export default TreeTaxaContainer;
