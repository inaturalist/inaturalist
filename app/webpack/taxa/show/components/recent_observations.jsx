import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { Grid, Row, Col } from "react-bootstrap";
import Carousel from "./carousel";
import TaxonPhoto from "../../shared/components/taxon_photo";

const RecentObservations = ( { observations, showPhotoModal, url } ) => {
  if ( !observations ) { return ( <span /> ); }
  const chunkSize = 7;
  return (
    <Grid className={`RecentObservations ${observations.length < chunkSize ? "no-slides" : ""}`}>
      <Row>
        <Col xs={12}>
          <Carousel
            title={ I18n.t( "recent_observations" ) }
            noContent={ I18n.t( "no_observations_yet" ) }
            items={ _.map( _.chunk( observations, chunkSize ), ( chunk, i ) => (
              <div className="slide" key={`recent-observations-${i}`}>
                {
                  chunk.map( observation => (
                    <TaxonPhoto
                      key={`recent-observations-obs-${observation.id}`}
                      photo={observation.photos[0]}
                      taxon={observation.taxon}
                      observation={observation}
                      width={120}
                      height={120}
                      showTaxonPhotoModal={ ( ) => showPhotoModal(
                        observation.photos[0],
                        observation.taxon,
                        observation
                      ) }
                    />
                  ) )
                }
                {
                  chunk.length < chunkSize ? (
                    <a href={url} className="viewall">{ I18n.t( "view_all" ) }</a>
                  ) : null
                }
              </div>
            ) ) }
          />
        </Col>
      </Row>
    </Grid>
  );
};

RecentObservations.propTypes = {
  observations: PropTypes.array,
  showPhotoModal: PropTypes.func,
  url: PropTypes.string
};

export default RecentObservations;
