import { connect } from "react-redux";
import DeleteRelationshipModal from "../components/delete_relationship_modal";
import { deleteRelationship } from "../ducks/relationships";
import { hideModal } from "../ducks/delete_relationship_modal";

function mapStateToProps( state ) {
  return {
    show: state.deleteRelationship.show,
    user: state.deleteRelationship.user
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); },
    deleteRelationship: ( ) => {
      dispatch( deleteRelationship( ) );
      dispatch( hideModal( ) );
    }
  };
}

const DeleteRelationshipModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DeleteRelationshipModal );

export default DeleteRelationshipModalContainer;
