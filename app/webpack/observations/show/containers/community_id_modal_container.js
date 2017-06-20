import { connect } from "react-redux";
import CommunityIDModal from "../components/community_id_modal";
import { setCommunityIDModalState } from "../ducks/community_id_modal";

function mapStateToProps( state ) {
  return {
    show: state.communityIDModal.show,
    observation: state.observation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setCommunityIDModalState: ( key, value ) => {
      dispatch( setCommunityIDModalState( key, value ) );
    }
  };
}

const CommunityIDModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIDModal );

export default CommunityIDModalContainer;
