import { connect } from "react-redux";
import { stringify } from "querystring";
import LeaderItem from "../components/leader_item";
import { defaultObservationParams } from "../../shared/util";


function mapStateToProps( state ) {
  let count = 0;
  const props = {
    iconClassName: `icon icon-iconic-${state.taxon.taxon.iconicTaxonName( ).toLowerCase( )}`,
    className: "NumSpecies",
    label: I18n.t( "total_species_observed" ),
    name: I18n.t( "x_of_y", { x: "?", y: state.taxon.taxon.complete_species_count } ),
    linkText: I18n.t( "view_all" ),
    noContent: true
  };
  const baseParams = {
    view: "species",
    rank: "species,subspecies,variety",
    place_id: "any",
    verifiable: true
  };
  if ( state.config.currentUser && state.config.currentUser.login ) {
    props.extraLinkText = I18n.t( "view_yours" );
    props.extraLinkTextShort = I18n.t( "yours" );
    const params = Object.assign( { }, defaultObservationParams( state ), baseParams, {
      user_id: state.config.currentUser.login
    } );
    props.extraLinkUrl = `/observations?${stringify( params )}`;
  }
  if ( state.taxon.species ) {
    count = state.taxon.species.total_results;
  }
  if ( count === null || count === undefined ) {
    return props;
  }
  const linkParams = Object.assign( { }, defaultObservationParams( state ), baseParams );
  return Object.assign( props, {
    name: I18n.t( "x_of_y", {
      x: I18n.toNumber( count, { precision: 0 } ),
      y: I18n.toNumber( state.taxon.taxon.complete_species_count, { precision: 0 } )
    } ),
    linkUrl: `/observations?${stringify( linkParams )}`,
    noContent: false
  } );
}

const NumSpeciesContainer = connect(
  mapStateToProps
)( LeaderItem );

export default NumSpeciesContainer;
