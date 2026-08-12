import { connect } from "react-redux";
import IdentificationsTab from "../components/identifications_tab";
import IdentificationsTabLegacy from "../components/identifications_tab_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import {
  setIdentificationsQuery,
  nominateIdentification,
  unnominateIdentification,
  voteIdentification,
  unvoteIdentification
} from "../../shared/ducks/taxon";
import { updateCurrentUser } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  const props = {
    response: state.taxon.identifications,
    identificationsQuery: state.taxon.identificationsQuery || {},
    identificationsAvailable: state.taxon.identificationsAvailable,
    config: state.config,
    taxon: state.taxon.taxon
  };
  return props;
}

function mapDispatchToProps( dispatch ) {
  return {
    setIdentificationsQuery: parameters => dispatch( setIdentificationsQuery( parameters ) ),
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    nominateIdentification: ( id, exemplarID ) => dispatch(
      nominateIdentification( id, exemplarID )
    ),
    unnominateIdentification: ( id, exemplarID ) => dispatch(
      unnominateIdentification( id, exemplarID )
    ),
    voteIdentification: ( id, vote ) => { dispatch( voteIdentification( id, vote ) ); },
    unvoteIdentification: id => { dispatch( unvoteIdentification( id ) ); }
  };
}

const IdentificationsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, IdentificationsTab, IdentificationsTabLegacy ) );

export default IdentificationsTabContainer;
