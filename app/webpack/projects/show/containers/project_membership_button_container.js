import { connect } from "react-redux";
import { updateProjectUser } from "../ducks/project";
import ProjectMembershipButton from "../components/project_membership_button";

const mapStateToProps = state => ( {
  project: state.project,
  projectUser: state.project.currentProjectUser
} );

const mapDispatchToProps = dispatch => ( {
  updateProjectUser: projectUser => dispatch( updateProjectUser( projectUser ) )
} );

const ProjectMembershipButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ProjectMembershipButton );

export default ProjectMembershipButtonContainer;
