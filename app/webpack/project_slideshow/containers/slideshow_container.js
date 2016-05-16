import { connect } from "react-redux";
import Slideshow from "../components/slideshow";
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

const SlideshowContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Slideshow );

export default SlideshowContainer;
