import { connect } from "react-redux";
import HiddenContentMessage from "../components/hidden_content_message";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

const HiddenContentMessageContainer = connect(
  mapStateToProps
)( HiddenContentMessage );

export default HiddenContentMessageContainer;
