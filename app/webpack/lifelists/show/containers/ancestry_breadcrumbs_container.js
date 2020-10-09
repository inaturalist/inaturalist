import { connect } from "react-redux";
import AncestryBreadcrumbs from "../components/ancestry_breadcrumbs";
import { setDetailsTaxon } from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) )
  };
}

const AncestryBreadcrumbsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AncestryBreadcrumbs );

export default AncestryBreadcrumbsContainer;
