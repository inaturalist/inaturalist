import { connect } from "react-redux";
import LeaderItem from "../components/leader_item";
import { urlForTaxon } from "../util";

function mapStateToProps( state ) {
  const leader = state.leaders.topSpecies;
  const props = {
    label: I18n.t( "top_species" ),
    noContent: true,
    iconClassName: "icon-iconic-unknown",
    valueIconClassName: "fa fa-binoculars",
    linkText: I18n.t( "observations" ),
    name: I18n.t( "no_species_observed" )
  };
  if ( !leader || !leader.taxon ) {
    return props;
  }
  props.noContent = false;
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
    linkUrl: `/observations?taxon_id=${leader.taxon.id}`,
    url: urlForTaxon( leader.taxon )
  } );
}

const TopSpeciesContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopSpeciesContainer;
