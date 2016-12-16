import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";

function mapStateToProps( state ) {
  const first = state.observations.first;
  const props = {
    label: I18n.t( "first_observation" ),
    iconClassName: "fa fa-binoculars",
    countIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_observations" ),
    noContent: true,
    className: "FirstObservation"
  };
  if ( !first ) {
    return props;
  }
  return Object.assign( props, {
    noContent: false,
    name: I18n.localize( "date.formats.month_day_year", first.observed_on ),
    imageUrl: first.photos[0] ? first.photos[0].photoUrl( "square" ) : null,
    linkUrl: `/observations/${first.id}`,
    linkText: I18n.t( "view_observation" ),
    url: `/observations/${first.id}`
  } );
}

const FirstObserverContainer = connect(
  mapStateToProps
)( LeaderItem );

export default FirstObserverContainer;
