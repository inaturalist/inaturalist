import React from "react";
import _ from "lodash";
import * as d3 from "d3";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";

const PieChartForIconicTaxonCounts = ( {
  data,
  user,
  year,
  margin,
  donutWidth,
  labelForDatum,
  urlPrefix
} ) => {
  const nameForPieLabel = name => _.truncate( _.capitalize( name ), { length: 15 } );
  return (
    <PieChart
      data={[
        {
          label: nameForPieLabel( I18n.t( "unknown" ) ),
          fullLabel: _.capitalize( I18n.t( "unknown" ) ),
          value: data.Unknown,
          color: COLORS.iconic.Unknown,
          iconicTaxonName: "Unknown"
        },
        {
          label: nameForPieLabel( I18n.t( "protozoans" ) ),
          fullLabel: _.capitalize( I18n.t( "protozoans" ) ),
          value: data.Protozoa,
          color: COLORS.iconic.Protozoa,
          iconicTaxonName: "Protozoa"
        },
        {
          label: nameForPieLabel( I18n.t( "fungi", { count: 2 } ) ),
          fullLabel: _.capitalize( I18n.t( "fungi", { count: 2 } ) ),
          value: data.Fungi,
          color: COLORS.iconic.Fungi,
          iconicTaxonName: "Fungi"
        },
        {
          label: nameForPieLabel( I18n.t( "plants" ) ),
          fullLabel: _.capitalize( I18n.t( "plants" ) ),
          value: data.Plantae,
          color: COLORS.inatGreenLight,
          iconicTaxonName: "Plantae"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.chromista" ) ),
          fullLabel: _.capitalize( I18n.t( "all_taxa.chromista" ) ),
          value: data.Chromista,
          color: COLORS.iconic.Chromista,
          iconicTaxonName: "Chromista"
        },
        {
          label: nameForPieLabel( I18n.t( "mollusks" ) ),
          fullLabel: _.capitalize( I18n.t( "mollusks" ) ),
          value: data.Mollusca,
          color: COLORS.iconic.Mollusca,
          iconicTaxonName: "Mollusca"
        },
        {
          label: nameForPieLabel( I18n.t( "insects" ) ),
          fullLabel: _.capitalize( I18n.t( "insects" ) ),
          value: data.Insecta,
          color: d3.color( COLORS.iconic.Insecta ).brighter( ),
          iconicTaxonName: "Insecta"
        },
        {
          label: nameForPieLabel( I18n.t( "arachnids" ) ),
          fullLabel: _.capitalize( I18n.t( "arachnids" ) ),
          value: data.Arachnida,
          color: d3.color( COLORS.iconic.Arachnida ).brighter( ).brighter( ),
          iconicTaxonName: "Arachnida"
        },
        {
          label: nameForPieLabel( I18n.t( "ray_finned_fishes" ) ),
          fullLabel: _.capitalize( I18n.t( "ray_finned_fishes" ) ),
          value: data.Actinopterygii,
          color: d3.color( COLORS.iconic.Actinopterygii ).darker( 1 ),
          iconicTaxonName: "Actinopterygii"
        },
        {
          label: nameForPieLabel( I18n.t( "amphibians" ) ),
          fullLabel: _.capitalize( I18n.t( "amphibians" ) ),
          value: data.Amphibia,
          color: d3.color( COLORS.iconic.Amphibia ).darker( 0.5 ),
          iconicTaxonName: "Amphibia"
        },
        {
          label: nameForPieLabel( I18n.t( "reptiles" ) ),
          fullLabel: _.capitalize( I18n.t( "reptiles" ) ),
          value: data.Reptilia,
          color: d3.color( COLORS.iconic.Reptilia ),
          iconicTaxonName: "Reptilia"
        },
        {
          label: nameForPieLabel( I18n.t( "birds" ) ),
          fullLabel: _.capitalize( I18n.t( "birds" ) ),
          value: data.Aves,
          color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ),
          iconicTaxonName: "Aves"
        },
        {
          label: nameForPieLabel( I18n.t( "mammals" ) ),
          fullLabel: _.capitalize( I18n.t( "mammals" ) ),
          value: data.Mammalia,
          color: d3.color( COLORS.iconic.Aves ).brighter( 1 ),
          iconicTaxonName: "Mammalia"
        },
        {
          label: nameForPieLabel( I18n.t( "other_animals" ) ),
          fullLabel: _.capitalize( I18n.t( "other_animals" ) ),
          value: data.Animalia,
          color: d3.color( COLORS.iconic.Animalia ),
          iconicTaxonName: "Animalia"
        }
      ]}
      legendColumns={ 2 }
      legendColumnWidth={ 120 }
      margin={ margin }
      labelForDatum={ labelForDatum }
      donutWidth={ donutWidth }
      onClick={ d => {
        let url = urlPrefix || `/observations?place_id=any&d1=${year}-01-01&d2=${year + 1}-01-01`;
        if ( user ) {
          url += `&user_id=${user.login}`;
        }
        const iconicTaxonIDs = _.reduce( inaturalist.ICONIC_TAXA, ( r, v, k ) => {
          Object.assign( r, { [v.name]: k } );
          return r;
        }, {} );
        const iconicTaxonID = iconicTaxonIDs[d.data.iconicTaxonName];
        if ( d.data.iconicTaxonName === "Animalia" ) {
          const iconicAnimalIDs = [
            iconicTaxonIDs.Mollusca,
            iconicTaxonIDs.Arachnida,
            iconicTaxonIDs.Insecta,
            iconicTaxonIDs.Actinopterygii,
            iconicTaxonIDs.Amphibia,
            iconicTaxonIDs.Reptilia,
            iconicTaxonIDs.Aves,
            iconicTaxonIDs.Mammalia
          ];
          url += `&taxon_id=${iconicTaxonID}&without_taxon_id=${iconicAnimalIDs.join( "," )}`;
        } else if ( iconicTaxonID ) {
          url += `&taxon_id=${iconicTaxonID}`;
        }
        window.open( url, "_blank" );
      } }
    />
  );
};

PieChartForIconicTaxonCounts.propTypes = {
  data: PropTypes.object,
  year: PropTypes.number,
  user: PropTypes.object,
  margin: PropTypes.object,
  labelForDatum: PropTypes.func,
  innerRadius: PropTypes.number,
  donutWidth: PropTypes.number,
  urlPrefix: PropTypes.string
};

export default PieChartForIconicTaxonCounts;
