import { connect } from "react-redux";
import TaxaTree from "../components/taxa_list";
import {
  setListViewScrollPage, setDetailsTaxon, setDetailsView,
  setListViewOpenTaxon, setListViewRankFilter, setTreeSort
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist,
    detailsTaxon: state.lifelist.detailsTaxon,
    openTaxon: state.lifelist.listViewOpenTaxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setListViewScrollPage: page => dispatch( setListViewScrollPage( page ) ),
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    setListViewOpenTaxon: taxon => dispatch( setListViewOpenTaxon( taxon ) ),
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
