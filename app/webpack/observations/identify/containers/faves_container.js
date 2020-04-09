import { connect } from "react-redux";
import Faves from "../../show/components/faves";
import { fave, unfave } from "../actions";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    config: state.config,
    faveText: I18n.t( "add_to_favorites" ),
    hideOtherUsers: true
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fave: id => dispatch( fave( id ) ),
    unfave: id => dispatch( unfave( id ) )
  };
}

const FavesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Faves );

export default FavesContainer;
