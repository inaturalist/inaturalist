import { connect } from "react-redux";
import { stringify } from "querystring";
import _ from "lodash";
import LeaderItem from "../components/leader_item";
import { defaultObservationParams } from "../../shared/util";


function mapStateToProps( state ) {
  const count = state.observations.total;
  const props = {
    iconClassName: "fa fa-binoculars",
    className: "NumObservations",
    label: I18n.t( "total_observations" ),
    name: 0,
    linkText: I18n.t( "view_all" ),
    noContent: true
  };
  if ( state.config.currentUser && state.config.currentUser.login ) {
    props.extraLinkText = I18n.t( "view_yours" );
    props.extraLinkTextShort = I18n.t( "yours" );
    const params = Object.assign( { }, defaultObservationParams( state ),
      { user_id: state.config.currentUser.login } );
    params.verifiable = "any";
    props.extraLinkUrl = `/observations?${stringify( params )}`;
  }
  if ( !count ) {
    return props;
  }
  return Object.assign( props, {
    name: I18n.toNumber( count, { precision: 0 } ),
    linkUrl: `/observations?${stringify( defaultObservationParams( state ) )}`,
    noContent: false
  } );
}

const NumObservationsContainer = connect(
  mapStateToProps
)( LeaderItem );

export default NumObservationsContainer;
