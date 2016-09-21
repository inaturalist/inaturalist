import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";

function mapStateToProps( state ) {
  const first = state.observations.first;
  const props = {
    label: I18n.t( "first_observer" ),
    iconClassName: "fa fa-user",
    countIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" )
  };
  if ( !first ) {
    return props;
  }
  return Object.assign( props, {
    name: first.user.login,
    imageUrl: first.user.icon_url,
    linkUrl: `/observations/${first.id}`,
    linkText: I18n.t( "view" ),
    extra: I18n.localize( "date.formats.month_day_year", first.observed_on )
  } );
}

const FirstObserverContainer = connect(
  mapStateToProps
)( LeaderItem );

export default FirstObserverContainer;
