import { connect } from "react-redux";
import { updateCurrentUser } from "../../../shared/ducks/config";
import BeforeEventTab from "../components/before_event_tab";
import { setAttributes, setSelectedTab } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setAttributes: attrs => dispatch( setAttributes( attrs ) ),
    setSelectedTab: tab => dispatch( setSelectedTab( tab ) ),
    updateCurrentUser: user => dispatch( updateCurrentUser( user ) )
  };
}

const BeforeEventTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( BeforeEventTab );

export default BeforeEventTabContainer;
