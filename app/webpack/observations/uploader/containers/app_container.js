import { connect } from "react-redux";
import App from "../components/app";

const mapStateToProps = ( state ) => (
  { empty: ( state.dragDropZone.obsCards === 0 ) }
);

const AppContainer = connect(
  mapStateToProps
)( App );

export default AppContainer;
