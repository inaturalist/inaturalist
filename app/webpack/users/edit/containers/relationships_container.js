import { connect } from "react-redux";

import Relationships from "../components/relationships";
import { updateFilters } from "../ducks/relationships";

function mapStateToProps( state ) {
  return {
    // empty array in case page loads before relationships fetched
    relationships: state.relationships.relationships || [],
    profile: state.profile,
    filteredRelationships: state.relationships.filteredRelationships || []
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateFilters: e => { dispatch( updateFilters( e ) ); }
    // sortRelationships: PropTypes.func
  };
}

const RelationshipsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Relationships );

export default RelationshipsContainer;
