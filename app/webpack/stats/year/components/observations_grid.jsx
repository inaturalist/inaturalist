import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import moment from "moment";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";

class ObservationsGrid extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      initialObsToShow: props.perPage || props.max
    };
  }

  render( ) {
    const {
      observations,
      user,
      columns,
      identifier,
      dateField,
      perPage,
      max
    } = this.props;
    const { initialObsToShow } = this.state;
    let obsToshow = initialObsToShow;
    if ( !perPage && initialObsToShow < max ) {
      obsToshow = max;
    }
    return (
      <div className={`${identifier} ${user ? "for-user" : ""}`}>
        { _.map( _.chunk( observations.slice( 0, obsToshow ), columns ), ( chunk, i ) => (
          <Row key={`${identifier}-obs-chunk-${i}`} className="d-flex flex-wrap">
            { chunk.map( o => {
              const colSize = Math.floor( 12.0 / columns );
              const xsColSize = colSize <= 2 ? 6 : 12;
              let favesCount = o.faves_count;
              if ( o.faves_count === null || o.faves_count === undefined ) {
                favesCount = o.cached_votes_total;
              }
              return (
                <Col
                  xs={xsColSize}
                  sm={colSize}
                  md={colSize}
                  lg={colSize}
                  key={`popular-obs-${o.id}`}
                  className="d-flex"
                >
                  <ObservationsGridItem
                    className="d-flex"
                    observation={new inatjs.Observation( o )}
                    splitTaxonOptions={{ noParens: true, noInactive: true }}
                    photoSize="medium"
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
                            { favesCount }
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
              );
            } ) }
          </Row>
        ) ) }
        { observations.length > initialObsToShow && perPage && (
          <button
            type="button"
            className="btn btn-default btn-bordered center-block"
            onClick={() => {
              this.setState( {
                initialObsToShow: Math.min( observations.length, initialObsToShow + perPage )
              } );
            }}
          >
            { I18n.t( "more__context_observations_caps", {
              defaultValue: I18n.t( "more_caps", {
                defaultValue: I18n.t( "more" )
              } )
            } ) }
          </button>
        ) }
      </div>
    );
  }
}

ObservationsGrid.propTypes = {
  observations: PropTypes.array,
  user: PropTypes.object,
  columns: PropTypes.number,
  max: PropTypes.number,
  perPage: PropTypes.number,
  identifier: PropTypes.string.isRequired,
  dateField: PropTypes.string
};

ObservationsGrid.defaultProps = {
  columns: 4,
  max: 8,
  dateField: "observed_on"
};

export default ObservationsGrid;
