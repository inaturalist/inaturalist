import React from "react";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";

const Summary = ( { data } ) => (
  <Row className="Summary">
    <Col xs={ 4 }>
      { data.observations.quality_grade_counts ? (
        <div className="panel">
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
          <table>
            <tr className="research">
              <td className="count">
                  { I18n.toNumber(
                    data.observations.quality_grade_counts.research,
                    { precision: 0 }
                  ) }
              </td>
              <td>
                { I18n.t( "research_grade" ) }
              </td>
            </tr>
            <tr className="needs_id">
              <td className="count">
                  { I18n.toNumber(
                    data.observations.quality_grade_counts.needs_id,
                    { precision: 0 }
                  ) }
              </td>
              <td>
                { I18n.t( "needs_id" ) }
              </td>
            </tr>
            <tr className="casual">
              <td className="count">
                  { I18n.toNumber(
                    data.observations.quality_grade_counts.casual,
                    { precision: 0 }
                  ) }
              </td>
              <td>
                { I18n.t( "casual" ) }
              </td>
            </tr>
          </table>
        </div>
      ) : null }
    </Col>
    <Col xs={ 4 }>
      { data.taxa && data.taxa.iconic_taxa_counts ? (
        <div className="panel">
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
          <table>
            <tbody>
              { _.map( data.taxa.iconic_taxa_counts, ( v, k ) => (
                <tr key={ `iconic-taxa-counts-${k}` }>
                  <td className="count">{ v }</td>
                  <td>{ k }</td>
                </tr>
              ) ) }
            </tbody>
          </table>
        </div>
      ) : null }
    </Col>
    <Col xs={ 4 }>
      { data.identifications && data.identifications.category_counts ? (
        <div className="panel">
          <div
            className="main"
            dangerouslySetInnerHTML={ { __html: I18n.t( "x_identifications_html", {
              count: I18n.toNumber(
                _.sum( _.map( data.identifications.category_counts, v => v ) ),
                { precision: 0 }
              )
            } ) } }
          />
          <table>
            <tbody>
              { _.map( data.identifications.category_counts, ( v, k ) => (
                <tr key={ `iconic-taxa-counts-${k}` }>
                  <td className="count">{ v }</td>
                  <td>{ I18n.t( k ) }</td>
                </tr>
              ) ) }
            </tbody>
          </table>
        </div>
      ) : null }
    </Col>
  </Row>
);

Summary.propTypes = {
  data: React.PropTypes.object
};

export default Summary;
