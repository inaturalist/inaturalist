import { connect } from "react-redux";
import IdentificationForm from "../components/identification_form";
import {
  postIdentification,
  fetchCurrentObservation,
  loadingDiscussionItem
} from "../actions";

// ownProps contains data passed in through the "tag", so in this case
// <IdentificationFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitIdentification: ( identification ) => {
      dispatch( loadingDiscussionItem( ) );
      dispatch( postIdentification( identification ) )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ownProps.observation ) );
        } );
    }
  };
}

const IdentificationFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationForm );

export default IdentificationFormContainer;
