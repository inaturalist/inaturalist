import { connect } from "react-redux";
import TreeView from "../components/tree_view";
import {
  setNavView, setDetailsView, zoomToTaxon, setDetailsTaxon, setTreeSort,
  setListViewRankFilter, setTreeMode, setTreeIndent, setListShowAncestry
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setNavView: view => dispatch( setNavView( view ) ),
    setDetailsView: view => dispatch( setDetailsView( view ) ),
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) ),
    setTreeSort: value => dispatch( setTreeSort( value ) ),
    setListViewRankFilter: value => dispatch( setListViewRankFilter( value ) ),
    setTreeMode: mode => dispatch( setTreeMode( mode ) ),
    setTreeIndent: indent => dispatch( setTreeIndent( indent ) ),
    setListShowAncestry: show => dispatch( setListShowAncestry( show ) )
  };
}

const TreeViewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( TreeView );

export default TreeViewContainer;
