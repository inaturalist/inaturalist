import { connect } from "react-redux";
import FlashMessages from "../components/flash_messages";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

const FlashMessagesContainer = connect(
  mapStateToProps
)( FlashMessages );

export default FlashMessagesContainer;
