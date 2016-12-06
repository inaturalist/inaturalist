import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import { urlForUser } from "../../shared/util";
import { stringify } from "querystring";
import { defaultObservationParams } from "../../shared/util";

function mapStateToProps( state ) {
  const leader = state.leaders.topIdentifier;
  const props = {
    label: I18n.t( "top_identifier" ),
    iconClassName: "icon-person",
    valueIconClassName: "icon-identification",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_identifications" ),
    noContent: true,
    className: "TopIdentifier"
  };
  if ( !leader || !leader.user ) {
    return props;
  }
  const urlParams = defaultObservationParams( state );
  urlParams.view = "identifiers";
  return Object.assign( props, {
    name: leader.user.login,
    imageUrl: leader.user.icon_url,
    value: leader.count,
    linkUrl: `/observations?${stringify( urlParams )}`,
    url: urlForUser( leader.user ),
    noContent: false
  } );
}

const TopIdentifierContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopIdentifierContainer;
