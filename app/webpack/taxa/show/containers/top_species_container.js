import { connect } from "react-redux";
import { stringify } from "querystring";
import LeaderItem from "../components/leader_item";
import { urlForTaxon, defaultObservationParams } from "../../shared/util";

function mapStateToProps( state ) {
  const leader = Object.assign( {}, state.leaders.topSpecies );
  const props = {
    label: I18n.t( "top_species" ),
    noContent: true,
    iconClassName: "icon-iconic-unknown",
    linkText: I18n.t( "observations" ),
    name: I18n.t( "no_species_observed" ),
    className: "TopSpecies"
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
  const urlParams = defaultObservationParams( state );
  urlParams.taxon_id = leader.taxon.id;
  return Object.assign( props, {
    name: leader.taxon.preferred_common_name || leader.taxon.name,
    imageUrl,
    linkText: I18n.t( "x_observations_", {
      count: leader.count === 1 ? leader.count : I18n.toNumber( leader.count, { precision: 0 } )
    } ),
    linkUrl: `/observations?${stringify( urlParams )}`,
    url: urlForTaxon( leader.taxon )
  } );
}

const TopSpeciesContainer = connect(
  mapStateToProps
)( LeaderItem );

export default TopSpeciesContainer;
