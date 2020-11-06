import { connect } from "react-redux";

import Relationships from "../components/relationships";
import { updateFilters, sortRelationships } from "../ducks/relationships";

function mapStateToProps( state ) {
  return {
    // empty array in case page loads before relationships fetched
    relationships: state.relationships.relationships || [],
    profile: state.profile,
    // spread filteredRelationships to refresh props when sorting results
    filteredRelationships:
      state.relationships.relationships
        ? [...state.relationships.filteredRelationships]
        : []
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateFilters: e => { dispatch( updateFilters( e ) ); },
    sortRelationships: e => { dispatch( sortRelationships( e ) ); }
  };
}

const RelationshipsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Relationships );

export default RelationshipsContainer;
