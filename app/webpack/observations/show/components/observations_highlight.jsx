import _ from "lodash";
import React, { PropTypes } from "react";
import { Col, OverlayTrigger, Tooltip } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../../taxa/shared/util";

const ObservationsHighlight = ( { title, observations, searchParams, showNewObservation } ) => {
  if ( _.isEmpty( observations ) ) { return ( <div /> ); }
  const loadObservationCallback = ( e, observation ) => {
    if ( !e.metaKey ) {
      e.preventDefault( );
      showNewObservation( observation );
    }
  };
  return (
    <div className="ObservationsHighlight">
      <Col xs={ 12 }>
        <h3>
          { title }
          <a href={ `/observations?${$.param( searchParams )}` }>
            { I18n.t( "view_all" ) }
          </a>
        </h3>
      </Col>
      <div className="list">
        { _.filter( observations, o => ( o.photo( ) ) ).map( o => (
          <Col xs={ 2 } key={ `highlight-${o.id}` }>
            <div className="photo">
              <OverlayTrigger
                placement="top"
                delayShow={ 200 }
                overlay={ (
                  <Tooltip id={`highlight-link-${o.id}`} className="obs-highlight-link">
                    <SplitTaxon taxon={o.taxon} url={urlForTaxon( o.taxon )} noParens />
                  </Tooltip>
                ) }
              >
                <a
                  href={ `/observations/${o.id}` }
                  style={ { backgroundImage: `url( '${o.photo( "small" )}' )` } }
                  onClick={ e => { loadObservationCallback( e, o ); } }
                />
              </OverlayTrigger>
            </div>
          </Col>
          ) )
        }
      </div>
    </div>
  );
};

ObservationsHighlight.propTypes = {
  title: PropTypes.string,
  searchParams: PropTypes.object,
  observations: PropTypes.array,
  showNewObservation: PropTypes.func
};

export default ObservationsHighlight;
