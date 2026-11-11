import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";

function dateFormat( observation ) {
  if ( observation.obscured || observation.private_geojson ) {
    return "date.formats.month_year";
  }
  return "date.formats.month_day_year";
}

function mapStateToProps( state ) {
  const { last } = state.observations;
  const props = {
    label: I18n.t( "last_observation_caps" ),
    labelTooltip: I18n.t( "most_recent_observation_by_date_observed" ),
    iconClassName: "fa fa-binoculars",
    countIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_observations" ),
    noContent: true,
    className: "LastObservation"
  };
  if ( !last ) {
    return props;
  }

  return Object.assign( props, {
    noContent: false,
    name: I18n.localize( dateFormat( last ), last.observed_on ),
    imageUrl: last.photos[0] ? last.photos[0].photoUrl( "square" ) : null,
    linkUrl: `/observations/${last.id}`,
    linkText: I18n.t( "view_observation" ),
    url: `/observations/${last.id}`
  } );
}

const LastObservationContainer = connect(
  mapStateToProps
)( LeaderItem );

export default LastObservationContainer;
