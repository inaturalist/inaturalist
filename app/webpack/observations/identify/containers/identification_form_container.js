import { connect } from "react-redux";
import IdentificationForm from "../components/identification_form";
import {
  postIdentification,
  fetchCurrentObservation,
  loadingDiscussionItem,
  fetchObservationsStats,
  fetchIdentifiers,
  stopLoadingDiscussionItem,
  showAlert,
  addIdentification
} from "../actions";

// ownProps contains data passed in through the "tag", so in this case
// <IdentificationFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation,
    currentUser: state.config.currentUser
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitIdentification: ( identification, options = {} ) => {
      dispatch( loadingDiscussionItem( ) );
      const boundPostIdentification = ( ) => {
        dispatch( postIdentification( identification ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ownProps.observation ) );
          dispatch( fetchObservationsStats( ) );
          dispatch( fetchIdentifiers( ) );
        } );
      };
      if ( options.confirmationText ) {
        dispatch( showAlert( options.confirmationText, {
          title: I18n.t( "heads_up" ),
          onConfirm: boundPostIdentification,
          onCancel: ( ) => {
            dispatch( stopLoadingDiscussionItem( ) );
            dispatch( addIdentification( ) );
          }
        } ) );
      } else {
        boundPostIdentification( );
      }
    }
  };
}

const IdentificationFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationForm );

export default IdentificationFormContainer;
