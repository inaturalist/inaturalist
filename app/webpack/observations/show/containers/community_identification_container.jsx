import { connect } from "react-redux";
import CommunityIdentification from "../components/community_identification";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return { };
}

const CommunityIdentificationContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIdentification );

export default CommunityIdentificationContainer;
