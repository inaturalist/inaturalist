import { connect } from "react-redux";

import Relationships from "../components/relationships";
import {
  deleteRelationship,
  setRelationshipToDelete,
  fetchRelationships,
  setRelationshipFilters
} from "../ducks/relationships";
import { showModal } from "../ducks/delete_relationship_modal";

function mapStateToProps( state ) {
  return {
    relationships: state.relationships.relationships,
    page: state.relationships.page,
    totalRelationships: state.relationships.totalRelationships,
    filters: state.relationships.filters
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    searchUsers: item => { dispatch( setRelationshipFilters( { q: item.id } ) ); },
    filterRelationships: e => {
      dispatch( setRelationshipFilters( { [e.target.name]: e.target.value } ) );
    },
    sortRelationships: e => {
      const sort = e.target.value;
      let params;

      if ( sort === "recently_added" ) {
        params = { order_by: "friendships.id", order: "desc" };
      }

      if ( sort === "earliest_added" ) {
        params = { order_by: "friendships.id", order: "asc" };
      }

      if ( sort === "a_to_z" ) {
        params = { order_by: null, order: "asc" };
      }

      if ( sort === "z_to_a" ) {
        params = { order_by: null, order: "desc" };
      }
      dispatch( setRelationshipFilters( params ) );
    },
    deleteRelationship: id => { dispatch( deleteRelationship( id ) ); },
    showModal: ( id, user ) => {
      dispatch( setRelationshipToDelete( id ) );
      dispatch( showModal( user ) );
    },
    loadPage: page => { dispatch( fetchRelationships( false, page ) ); }
  };
}

const RelationshipsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Relationships );

export default RelationshipsContainer;
