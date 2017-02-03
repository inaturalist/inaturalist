import { connect } from "react-redux";
import MoreFromUser from "../components/more_from_user";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observations: state.otherObservations.moreFromUser
  };
}

const MoreFromUserContainer = connect(
  mapStateToProps
)( MoreFromUser );

export default MoreFromUserContainer;
