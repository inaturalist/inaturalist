import { connect } from "react-redux";
import IdentificationForm from "../components/identification_form";
import { postIdentification, fetchCurrentObservation } from "../actions";

// ownProps contains data passed in through the "tag", so in this case
// <IdentificationFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onSubmitIdentification: ( identification ) => {
      dispatch( postIdentification( identification ) )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    }
  };
}

const IdentificationFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationForm );

export default IdentificationFormContainer;
