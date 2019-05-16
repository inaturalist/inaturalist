import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import * as d3 from "d3";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";

const PieChartForIconicTaxonCounts = ( {
  data,
  user,
  site,
  year,
  margin,
  donutWidth,
  labelForDatum,
  urlPrefix
} ) => {
  const nameForPieLabel = name => _.truncate( name, { length: 15 } );
  return (
    <PieChart
      data={[
        {
          label: nameForPieLabel( I18n.t( "unknown" ) ),
          fullLabel: I18n.t( "unknown" ),
          value: data.Unknown,
          color: COLORS.iconic.Unknown,
          iconicTaxonName: "Unknown"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.protozoans" ) ),
          fullLabel: I18n.t( "all_taxa.protozoans" ),
          value: data.Protozoa,
          color: COLORS.iconic.Protozoa,
          iconicTaxonName: "Protozoa"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.fungi" ) ),
          fullLabel: I18n.t( "all_taxa.fungi" ),
          value: data.Fungi,
          color: COLORS.iconic.Fungi,
          iconicTaxonName: "Fungi"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.plants" ) ),
          fullLabel: I18n.t( "all_taxa.plants" ),
          value: data.Plantae,
          color: COLORS.inatGreenLight,
          iconicTaxonName: "Plantae"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.chromista" ) ),
          fullLabel: I18n.t( "all_taxa.chromista" ),
          value: data.Chromista,
          color: COLORS.iconic.Chromista,
          iconicTaxonName: "Chromista"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.mollusks" ) ),
          fullLabel: I18n.t( "all_taxa.mollusks" ),
          value: data.Mollusca,
          color: COLORS.iconic.Mollusca,
          iconicTaxonName: "Mollusca"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.insects" ) ),
          fullLabel: I18n.t( "all_taxa.insects" ),
          value: data.Insecta,
          color: d3.color( COLORS.iconic.Insecta ).brighter( ),
          iconicTaxonName: "Insecta"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.arachnids" ) ),
          fullLabel: I18n.t( "all_taxa.arachnids" ),
          value: data.Arachnida,
          color: d3.color( COLORS.iconic.Arachnida ).brighter( ).brighter( ),
          iconicTaxonName: "Arachnida"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.ray_finned_fishes" ) ),
          fullLabel: I18n.t( "all_taxa.ray_finned_fishes" ),
          value: data.Actinopterygii,
          color: d3.color( COLORS.iconic.Actinopterygii ).darker( 1 ),
          iconicTaxonName: "Actinopterygii"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.amphibians" ) ),
          fullLabel: I18n.t( "all_taxa.amphibians" ),
          value: data.Amphibia,
          color: d3.color( COLORS.iconic.Amphibia ).darker( 0.5 ),
          iconicTaxonName: "Amphibia"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.reptiles" ) ),
          fullLabel: I18n.t( "all_taxa.reptiles" ),
          value: data.Reptilia,
          color: d3.color( COLORS.iconic.Reptilia ),
          iconicTaxonName: "Reptilia"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.birds" ) ),
          fullLabel: I18n.t( "all_taxa.birds" ),
          value: data.Aves,
          color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ),
          iconicTaxonName: "Aves"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.mammals" ) ),
          fullLabel: I18n.t( "all_taxa.mammals" ),
          value: data.Mammalia,
          color: d3.color( COLORS.iconic.Aves ).brighter( 1 ),
          iconicTaxonName: "Mammalia"
        },
        {
          label: nameForPieLabel( I18n.t( "all_taxa.other_animals" ) ),
          fullLabel: I18n.t( "all_taxa.other_animals" ),
          value: data.Animalia,
          color: d3.color( COLORS.iconic.Animalia ),
          iconicTaxonName: "Animalia"
        }
      ]}
      legendColumns={2}
      legendColumnWidth={120}
      margin={margin}
      labelForDatum={labelForDatum}
      donutWidth={donutWidth}
      onClick={d => {
        let url = urlPrefix || `/observations?d1=${year}-01-01&d2=${year}-12-31`;
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
        if ( site && site.id !== 1 ) {
          if ( site.place_id ) {
            url += `&place_id=${site.place_id}`;
          } else {
            url += `&site_id=${site.id}`;
          }
        } else {
          url += "&place_id=any";
        }
        window.open( url, "_blank" );
      }}
    />
  );
};

PieChartForIconicTaxonCounts.propTypes = {
  data: PropTypes.object,
  year: PropTypes.number,
  user: PropTypes.object,
  site: PropTypes.object,
  margin: PropTypes.object,
  labelForDatum: PropTypes.func,
  donutWidth: PropTypes.number,
  urlPrefix: PropTypes.string
};

export default PieChartForIconicTaxonCounts;
