import { connect } from "react-redux";
import TaxaTree from "../components/taxa_list";
import {
  setListViewScrollPage, setDetailsTaxon, setDetailsView,
  setListViewRankFilter, setTreeSort
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist,
    detailsTaxon: state.lifelist.detailsTaxon,
    searchTaxon: state.lifelist.searchTaxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setListViewScrollPage: page => dispatch( setListViewScrollPage( page ) ),
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    setListViewRankFilter: value => dispatch( setListViewRankFilter( value ) ),
    setTreeSort: value => dispatch( setTreeSort( value ) ),
    setDetailsView: view => dispatch( setDetailsView( view ) )
  };
}

const TaxaListContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TaxaTree );

export default TaxaListContainer;
