import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Col, OverlayTrigger, Tooltip } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../../taxa/shared/util";

const ObservationsHighlight = ( {
  title,
  observations,
  searchParams,
  showNewObservation,
  config
} ) => {
  const { testingApiV2 } = config || {};
  const loadObservationCallback = ( e, observation ) => {
    if ( !e.metaKey ) {
      e.preventDefault( );
      showNewObservation( observation, {
        useInstance: !testingApiV2
      } );
    }
  };
  const empty = _.isEmpty( observations );
  let content = <span className="none">{ I18n.t( "none_found" ) }</span>;
  if ( !empty ) {
    content = _.filter( observations, o => ( o.photo( ) ) ).map( o => (
      <Col xs={2} key={`highlight-${o.uuid}`}>
        <div className="photo">
          <OverlayTrigger
            container={$( "#wrapper.bootstrap" ).get( 0 )}
            placement="top"
            delayShow={200}
            overlay={(
              <Tooltip id={`highlight-link-${o.id}`} className="obs-highlight-link">
                <SplitTaxon
                  taxon={o.taxon}
                  url={urlForTaxon( o.taxon )}
                  noParens
                  user={config.currentUser}
                />
              </Tooltip>
            )}
          >
            <a
              href={`/observations/${o.id}`}
              style={{ backgroundImage: `url( '${o.photo( "small" )}' )` }}
              onClick={e => loadObservationCallback( e, o )}
            >
              &nbsp;
            </a>
          </OverlayTrigger>
        </div>
      </Col>
    ) );
  }
  const viewAll = empty ? null : (
    <a href={`/observations?${$.param( searchParams )}`}>
      { I18n.t( "view_all" ) }
    </a>
  );
  return (
    <div className="ObservationsHighlight">
      <Col xs={12}>
        <h3>
          { title }
          { viewAll }
        </h3>
      </Col>
      <div className={`list ${empty ? "empty" : ""}`}>
        { content }
      </div>
    </div>
  );
};

ObservationsHighlight.propTypes = {
  title: PropTypes.string,
  searchParams: PropTypes.object,
  observations: PropTypes.array,
  showNewObservation: PropTypes.func,
  config: PropTypes.object
};

ObservationsHighlight.defaultProps = {
  config: {}
};

export default ObservationsHighlight;
