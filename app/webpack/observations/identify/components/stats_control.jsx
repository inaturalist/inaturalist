import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";

const StatsControl = ( {
  stats,
  currentQualityGrade,
  updateQualityGrade
} ) => {
  const statControl = ( qualityGrade ) => {
    let title;
    let value;
    switch ( qualityGrade ) {
      case "needs_id":
        title = I18n.t( "needs_id" );
        value = stats.needsId;
        break;
      case "research":
        title = I18n.t( "research_grade" );
        value = stats.research;
        break;
      default:
        title = I18n.t( "casual" );
        value = stats.casual;
    }
    return (
      <Col
        xs={2}
        key={`statcol-${qualityGrade}`}
        className={`statcol ${currentQualityGrade === qualityGrade ? "active" : ""}`}
        onClick={ function ( ) {
          updateQualityGrade( qualityGrade );
        } }
      >
        <div className="stat">
          <div className="stat-value">
            { value === undefined ? "--" : I18n.toNumber( value, { precision: 0 } ) }
          </div>
          <div className="stat-title">
            { title }
          </div>
        </div>
      </Col>
    );
  };
  return (
    <Row className="StatsControl">
      { "needs_id research casual".split( " " ).map( qg => statControl( qg ) ) }
    </Row>
  );
};

StatsControl.propTypes = {
  stats: PropTypes.object,
  currentQualityGrade: PropTypes.string,
  updateQualityGrade: PropTypes.func
};

export default StatsControl;
