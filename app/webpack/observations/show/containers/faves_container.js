import { connect } from "react-redux";
import Faves from "../components/faves";
import { fave, unfave } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fave: ( id ) => { dispatch( fave( id ) ); },
    unfave: ( id ) => { dispatch( unfave( id ) ); }
  };
}

const FavesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Faves );

export default FavesContainer;
