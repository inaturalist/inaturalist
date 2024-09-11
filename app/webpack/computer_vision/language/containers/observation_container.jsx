import { connect } from "react-redux";
import Observation from "../components/observation";
import { voteOnPhoto } from "../reducers/language_demo_reducer";

const mapStateToProps = state => ( {
  votes: state.languageDemo.votes,
  votingEnabled: state.languageDemo.votingEnabled,
  config: state.config
} );

const mapDispatchToProps = dispatch => ( {
  voteOnPhoto: ( photoID, vote ) => {
    dispatch( voteOnPhoto( photoID, vote ) );
  }
} );

const PhotoContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Observation );

export default PhotoContainer;
