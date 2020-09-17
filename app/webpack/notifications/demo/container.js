import { connect } from "react-redux";
import App from "./components/app";

function mapStateToProps( state ) {
  return {
    apiResponse: state.apiResponse
  };
}

const DemoContainer = connect(
  mapStateToProps
)( App );

export default DemoContainer;
