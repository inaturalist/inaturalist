import { connect } from "react-redux";
import ActivityCreatePanel from "../components/activity_create_panel";
import {
  addID
} from "../ducks/observation";
import { setActiveTab } from "../ducks/comment_id_panel";
import { updateEditorContent } from "../../shared/ducks/text_editors";

function mapStateToProps( state ) {
  const observation = Object.assign( {}, state.observation, {
    places: state.observationPlaces
  } );
  return {
    observation,
    config: state.config,
    activeTab: state.commentIDPanel.activeTab,
    content: state.textEditor.activity
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    setActiveTab: activeTab => { dispatch( setActiveTab( activeTab ) ); },
    updateEditorContent: ( editor, content ) => dispatch( updateEditorContent( editor, content ) )
  };
}

const ActivityCreatePanelContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ActivityCreatePanel );

export default ActivityCreatePanelContainer;
