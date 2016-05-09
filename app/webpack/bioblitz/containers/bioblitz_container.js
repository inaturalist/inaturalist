import { connect } from "react-redux";
import Bioblitz from "../components/bioblitz";
import actions from "../actions/actions";

const mapStateToProps = ( state ) => state;

const mapDispatchToProps = ( dispatch ) => ( {

  setState: ( attrs ) => {
    dispatch( actions.setState( attrs ) );
  },
  updateState: ( attrs ) => {
    dispatch( actions.updateState( attrs ) );
  }

} );

const BioblitzContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Bioblitz );

export default BioblitzContainer;
