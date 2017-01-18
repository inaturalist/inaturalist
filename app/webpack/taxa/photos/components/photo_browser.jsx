import React, { PropTypes } from "react";
import InfiniteScroll from "react-infinite-scroller";
import _ from "lodash";
import {
  Grid,
  Row,
  Col,
  ButtonGroup,
  Button,
  MenuItem,
  Dropdown
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../shared/components/taxon_photo";
import { urlForTaxonPhotos } from "../../shared/util";

const PhotoBrowser = ( {
  groupedPhotos,
  grouping,
  hasMorePhotos,
  layout,
  loadMorePhotos,
  observationPhotos,
  params,
  setGrouping,
  setLayout,
  setParam,
  setTerm,
  showTaxonPhotoModal,
  terms,
  showTaxonGrouping,
  place
} ) => {
  let sortedGroupedPhotos;
  if ( grouping.param === "taxon_id" ) {
    sortedGroupedPhotos = _.sortBy( _.values( groupedPhotos ), group => group.groupObject.name );
  } else {
    sortedGroupedPhotos = _.sortBy( _.values( groupedPhotos ), "groupName" );
  }
  const renderObservationPhotos = obsPhotos => (
    ( obsPhotos || [] ).map( observationPhoto => {
      let itemDim = 183;
      let width = itemDim;
      if ( layout === "fluid" ) {
        itemDim = itemDim + 50;
        const dims = observationPhoto.photo.dimensions( );
        if ( dims ) {
          width = itemDim / dims.height * dims.width;
        } else {
          width = itemDim;
        }
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
          showTaxon
        />
      );
    } )
  );
  const loader = (
    <div className="loading">
      <i className="fa fa-refresh fa-spin"></i>
    </div>
  );
  const noObsNotice = (
    <div className="nocontent text-muted">
      { I18n.t( place ? "no_observations_from_this_place_yet" : "no_observations_yet" ) }
    </div>
  );
  const renderUngroupedPhotos = ( ) => (
    <InfiniteScroll
      loadMore={( ) => loadMorePhotos( )}
      hasMore={ hasMorePhotos }
      className="photos"
      loader={loader}
    >
      { observationPhotos && observationPhotos.length === 0 ? noObsNotice : null }
      { observationPhotos ? null : loader }
      { renderObservationPhotos( observationPhotos ) }
    </InfiniteScroll>
  );
  const renderGroupedPhotos = ( ) => (
    <div>
      { sortedGroupedPhotos.map( group => (
        <div key={`group-${group.groupName}`} className="photo-group">
          <h3>
            { group.groupObject ?
              <SplitTaxon
                taxon={group.groupObject}
                url={urlForTaxonPhotos(
                  group.groupObject,
                  $.deparam( window.location.search.replace( /^\?/, "" ) )
                ) }
              /> : group.groupName }
          </h3>
          <div className="photos">
            { group.observationPhotos.length === 0 ?
              <div className="nocontent text-muted">{ I18n.t( "no_observations_yet" ) }</div>
              : null
            }
            { renderObservationPhotos( group.observationPhotos ) }
          </div>
        </div>
      ) ) }
    </div>
  );
  const orderByDisplay = key => {
    if ( key === "created_at" ) {
      return I18n.t( "date_added" );
    }
    return I18n.t( "faves" );
  };
  const groupingDisplay = param => {
    if ( param === "taxon_id" ) {
      return I18n.t( "taxonomic" );
    } else if ( param ) {
      const displayText = param.replace( "field:", "" );
      return I18n.t( displayText, { defaultValue: displayText } );
    }
    return I18n.t( "none" );
  };
  let groupingMenuItems = [];
  if ( showTaxonGrouping ) {
    groupingMenuItems.push(
      <MenuItem
        key="grouping-menu-item-taxon-id"
        eventKey={"taxon_id"}
        active={grouping.param === "taxon_id"}
      >
        { groupingDisplay( "taxon_id" ) }
      </MenuItem>
    );
  }
  groupingMenuItems = groupingMenuItems.concat(
    terms.map( term => (
      <MenuItem
        key={`grouping-chooser-item-${term.name}`}
        eventKey={term.name}
        active={grouping.param === `field:${term.name}`}
      >
        { term.name }
      </MenuItem>
    ) )
  );
  if ( groupingMenuItems.length > 0 ) {
    groupingMenuItems.unshift(
      <MenuItem
        key="grouping-menu-item-none"
        eventKey={"none"}
        active={!grouping.param}
      >
        { groupingDisplay( null ) }
      </MenuItem>
    );
  }
  return (
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
            { groupingMenuItems.length === 0 ? null : (
              <span className="control-group">
                <Dropdown
                  id="grouping-control"
                  onSelect={ ( event, key ) => {
                    if ( key === "none" ) {
                      setGrouping( null );
                    } else if ( key === "taxon_id" ) {
                      setGrouping( "taxon_id" );
                    } else {
                      setGrouping(
                        `field:${key}`,
                        _.find( terms, t => t.name === key ).values
                      );
                    }
                  } }
                >
                  <Dropdown.Toggle bsClass="link">
                    { I18n.t( "grouping" ) }: <strong>{ groupingDisplay( grouping.param ) }</strong>
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
                    { groupingMenuItems }
                  </Dropdown.Menu>
                </Dropdown>
              </span>
            ) }
            { terms.map( term => (
              <span key={`term-${term}`} className="control-group">
                <Dropdown
                  id={`term-chooser-${term.name}`}
                  onSelect={ ( event, key ) => setTerm( term.name, key ) }
                >
                  <Dropdown.Toggle bsClass="link">
                    {
                      I18n.t( _.snakeCase( term.name ) )
                    }: <strong>{
                      I18n.t( _.snakeCase( term.selectedValue || "any" ), { defaultValue: term.selectedValue } )
                    }</strong>
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
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
                        { I18n.t( _.snakeCase( value ), { defaultValue: value } ) }
                      </MenuItem>
                    ) ) }
                  </Dropdown.Menu>
                </Dropdown>
              </span>
            ) ) }
            <span className="control-group">
              <Dropdown
                id="sort-control"
                onSelect={ ( event, key ) => {
                  setParam( "order_by", key );
                } }
              >
                <Dropdown.Toggle bsClass="link">
                  { I18n.t( "order_by" ) }: <strong>{ orderByDisplay( params.order_by ) }</strong>
                </Dropdown.Toggle>
                <Dropdown.Menu>
                  <MenuItem
                    eventKey={"votes"}
                    active={params.order_by === "votes"}
                  >
                    { orderByDisplay( "votes" ) }
                  </MenuItem>
                  <MenuItem
                    eventKey={"created_at"}
                    active={grouping === "created_at"}
                  >
                    { orderByDisplay( "created_at" ) }
                  </MenuItem>
                </Dropdown.Menu>
              </Dropdown>
            </span>
          </div>
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          { sortedGroupedPhotos && sortedGroupedPhotos.length > 0 ?
            renderGroupedPhotos( ) : renderUngroupedPhotos( ) }
        </Col>
      </Row>
    </Grid>
  );
};

PhotoBrowser.propTypes = {
  observationPhotos: PropTypes.array,
  groupedPhotos: PropTypes.object,
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
  setTerm: PropTypes.func,
  grouping: PropTypes.object,
  setGrouping: PropTypes.func,
  params: PropTypes.object,
  setParam: PropTypes.func,
  showTaxonGrouping: PropTypes.bool,
  place: PropTypes.object
};

PhotoBrowser.defaultProps = {
  layout: "fluid",
  terms: [],
  grouping: {},
  groupedPhotos: {},
  showTaxonGrouping: true
};

export default PhotoBrowser;
