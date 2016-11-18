import React, { PropTypes } from "react";
import InfiniteScroll from "react-infinite-scroller";
import {
  Grid,
  Row,
  Col,
  ButtonGroup,
  Button,
  DropdownButton,
  MenuItem,
  Dropdown
} from "react-bootstrap";
import TaxonPhoto from "../../shared/components/taxon_photo";

const PhotoBrowser = ( {
  observationPhotos,
  showTaxonPhotoModal,
  loadMorePhotos,
  hasMorePhotos,
  layout,
  setLayout,
  terms,
  setTerm
} ) => (
  <Grid className={`PhotoBrowser ${layout}`}>
    <Row>
      <Col xs={12}>
        <div id="controls">
          <ButtonGroup className="control-group">
            <Button
              active={layout === "fluid"}
              title={I18n.t( "fluid_layout" )}
              onClick={( ) => setLayout( "fluid" )}
            >
              <i className="icon-photo-quilt"></i>
            </Button>
            <Button
              active={layout === "grid"}
              title={I18n.t( "grid_layout" )}
              onClick={( ) => setLayout( "grid" )}
            >
              <i className="icon-photo-grid"></i>
            </Button>
          </ButtonGroup>
          { terms.map( term => (
            <span key={`term-${term}`} className="control-group">
              <Dropdown
                id={`term-chooser-${term.name}`}
                onSelect={ ( event, key ) => setTerm( term.name, key ) }
              >
                <Dropdown.Toggle bsClass="link">
                  { term.name }: <strong>{ term.selectedValue || I18n.t( "any" ) }</strong>
                </Dropdown.Toggle>
                <Dropdown.Menu className="super-colors">
                  <MenuItem
                    key={`term-chooser-item-${term.name}-any`}
                    eventKey={"any"}
                    active={term.selectedValue === "any" || !term.selectedValue}
                  >
                    { I18n.t( "any" ) }
                  </MenuItem>
                  { term.values.map( value => (
                    <MenuItem
                      key={`term-chooser-item-${term.name}-${value}`}
                      eventKey={value}
                      active={term.selectedValue === value}
                    >
                      { value }
                    </MenuItem>
                  ) ) }
                </Dropdown.Menu>
              </Dropdown>
            </span>
          ) ) }
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
  setLayout: PropTypes.func.isRequired,
  terms: PropTypes.arrayOf(
    PropTypes.shape( {
      name: PropTypes.string,
      values: PropTypes.array,
      selectedValue: PropTypes.string
    } )
  ),
  setTerm: PropTypes.func
};

PhotoBrowser.defaultProps = {
  observationPhotos: [],
  layout: "fluid",
  terms: []
};

export default PhotoBrowser;
