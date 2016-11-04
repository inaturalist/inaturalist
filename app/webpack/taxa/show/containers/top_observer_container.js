import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import { urlForUser } from "../util";

function mapStateToProps( state ) {
  const leader = state.leaders.topObserver;
  const taxon = state.taxon.taxon;
  const props = {
    label: I18n.t( "top_observer" ),
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
  return Object.assign( props, {
    name: leader.user.login,
    noContent: false,
    imageUrl: leader.user.icon_url,
    value: leader.observation_count,
    linkUrl: `/observations?taxon_id=${taxon.id}&view=observers`,
    url: urlForUser( leader.user )
  } );
}

const TopObserverContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopObserverContainer;
