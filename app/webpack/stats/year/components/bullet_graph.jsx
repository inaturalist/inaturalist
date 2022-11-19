import React from "react";
import PropTypes from "prop-types";
import { scaleLinear } from "d3";
import { OverlayTrigger, Tooltip } from "react-bootstrap";
import { shortFormattedNumber } from "../../../shared/util";

const BulletGraph = ( {
  performance,
  comparison,
  low,
  lowLabel,
  lowLabelExtra,
  medium,
  mediumLabel,
  mediumLabelExtra,
  high,
  highLabel,
  highLabelExtra,
  vertical
} ) => {
  const valueDimension = vertical ? "height" : "width";
  const scale = scaleLinear( ).domain( [0, high] ).range( [0, 100] );
  const ticks = scale.ticks( );
  return (
    <div className={`BulletGraph ${vertical ? "vertical" : ""}`}>
      <div className="high" style={{ [valueDimension]: "100%" }} title={high.toString( )}>
        <div className="qual-label">{ highLabel }</div>
        <div className="qual-label-extra">{ highLabelExtra }</div>
        <div className="medium" style={{ [valueDimension]: `${scale( medium )}%` }} title={medium.toString( )}>
          <div className="qual-label">{ mediumLabel }</div>
          <div className="qual-label-extra">{ mediumLabelExtra }</div>
        </div>
        {
          scale( low ) < 5
            ? (
              <div className="low-too-small">
                <OverlayTrigger
                  placement="top"
                  trigger="click"
                  rootClose
                  container={$( "#wrapper.bootstrap" ).get( 0 )}
                  overlay={(
                    <Tooltip id={`bullet-low-too-small-${low}-${medium}-${high}`}>
                      { I18n.t( "views.stats.year.low_too_small", { low_value: low, low_desc: lowLabelExtra } ) }
                    </Tooltip>
                  )}
                >
                  <i className="fa fa-info-circle" />
                </OverlayTrigger>
              </div>
            )
            : (
              <div className="low" style={{ [valueDimension]: `${scale( low )}%` }} title={low.toString( )}>
                <div className="qual-label">{ lowLabel }</div>
                <div className="qual-label-extra">{ lowLabelExtra }</div>
              </div>
            )
        }
        <div
          className="comparison"
          style={{ [valueDimension]: `${scale( comparison )}%` }}
          title={comparison.toString( )}
        />
        <div
          className="performance"
          style={{ [valueDimension]: `${scale( performance )}%` }}
          title={performance.toString( )}
        />
      </div>
      <div className="ticks">
        { ticks.map( ( tick, i ) => (
          <div
            key={`bullet-graph-ticks-${tick}`}
            className={`tick ${tick === 0 ? "zero" : ""} ${i % 2 === 0 ? "even" : "odd"}`}
            style={{ [valueDimension]: `${scale( tick )}%` }}
          >
            <span>{ shortFormattedNumber( tick ) }</span>
          </div>
        ) ) }
      </div>
    </div>
  );
};

BulletGraph.propTypes = {
  performance: PropTypes.number,
  comparison: PropTypes.number,
  low: PropTypes.number,
  lowLabel: PropTypes.string,
  lowLabelExtra: PropTypes.string,
  medium: PropTypes.number,
  mediumLabel: PropTypes.string,
  mediumLabelExtra: PropTypes.string,
  high: PropTypes.number,
  highLabel: PropTypes.string,
  highLabelExtra: PropTypes.string,
  vertical: PropTypes.bool
};

BulletGraph.defaultProps = {
  comparison: 0,
  high: 0,
  low: 0,
  medium: 0,
  performance: 0
};

export default BulletGraph;
