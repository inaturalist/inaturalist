import { connect } from "react-redux";
import ActivityCreatePanel from "../components/activity_create_panel";
import ActivityCreatePanelLegacy from "../components/activity_create_panel_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import {
  addID
} from "../ducks/observation";
import { setActiveTab, setNominateOnSubmit, setSuggestedTaxon } from "../ducks/comment_id_panel";
import { updateEditorContent } from "../../shared/ducks/text_editors";
import { confirmResendConfirmation } from "../../../shared/ducks/user_confirmation";

function mapStateToProps( state ) {
  const observation = Object.assign( {}, state.observation, {
    places: state.observationPlaces
  } );
  return {
    observation,
    config: state.config,
    activeTab: state.commentIDPanel.activeTab,
    nominate: state.commentIDPanel.nominate,
    content: state.textEditor.activity,
    suggestedTaxon: state.commentIDPanel.suggestedTaxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    setActiveTab: activeTab => { dispatch( setActiveTab( activeTab ) ); },
    setNominateOnSubmit: nominate => { dispatch( setNominateOnSubmit( nominate ) ); },
    setSuggestedTaxon: taxon => { dispatch( setSuggestedTaxon( taxon ) ); },
    updateEditorContent: ( editor, content ) => dispatch( updateEditorContent( editor, content ) ),
    confirmResendConfirmation: method => dispatch( confirmResendConfirmation( method ) )
  };
}

const ActivityCreatePanelContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, ActivityCreatePanel, ActivityCreatePanelLegacy ) );

export default ActivityCreatePanelContainer;
