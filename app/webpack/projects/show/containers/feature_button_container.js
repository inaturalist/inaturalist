import { connect } from "react-redux";
import FeatureButton from "../components/feature_button";
import { feature, unfeature } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    feature: options => { dispatch( feature( options ) ); },
    unfeature: ( ) => { dispatch( unfeature( ) ); }
  };
}

const FeatureButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FeatureButton );

export default FeatureButtonContainer;
