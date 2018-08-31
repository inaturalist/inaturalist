import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import { COLORS } from "../../../shared/util";
import PieChart from "./pie_chart";
import PieChartForIconicTaxonCounts from "./pie_chart_for_iconic_taxon_counts";

const Summary = ( {
  data,
  user,
  year
} ) => {
  const pieMargin = { top: 0, bottom: 120, left: 0, right: 0 };
  const donutWidth = 20;
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
                let url = `/observations?place_id=any&quality_grade=${d.data.qualityGrade}&${year}-01-01&d2=${year + 1}-01-01`;
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
            <PieChartForIconicTaxonCounts
              data={ data.taxa.iconic_taxa_counts }
              margin={ pieMargin }
              donutWidth={ donutWidth }
              user={ user }
              year={ year }
              labelForDatum={ d => {
                const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
                const percent = _.round( degrees / 360 * 100, 2 );
                const value = I18n.t( "x_observations", {
                  count: I18n.toNumber( d.value, { precision: 0 } )
                } );
                return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
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
  data: PropTypes.object,
  year: PropTypes.number,
  user: PropTypes.object
};

export default Summary;
