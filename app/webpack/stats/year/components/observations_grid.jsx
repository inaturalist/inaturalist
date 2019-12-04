import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import moment from "moment";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";

const ObservationsGrid = ( {
  observations,
  user,
  columns,
  max,
  identifier,
  dateField
} ) => (
  <div className={`${identifier} ${user ? "for-user" : ""}`}>
    { _.map( _.chunk( observations.slice( 0, max ), columns ), ( chunk, i ) => (
      <Row key={`${identifier}-obs-chunk-${i}`}>
        { chunk.map( o => (
          <Col
            xs={Math.floor( 12.0 / columns * 4.0 )}
            sm={Math.floor( 12.0 / columns )}
            md={Math.floor( 12.0 / columns )}
            lg={Math.floor( 12.0 / columns )}
            key={`popular-obs-${o.id}`}
          >
            <ObservationsGridItem
              observation={new inatjs.Observation( o )}
              splitTaxonOptions={{ noParens: true }}
              controls={(
                <div>
                  <span className="activity">
                    <span className="stat">
                      <i className="icon-chatbubble" />
                      { " " }
                      { o.comments_count }
                    </span>
                    <span className="stat">
                      <i className="fa fa-star" />
                      { " " }
                      { o.faves_count === null || o.faves_count === undefined ? o.cached_votes_total : o.faves_count }
                    </span>
                  </span>
                  <time
                    className="time pull-right"
                    dateTime={o.created_at}
                    title={moment( o[dateField] ).format( "LLL" )}
                  >
                    { moment( o[dateField] ).format( "DD MMM" ) }
                  </time>
                </div>
              )}
            />
          </Col>
        ) ) }
      </Row>
    ) ) }
  </div>
);

ObservationsGrid.propTypes = {
  observations: PropTypes.array,
  user: PropTypes.object,
  columns: PropTypes.number,
  max: PropTypes.number,
  identifier: PropTypes.string.isRequired,
  dateField: PropTypes.string
};

ObservationsGrid.defaultProps = {
  columns: 4,
  max: 8,
  dateField: "observed_on"
};

export default ObservationsGrid;
