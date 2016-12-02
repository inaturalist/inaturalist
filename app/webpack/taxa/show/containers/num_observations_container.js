import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import _ from "lodash";

function mapStateToProps( state ) {
  const count = state.observations.total;
  const taxon = state.taxon.taxon;
  const props = {
    iconClassName: "fa fa-binoculars",
    className: "NumObservations",
    label: I18n.t( "total_observations" ),
    name: 0,
    linkText: _.startCase( I18n.t( "view_all" ) ),
    noContent: true
  };
  if ( !count ) {
    return props;
  }
  return Object.assign( props, {
    name: I18n.toNumber( count, { precision: 0 } ),
    linkUrl: `/observations?taxon_id=${taxon.id}`,
    noContent: false
  } );
}

const NumObservationsContainer = connect(
  mapStateToProps
)( LeaderItem );

export default NumObservationsContainer;
