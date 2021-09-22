import { connect } from "react-redux";
import { stringify } from "querystring";
import LeaderItem from "../components/leader_item";
import { urlForUser, defaultObservationParams } from "../../shared/util";

function mapStateToProps( state ) {
  const leader = state.leaders.topObserver;
  const props = {
    label: I18n.t( "top_observer_caps" ),
    noContent: true,
    iconClassName: "icon-person",
    valueIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_observations" ),
    className: "TopObserver"
  };
  if ( !leader || !leader.user ) {
    return props;
  }
  const urlParams = defaultObservationParams( state );
  urlParams.view = "observers";
  return Object.assign( props, {
    name: leader.user.login,
    noContent: false,
    imageUrl: leader.user.icon_url,
    value: leader.observation_count,
    linkUrl: `/observations?${stringify( urlParams )}`,
    url: urlForUser( leader.user )
  } );
}

const TopObserverContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopObserverContainer;
