import { connect } from "react-redux";
import { setAttributes, setSelectedTab } from "../ducks/project";
import InsufficientRequirements from "../components/insufficient_requirements";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setAttributes: attrs => dispatch( setAttributes( attrs ) ),
    setSelectedTab: tab => dispatch( setSelectedTab( tab ) )
  };
}

const InsufficientRequirementsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( InsufficientRequirements );


export default InsufficientRequirementsContainer;
