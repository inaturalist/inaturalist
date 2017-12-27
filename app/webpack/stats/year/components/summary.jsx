import React from "react";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";
import * as d3 from "d3";

const Summary = ( {
  data,
  user,
  year
} ) => {
  const pieMargin = { top: 0, bottom: 120, left: 0, right: 0 };
  const donutWidth = 20;
  const nameForPieLabel = name => _.truncate( _.capitalize( name ), { length: 15 } );
  return (
    <Row className="Summary">
      <Col xs={ 4 }>
        { data.observations.quality_grade_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={ { __html: I18n.t( "x_observations_html", {
                count: I18n.toNumber(
                  ( data.observations.quality_grade_counts.research || 0 ) + ( data.observations.quality_grade_counts.needs_id || 0 ),
                  { precision: 0 }
                )
              } ) } }
            >
            </div>
            <PieChart
              data={[
                {
                  label: _.upperFirst( I18n.t( "casual" ) ),
                  value: data.observations.quality_grade_counts.casual,
                  color: "#aaaaaa",
                  qualityGrade: "casual"
                },
                {
                  label: _.upperFirst( I18n.t( "needs_id" ) ),
                  value: data.observations.quality_grade_counts.needs_id,
                  color: COLORS.needsIdYellow,
                  qualityGrade: "needs_id"
                },
                {
                  label: _.upperFirst( I18n.t( "research" ) ),
                  value: data.observations.quality_grade_counts.research,
                  color: COLORS.inatGreenLight,
                  qualityGrade: "research"
                }
              ]}
              legendColumnWidth={ 50 }
              margin={ pieMargin }
              donutWidth={ donutWidth }
              onClick={ d => {
                let url = `/observations?quality_grade=${d.data.qualityGrade}&${year}-01-01&d2=${year + 1}-01-01`;
                if ( user ) {
                  url += `&user_id=${user.login}`;
                }
                window.open( url, "_blank" );
              } }
            />
          </div>
        ) : null }
      </Col>
      <Col xs={ 4 }>
        { data.taxa && data.taxa.iconic_taxa_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={ { __html: I18n.t( "x_species_html", {
                count: I18n.toNumber(
                  (
                    data.taxa.leaf_taxa_count
                  ),
                  { precision: 0 }
                )
              } ) } }
            />
            <PieChart
              data={[
                {
                  label: nameForPieLabel( I18n.t( "unknown" ) ),
                  fullLabel: _.capitalize( I18n.t( "unknown" ) ),
                  value: data.taxa.iconic_taxa_counts.Unknown,
                  color: COLORS.iconic.Unknown,
                  iconicTaxonName: "Unknown"
                },
                {
                  label: nameForPieLabel( I18n.t( "protozoans" ) ),
                  fullLabel: _.capitalize( I18n.t( "protozoans" ) ),
                  value: data.taxa.iconic_taxa_counts.Protozoa,
                  color: COLORS.iconic.Protozoa,
                  iconicTaxonName: "Protozoa"
                },
                {
                  label: nameForPieLabel( I18n.t( "fungi", { count: 2 } ) ),
                  fullLabel: _.capitalize( I18n.t( "fungi", { count: 2 } ) ),
                  value: data.taxa.iconic_taxa_counts.Fungi,
                  color: COLORS.iconic.Fungi,
                  iconicTaxonName: "Fungi"
                },
                {
                  label: nameForPieLabel( I18n.t( "plants" ) ),
                  fullLabel: _.capitalize( I18n.t( "plants" ) ),
                  value: data.taxa.iconic_taxa_counts.Plantae,
                  color: COLORS.inatGreenLight,
                  iconicTaxonName: "Plantae"
                },
                {
                  label: nameForPieLabel( I18n.t( "all_taxa.chromista" ) ),
                  fullLabel: _.capitalize( I18n.t( "all_taxa.chromista" ) ),
                  value: data.taxa.iconic_taxa_counts.Chromista,
                  color: COLORS.iconic.Chromista,
                  iconicTaxonName: "Chromista"
                },
                {
                  label: nameForPieLabel( I18n.t( "mollusks" ) ),
                  fullLabel: _.capitalize( I18n.t( "mollusks" ) ),
                  value: data.taxa.iconic_taxa_counts.Mollusca,
                  color: COLORS.iconic.Mollusca,
                  iconicTaxonName: "Mollusca"
                },
                {
                  label: nameForPieLabel( I18n.t( "insects" ) ),
                  fullLabel: _.capitalize( I18n.t( "insects" ) ),
                  value: data.taxa.iconic_taxa_counts.Insecta,
                  color: d3.color( COLORS.iconic.Insecta ).brighter( ),
                  iconicTaxonName: "Insecta"
                },
                {
                  label: nameForPieLabel( I18n.t( "arachnids" ) ),
                  fullLabel: _.capitalize( I18n.t( "arachnids" ) ),
                  value: data.taxa.iconic_taxa_counts.Arachnida,
                  color: d3.color( COLORS.iconic.Arachnida ).brighter( ).brighter( ),
                  iconicTaxonName: "Arachnida"
                },
                {
                  label: nameForPieLabel( I18n.t( "ray_finned_fishes" ) ),
                  fullLabel: _.capitalize( I18n.t( "ray_finned_fishes" ) ),
                  value: data.taxa.iconic_taxa_counts.Actinopterygii,
                  color: d3.color( COLORS.iconic.Actinopterygii ).darker( 1 ),
                  iconicTaxonName: "Actinopterygii"
                },
                {
                  label: nameForPieLabel( I18n.t( "amphibians" ) ),
                  fullLabel: _.capitalize( I18n.t( "amphibians" ) ),
                  value: data.taxa.iconic_taxa_counts.Amphibia,
                  color: d3.color( COLORS.iconic.Amphibia ).darker( 0.5 ),
                  iconicTaxonName: "Amphibia"
                },
                {
                  label: nameForPieLabel( I18n.t( "reptiles" ) ),
                  fullLabel: _.capitalize( I18n.t( "reptiles" ) ),
                  value: data.taxa.iconic_taxa_counts.Reptilia,
                  color: d3.color( COLORS.iconic.Reptilia ),
                  iconicTaxonName: "Reptilia"
                },
                {
                  label: nameForPieLabel( I18n.t( "birds" ) ),
                  fullLabel: _.capitalize( I18n.t( "birds" ) ),
                  value: data.taxa.iconic_taxa_counts.Aves,
                  color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ),
                  iconicTaxonName: "Aves"
                },
                {
                  label: nameForPieLabel( I18n.t( "mammals" ) ),
                  fullLabel: _.capitalize( I18n.t( "mammals" ) ),
                  value: data.taxa.iconic_taxa_counts.Mammalia,
                  color: d3.color( COLORS.iconic.Aves ).brighter( 1 ),
                  iconicTaxonName: "Mammalia"
                },
                {
                  label: nameForPieLabel( I18n.t( "other_animals" ) ),
                  fullLabel: _.capitalize( I18n.t( "other_animals" ) ),
                  value: data.taxa.iconic_taxa_counts.Animalia,
                  color: d3.color( COLORS.iconic.Animalia ),
                  iconicTaxonName: "Animalia"
                }
              ]}
              legendColumns={ 2 }
              legendColumnWidth={ 120 }
              margin={ pieMargin }
              labelForDatum={ d => {
                const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                const percent = _.round( degrees / 360 * 100, 2 );
                const value = I18n.t( "x_observations", {
                  count: I18n.toNumber( d.value, { precision: 0 } )
                } );
                return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
              }}
              donutWidth={ donutWidth }
              onClick={ d => {
                let url = `/observations?d1=${year}-01-01&d2=${year + 1}-01-01`;
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
          </div>
        ) : null }
      </Col>
      <Col xs={ 4 }>
        { data.identifications && data.identifications.category_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={ { __html: I18n.t( "x_identifications_html", {
                count: I18n.toNumber(
                  _.sum( _.map( data.identifications.category_counts, v => v ) ),
                  { precision: 0 }
                )
              } ) } }
            />
            <PieChart
              data={[
                {
                  label: _.capitalize( I18n.t( "improving" ) ),
                  value: data.identifications.category_counts.improving,
                  color: COLORS.inatGreen,
                  category: "improving"
                },
                {
                  label: _.capitalize( I18n.t( "supporting" ) ),
                  value: data.identifications.category_counts.supporting,
                  color: COLORS.inatGreenLight,
                  category: "supporting"
                },
                {
                  label: _.capitalize( I18n.t( "leading" ) ),
                  value: data.identifications.category_counts.leading,
                  color: COLORS.needsIdYellow,
                  category: "leading"
                },
                {
                  label: _.capitalize( I18n.t( "maverick" ) ),
                  value: data.identifications.category_counts.maverick,
                  color: COLORS.failRed,
                  category: "maverick"
                }
              ]}
              legendColumns={ 2 }
              legendColumnWidth={ 100 }
              margin={ pieMargin }
              donutWidth={ donutWidth }
              onClick={ d => {
                let url = `/identifications?for=others&current=true&category=${d.data.category}&d1=${year}-01-01&d2=${year + 1}-01-01`;
                if ( user ) {
                  url += `&user_id=${user.login}`;
                }
                window.open( url, "_blank" );
              } }
            />
          </div>
        ) : null }
      </Col>
    </Row>
  );
};

Summary.propTypes = {
  data: React.PropTypes.object,
  year: React.PropTypes.number,
  user: React.PropTypes.object
};

export default Summary;
