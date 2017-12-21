import React from "react";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";
import * as d3 from "d3";

const Summary = ( { data } ) => {
  const pieMargin = { top: 0, bottom: 120, left: 0, right: 0 };
  return (
    <Row className="Summary">
      <Col xs={ 4 }>
        { data.observations.quality_grade_counts ? (
          <div className="summary-panel">
            <div
              className="main"
              dangerouslySetInnerHTML={ { __html: I18n.t( "x_observations_html", {
                count: I18n.toNumber(
                  (
                    data.observations.quality_grade_counts.research + data.observations.quality_grade_counts.needs_id
                  ),
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
                  color: "#aaaaaa"
                },
                {
                  label: _.upperFirst( I18n.t( "needs_id" ) ),
                  value: data.observations.quality_grade_counts.needs_id,
                  color: COLORS.needsIdYellow
                },
                {
                  label: _.upperFirst( I18n.t( "research" ) ),
                  value: data.observations.quality_grade_counts.research,
                  color: COLORS.inatGreenLight
                }
              ]}
              legendOrient="horizontal"
              legendColumnWidth={ 125 }
              legendShapePadding={ 50 }
              margin={ pieMargin }
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
                  label: _.capitalize( I18n.t( "unknown" ) ),
                  value: data.taxa.iconic_taxa_counts.Unknown,
                  color: COLORS.iconic.Unknown
                },
                {
                  label: _.capitalize( I18n.t( "protozoans" ) ),
                  value: data.taxa.iconic_taxa_counts.Protozoa,
                  color: COLORS.iconic.Protozoa
                },
                {
                  label: _.capitalize( I18n.t( "fungi", { count: 2 } ) ),
                  value: data.taxa.iconic_taxa_counts.Fungi,
                  color: COLORS.iconic.Fungi
                },
                {
                  label: _.capitalize( I18n.t( "plants" ) ),
                  value: data.taxa.iconic_taxa_counts.Plantae,
                  color: COLORS.inatGreenLight
                },
                {
                  label: _.capitalize( I18n.t( "all_taxa.chromista" ) ),
                  value: data.taxa.iconic_taxa_counts.Chromista,
                  color: COLORS.iconic.Chromista
                },
                {
                  label: _.capitalize( I18n.t( "mollusks" ) ),
                  value: data.taxa.iconic_taxa_counts.Mollusca,
                  color: COLORS.iconic.Mollusca
                },
                {
                  label: _.capitalize( I18n.t( "insects" ) ),
                  value: data.taxa.iconic_taxa_counts.Insecta,
                  color: d3.color( COLORS.iconic.Insecta ).brighter( )
                },
                {
                  label: _.capitalize( I18n.t( "arachnids" ) ),
                  value: data.taxa.iconic_taxa_counts.Arachnida,
                  color: d3.color( COLORS.iconic.Arachnida ).brighter( ).brighter( )
                },
                {
                  label: _.capitalize( I18n.t( "ray_finned_fishes" ) ),
                  value: data.taxa.iconic_taxa_counts.Actinopterygii,
                  color: COLORS.iconic.Actinopterygii
                },
                {
                  label: _.capitalize( I18n.t( "amphibians" ) ),
                  value: data.taxa.iconic_taxa_counts.Amphibia,
                  color: d3.color( COLORS.iconic.Amphibia ).brighter( 0.5 )
                },
                {
                  label: _.capitalize( I18n.t( "reptiles" ) ),
                  value: data.taxa.iconic_taxa_counts.Reptilia,
                  color: d3.color( COLORS.iconic.Reptilia ).brighter( 0.5 ).brighter( 0.5 )
                },
                {
                  label: _.capitalize( I18n.t( "birds" ) ),
                  value: data.taxa.iconic_taxa_counts.Aves,
                  color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ).brighter( 0.5 ).brighter( 0.5 )
                },
                {
                  label: _.capitalize( I18n.t( "other_animals" ) ),
                  value: data.taxa.iconic_taxa_counts.Animalia,
                  color: d3.color( COLORS.iconic.Aves ).brighter( 0.5 ).brighter( 0.5 ).brighter( 0.5 ).brighter( 0.5 )
                }
              ]}
              legendColumns={ 2 }
              legendColumnWidth={ 120 }
              margin={ pieMargin }
              labelForDatum={ d => {
                const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                const percent = _.round( degrees / 360 * 100, 2 );
                return `<strong>${d.data.label}</strong>: ${I18n.t( "x_observations", { count: d.value } )} (${percent}%)`;
              }}
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
                  color: COLORS.inatGreen
                },
                {
                  label: _.capitalize( I18n.t( "supporting" ) ),
                  value: data.identifications.category_counts.supporting,
                  color: COLORS.inatGreenLight
                },
                {
                  label: _.capitalize( I18n.t( "leading" ) ),
                  value: data.identifications.category_counts.leading,
                  color: COLORS.needsIdYellow
                },
                {
                  label: _.capitalize( I18n.t( "maverick" ) ),
                  value: data.identifications.category_counts.maverick,
                  color: COLORS.failRed
                }
              ]}
              legendColumns={ 2 }
              legendColumnWidth={ 100 }
              margin={ pieMargin }
            />
          </div>
        ) : null }
      </Col>
    </Row>
  );
}

Summary.propTypes = {
  data: React.PropTypes.object
};

export default Summary;
