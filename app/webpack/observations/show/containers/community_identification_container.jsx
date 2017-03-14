import { connect } from "react-redux";
import CommunityIdentification from "../components/community_identification";
import { addID } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addID: ( taxon ) => { dispatch( addID( taxon ) ); }
  };
}

const CommunityIdentificationContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommunityIdentification );

export default CommunityIdentificationContainer;
