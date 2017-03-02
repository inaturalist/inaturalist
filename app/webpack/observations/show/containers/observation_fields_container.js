import { connect } from "react-redux";
import ObservationFields from "../components/observation_fields";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

const ObservationFieldsContainer = connect(
  mapStateToProps
)( ObservationFields );

export default ObservationFieldsContainer;
