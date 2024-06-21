import { connect } from "react-redux";
import LanguageDemoApp from "../components/language_demo_app";
import {
  languageSearch,
  nextPage,
  previousPage,
  toggleVoting,
  submitVotes,
  voteRemainingUp,
  voteRemainingDown,
  viewInIdentify,
  acknowledgeSubmission,
  resetState
} from "../reducers/language_demo_reducer";

const mapStateToProps = state => ( {
  ...state.languageDemo,
  config: state.config
} );

const mapDispatchToProps = dispatch => ( {
  languageSearch: ( searchTerm, searchTaxon ) => {
    dispatch( languageSearch( searchTerm, searchTaxon ) );
  },
  nextPage: options => {
    dispatch( nextPage( options ) );
  },
  previousPage: options => {
    dispatch( previousPage( options ) );
  },
  toggleVoting: ( ) => {
    dispatch( toggleVoting( ) );
  },
  submitVotes: options => {
    dispatch( submitVotes( options ) );
  },
  voteRemainingUp: ( ) => {
    dispatch( voteRemainingUp( ) );
  },
  voteRemainingDown: ( ) => {
    dispatch( voteRemainingDown( ) );
  },
  viewInIdentify: ( ) => {
    dispatch( viewInIdentify( ) );
  },
  acknowledgeSubmission: ( ) => {
    dispatch( acknowledgeSubmission( ) );
  },
  resetState: ( ) => {
    dispatch( resetState( ) );
  }
} );

const LanguageDemoContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( LanguageDemoApp );

export default LanguageDemoContainer;
