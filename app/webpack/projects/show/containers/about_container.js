import { connect } from "react-redux";
import About from "../components/about";
import { setSelectedTab, feature, unfeature } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setSelectedTab: tab => { dispatch( setSelectedTab( tab ) ); },
    feature: options => { dispatch( feature( options ) ); },
    unfeature: ( ) => { dispatch( unfeature( ) ); }
  };
}

const AboutContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( About );

export default AboutContainer;
