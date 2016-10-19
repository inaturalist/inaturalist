import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import { urlForUser } from "../util";

function mapStateToProps( state ) {
  const leader = state.leaders.topIdentifier;
  const taxon = state.taxon.taxon;
  const props = {
    label: I18n.t( "top_identifier" ),
    iconClassName: "icon-person",
    valueIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "leaderboard" ),
    name: I18n.t( "no_identifications" ),
    noContent: true
  };
  if ( !leader || !leader.user ) {
    return props;
  }
  return Object.assign( props, {
    name: leader.user.login,
    imageUrl: leader.user.icon_url,
    value: leader.count,
    linkUrl: `/observations?taxon_id=${taxon.id}&view=identifiers`,
    url: urlForUser( leader.user ),
    noContent: false
  } );
}

const TopIdentifierContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopIdentifierContainer;
