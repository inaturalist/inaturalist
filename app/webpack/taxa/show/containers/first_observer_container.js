import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import { urlForUser } from "../util";

function mapStateToProps( state ) {
  const first = state.observations.first;
  const props = {
    label: I18n.t( "first_observer" ),
    iconClassName: "icon-person",
    countIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_observations" ),
    noContent: true
  };
  if ( !first ) {
    return props;
  }
  return Object.assign( props, {
    noContent: false,
    name: first.user.login,
    imageUrl: first.user.icon_url,
    linkUrl: `/observations/${first.id}`,
    linkText: I18n.t( "view" ),
    extra: I18n.localize( "date.formats.month_day_year", first.observed_on ),
    url: urlForUser( first.user )
  } );
}

const FirstObserverContainer = connect(
  mapStateToProps
)( LeaderItem );

export default FirstObserverContainer;
