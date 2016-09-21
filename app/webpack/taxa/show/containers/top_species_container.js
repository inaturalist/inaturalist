import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";

function mapStateToProps( state ) {
  const leader = state.leaders.topSpecies;
  const props = {
    label: I18n.t( "top_species" ),
    iconClassName: "icon-iconic-unknown",
    valueIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "observations" ),
    name: I18n.t( "unknown" )
  };
  if ( !leader || !leader.taxon ) {
    return props;
  }
  let imageUrl;
  if ( leader.taxon.defaultPhoto ) {
    imageUrl = leader.taxon.defaultPhoto.photoUrl( "small" );
  } else {
    props.iconClassName = `icon icon-iconic-${leader.taxon.iconicTaxonName( ).toLowerCase( )}`;
  }
  return Object.assign( props, {
    name: leader.taxon.preferred_common_name || leader.taxon.name,
    imageUrl,
    value: leader.count,
    linkUrl: `/observations?taxon_id=${leader.taxon.id}`
  } );
}

const TopSpeciesContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopSpeciesContainer;
