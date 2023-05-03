import React from "react";
import PropTypes from "prop-types";
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
  selectedTerm,
  selectedTermValue,
  terms,
  showTaxonGrouping,
  place,
  config
} ) => {
  let sortedGroupedPhotos;
  if ( grouping.param === "taxon_id" ) {
    sortedGroupedPhotos = _.sortBy( _.values( groupedPhotos ), group => group.groupObject.name );
  } else {
    sortedGroupedPhotos = _.sortBy( _.values( groupedPhotos ), "groupName" );
  }
  const photoLicenses = _.sortBy(
    _.keys( _.pickBy( iNaturalist.Licenses, ( v, k ) => k.indexOf( "cc" ) === 0 ) ),
    k => I18n.t( `${_.snakeCase( k )}_name`, { defaultValue: k } )
  );
  const renderObservationPhotos = obsPhotos => (
    ( obsPhotos || [] ).map( observationPhoto => {
      let itemDim = 183;
      let width = itemDim;
      if ( layout === "fluid" ) {
        itemDim += 50;
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
          showTaxonPhotoModal={( ) => showTaxonPhotoModal(
            observationPhoto.photo,
            observationPhoto.observation.taxon,
            observationPhoto.observation
          )}
          showTaxon
          linkTaxon
          config={config}
        />
      );
    } )
  );
  const loader = (
    <div key="photo-browser-loader" className="loading">
      <i className="fa fa-refresh fa-spin" />
    </div>
  );
  const noObsNotice = (
    <div key="photo-browser-no-obs-notice" className="nocontent text-muted">
      { I18n.t( place ? "no_observations_from_this_place_yet" : "no_observations_yet" ) }
    </div>
  );
  const renderUngroupedPhotos = ( ) => (
    <InfiniteScroll
      loadMore={( ) => loadMorePhotos( )}
      hasMore={hasMorePhotos}
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
      { sortedGroupedPhotos.map( ( group, i ) => (
        <div key={`group-${group.groupName}`} className={`photo-group ${i === 0 ? "first" : ""}`}>
          <h3>
            { group.groupObject ? (
              <SplitTaxon
                taxon={group.groupObject}
                user={config.currentUser}
                url={urlForTaxonPhotos(
                  group.groupObject,
                  $.deparam( window.location.search.replace( /^\?/, "" ) )
                )}
              />
            ) : I18n.t( `controlled_term_labels.${_.snakeCase( group.groupName )}`, { defaultValue: group.groupName } ) }
          </h3>
          <div className="photos">
            { group.observationPhotos.length === 0 ? (
              <div className="nocontent text-muted">{ I18n.t( "no_observations_yet" ) }</div>
            ) : null }
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
  const licenseDisplay = key => {
    if ( key && key.length > 0 ) {
      const licenseKey = _.snakeCase( key );
      return I18n.t( `${licenseKey}_name`, { defaultValue: key } );
    }
    return I18n.t( "any_license" );
  };
  const qualityGradeDisplay = key => {
    if ( key && key !== "any" ) {
      return I18n.t( "research_" );
    }
    return I18n.t( "any_quality_grade" );
  };
  const groupingDisplay = param => {
    if ( param === "taxon_id" ) {
      return I18n.t( "taxonomic" );
    }
    if ( param && terms[grouping.values] ) {
      const displayText = terms[grouping.values][0].controlled_attribute.label;
      return I18n.t( `controlled_term_labels.${_.snakeCase( displayText )}`, { defaultValue: displayText } );
    }
    return I18n.t( "none" );
  };
  let groupingMenuItems = [];
  if ( showTaxonGrouping ) {
    groupingMenuItems.push(
      <MenuItem
        key="grouping-menu-item-taxon-id"
        eventKey="taxon_id"
        active={grouping.param === "taxon_id"}
      >
        { groupingDisplay( "taxon_id" ) }
      </MenuItem>
    );
  }
  groupingMenuItems = groupingMenuItems.concat(
    _.map( terms, values => (
      <MenuItem
        key={`grouping-chooser-item-${values[0].controlled_attribute.label}`}
        eventKey={values[0].controlled_attribute}
        active={grouping.param === `field:${values[0].controlled_attribute.label}`}
      >
        { I18n.t( `controlled_term_labels.${_.snakeCase( values[0].controlled_attribute.label )}`,
          { defaultValue: values[0].controlled_attribute.label } ) }
      </MenuItem>
    ) )
  );
  if ( groupingMenuItems.length > 0 ) {
    groupingMenuItems.unshift(
      <MenuItem
        key="grouping-menu-item-none"
        eventKey="none"
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
            <ButtonGroup className="control-group" id="layout-control">
              <Button
                active={layout === "fluid"}
                title={I18n.t( "fluid_layout" )}
                onClick={( ) => setLayout( "fluid" )}
              >
                <i className="icon-photo-quilt" />
              </Button>
              <Button
                active={layout === "grid"}
                title={I18n.t( "grid_layout" )}
                onClick={( ) => setLayout( "grid" )}
              >
                <i className="icon-photo-grid" />
              </Button>
            </ButtonGroup>
            <div id="filters">
              { groupingMenuItems.length === 0 ? null : (
                <span className="control-group">
                  <Dropdown
                    id="grouping-control"
                    onSelect={key => {
                      if ( key === "none" ) {
                        setGrouping( null );
                      } else if ( key === "taxon_id" ) {
                        setGrouping( "taxon_id" );
                      } else {
                        setGrouping( `terms:${key.id}`, key.id );
                      }
                    }}
                  >
                    <Dropdown.Toggle bsStyle="link">
                      { I18n.t( "grouping" ) }
                      { ": " }
                      <strong>{ groupingDisplay( grouping.param ) }</strong>
                    </Dropdown.Toggle>
                    <Dropdown.Menu>
                      { groupingMenuItems }
                    </Dropdown.Menu>
                  </Dropdown>
                </span>
              ) }
              { _.map( terms, values => {
                const attr = values[0].controlled_attribute;
                const translatedAny = I18n.t(
                  `controlled_term_labels.any_${_.snakeCase( attr.label )}`,
                  {
                    defaultValue: I18n.t( "any_annotation_attribute", {
                      defaultValue: I18n.t( "any" )
                    } )
                  }
                );
                return (
                  <span key={`term-${attr.label}`} className="control-group">
                    <Dropdown
                      id={`term-chooser-${attr.label}`}
                      onSelect={key => setTerm( attr.id, key )}
                    >
                      <Dropdown.Toggle bsStyle="link">
                        { I18n.t( `controlled_term_labels.${_.snakeCase( attr.label )}`, { defaultValue: attr.label } ) }
                        { ": " }
                        <strong>
                          {( selectedTerm && selectedTerm.id === attr.id && selectedTermValue
                            ? I18n.t( `controlled_term_labels.${_.snakeCase( selectedTermValue.label )}`,
                              { defaultValue: selectedTermValue.label } )
                            : translatedAny
                          ) }
                        </strong>
                      </Dropdown.Toggle>
                      <Dropdown.Menu>
                        <MenuItem
                          key={`term-chooser-item-${attr.label}-any`}
                          eventKey="any"
                          active={!selectedTermValue}
                        >
                          { translatedAny }
                        </MenuItem>
                        { values.map( v => {
                          const value = v.controlled_value;
                          return (
                            <MenuItem
                              key={`term-chooser-item-${attr.label}-${value.label}`}
                              eventKey={value.id}
                              active={selectedTermValue && selectedTermValue.id === value.id}
                            >
                              { I18n.t( `controlled_term_labels.${_.snakeCase( value.label )}`, { defaultValue: value.label } ) }
                            </MenuItem>
                          );
                        } ) }
                      </Dropdown.Menu>
                    </Dropdown>
                  </span>
                );
              } ) }
              <span className="control-group">
                <Dropdown
                  id="sort-control"
                  onSelect={key => {
                    setParam( "order_by", key );
                  }}
                >
                  <Dropdown.Toggle bsStyle="link">
                    { I18n.t( "order_by" ) }
                    { ": " }
                    <strong>{ orderByDisplay( params.order_by ) }</strong>
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
                    <MenuItem
                      eventKey="votes"
                      active={params.order_by === "votes"}
                    >
                      { orderByDisplay( "votes" ) }
                    </MenuItem>
                    <MenuItem
                      eventKey="created_at"
                      active={grouping === "created_at"}
                    >
                      { orderByDisplay( "created_at" ) }
                    </MenuItem>
                  </Dropdown.Menu>
                </Dropdown>
              </span>
              <span className="control-group">
                <Dropdown
                  id="license-control"
                  onSelect={key => { setParam( "photo_license", key ); }}
                >
                  <Dropdown.Toggle bsStyle="link">
                    { I18n.t( "photo_licensing" ) }
                    { ": " }
                    <strong>{ licenseDisplay( params.photo_license ) }</strong>
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
                    <MenuItem
                      key="license-chooser-any"
                      eventKey="any"
                      active={!params.photo_license}
                    >
                      { I18n.t( "any_license" ) }
                    </MenuItem>
                    { _.map( photoLicenses, k => (
                      <MenuItem
                        key={`license-chooser-${k}`}
                        eventKey={k}
                        active={params.photo_license === k}
                      >
                        { licenseDisplay( k ) }
                      </MenuItem>
                    ) ) }
                  </Dropdown.Menu>
                </Dropdown>
              </span>
              <span className="control-group">
                <Dropdown
                  id="quality-grade-control"
                  onSelect={key => {
                    setParam( "quality_grade", key );
                  }}
                >
                  <Dropdown.Toggle bsStyle="link">
                    { I18n.t( "quality_grade_" ) }
                    { ": " }
                    <strong>{ qualityGradeDisplay( params.quality_grade ) }</strong>
                  </Dropdown.Toggle>
                  <Dropdown.Menu>
                    <MenuItem
                      key="quality-grade-chooser-any"
                      eventKey="any"
                      active={!params.quality_grade}
                    >
                      { I18n.t( "any_quality_grade" ) }
                    </MenuItem>
                    <MenuItem
                      key="quality-grade-chooser-research"
                      eventKey="research"
                      active={params.quality_grade === "research"}
                    >
                      { qualityGradeDisplay( "research" ) }
                    </MenuItem>
                  </Dropdown.Menu>
                </Dropdown>
              </span>
            </div>
          </div>
        </Col>
      </Row>
      <Row>
        <Col xs={12}>
          { sortedGroupedPhotos && sortedGroupedPhotos.length > 0
            ? renderGroupedPhotos( ) : renderUngroupedPhotos( ) }
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
  selectedTerm: PropTypes.object,
  selectedTermValue: PropTypes.object,
  terms: PropTypes.object,
  setTerm: PropTypes.func,
  grouping: PropTypes.object,
  setGrouping: PropTypes.func,
  params: PropTypes.object,
  setParam: PropTypes.func,
  showTaxonGrouping: PropTypes.bool,
  place: PropTypes.object,
  config: PropTypes.object
};

PhotoBrowser.defaultProps = {
  layout: "fluid",
  terms: {},
  grouping: {},
  groupedPhotos: {},
  showTaxonGrouping: true,
  config: {}
};

export default PhotoBrowser;
