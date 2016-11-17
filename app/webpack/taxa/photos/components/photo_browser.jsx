import React, { PropTypes } from "react";
import InfiniteScroll from "react-infinite-scroller";
import {
  Grid,
  Row,
  Col,
  ButtonGroup,
  Button
} from "react-bootstrap";
import TaxonPhoto from "../../shared/components/taxon_photo";

const PhotoBrowser = ( {
  observationPhotos,
  showTaxonPhotoModal,
  loadMorePhotos,
  hasMorePhotos,
  layout,
  setLayout
} ) => (
  <Grid className={`PhotoBrowser ${layout}`}>
    <Row>
      <Col xs={12}>
        <div id="controls">
          <ButtonGroup>
            <Button
              active={layout === "fluid"}
              title={I18n.t( "fluid_layout" )}
              onClick={( ) => setLayout( "fluid" )}
            >
              Fluid
            </Button>
            <Button
              active={layout === "grid"}
              title={I18n.t( "grid_layout" )}
              onClick={( ) => setLayout( "grid" )}
            >
              <i className="glyphicon glyphicon-th-large"></i>
            </Button>
          </ButtonGroup>
        </div>
      </Col>
    </Row>
    <Row>
      <Col xs={12}>
        <InfiniteScroll
          loadMore={( ) => loadMorePhotos( )}
          hasMore={ hasMorePhotos }
          className="photos"
          loader={
            <div className="loading">
              <i className="fa fa-refresh fa-spin"></i> { I18n.t( "loading" ) }
            </div>
          }
        >
          { observationPhotos.map( observationPhoto => {
            const itemDim = 180;
            let width = itemDim;
            if ( layout === "fluid" ) {
              width = itemDim / observationPhoto.photo.dimensions( ).height * observationPhoto.photo.dimensions( ).width;
            }
            return (
              <TaxonPhoto
                key={`taxon-photo-${observationPhoto.photo.id}`}
                photo={observationPhoto.photo}
                taxon={observationPhoto.observation.taxon}
                observation={observationPhoto.observation}
                width={width}
                height={itemDim}
                showTaxonPhotoModal={ ( ) => showTaxonPhotoModal(
                  observationPhoto.photo,
                  observationPhoto.observation.taxon,
                  observationPhoto.observation
                ) }
              />
            );
          } ) }
        </InfiniteScroll>
      </Col>
    </Row>
  </Grid>
);

PhotoBrowser.propTypes = {
  observationPhotos: PropTypes.array.isRequired,
  showTaxonPhotoModal: PropTypes.func.isRequired,
  loadMorePhotos: PropTypes.func.isRequired,
  hasMorePhotos: PropTypes.bool,
  layout: PropTypes.string,
  setLayout: PropTypes.func.isRequired
};

PhotoBrowser.defaultProps = {
  observationPhotos: [],
  layout: "fluid"
};

export default PhotoBrowser;
