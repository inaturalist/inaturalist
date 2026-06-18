import React, { useCallback, useMemo } from "react";
import InfiniteScroll from "react-infinite-scroller";
import _ from "lodash";
import {
  ButtonGroup,
  Button,
  MenuItem,
  Dropdown
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import { urlForTaxonPhotos } from "../../shared/util";
import type {
  Photo as BasePhoto, Taxon, Observation as BaseObservation, Config,
  Place, ControlledAttribute, ControlledValue, TermValue
} from "../../../shared/types";

type Photo = BasePhoto & {
  dimensions: () => { width: number; height: number } | null;
};

type Observation = BaseObservation & {
  taxon: Taxon;
};

interface ObservationPhoto {
  photo: Photo;
  observation: Observation;
}

interface GroupObject {
  id?: number;
  name?: string;
  label?: string;
  [key: string]: unknown;
}

interface PhotoGroup {
  groupName: string;
  groupObject: GroupObject;
  observationPhotos: ObservationPhoto[];
}

interface Grouping {
  param?: string;
  values?: number;
}

interface Params {
  order_by?: string;
  photo_license?: string;
  quality_grade?: string;
  [key: string]: unknown;
}

interface PhotoBrowserProps {
  config?: Config;
  groupedPhotos?: Record<string, PhotoGroup>;
  grouping?: Grouping;
  hasMorePhotos?: boolean;
  layout?: string;
  loadMorePhotos: () => void;
  observationPhotos?: ObservationPhoto[];
  params?: Params;
  place?: Place;
  selectedTerm?: ControlledAttribute;
  selectedTermValue?: ControlledValue;
  setGrouping?: ( param: string | null, values?: number ) => void;
  setLayout: ( layout: string ) => void;
  setParam?: ( key: string, value: string ) => void;
  setTerm?: ( attrId: number, valueId: string ) => void;
  showTaxonGrouping?: boolean;
  showTaxonPhotoModal: ( photo: Photo, taxon: Taxon, observation: Observation ) => void;
  taxon?: Taxon;
  terms?: Record<string, TermValue[]>;
}

const orderByDisplay = ( key: string | undefined ) => {
  if ( key === "created_at" ) {
    return I18n.t( "date_added" );
  }
  return I18n.t( "faves" );
};

const licenseDisplay = ( key: string | undefined ) => {
  if ( key && key.length > 0 ) {
    const licenseKey = _.snakeCase( key );
    return I18n.t( `${licenseKey}_name`, { defaultValue: key } );
  }
  return I18n.t( "any_license" );
};

const qualityGradeDisplay = ( key: string | undefined ) => {
  if ( key && key !== "any" ) {
    return I18n.t( "research_" );
  }
  return I18n.t( "any_quality_grade" );
};

const PhotoBrowser = ( {
  groupedPhotos = {},
  grouping = {},
  hasMorePhotos,
  layout = "fluid",
  loadMorePhotos,
  observationPhotos,
  params = {},
  setGrouping,
  setLayout,
  setParam,
  setTerm,
  showTaxonPhotoModal,
  selectedTerm,
  selectedTermValue,
  taxon,
  terms = {},
  showTaxonGrouping = true,
  place,
  config = {}
}: PhotoBrowserProps ) => {
  // Computed inline rather than memoized: the store mutates the groupedPhotos
  // container in place (groups are set empty, then re-set with photos once the
  // async fetch resolves) without changing its object identity, so memoizing on
  // [groupedPhotos] would strand the empty groups and never render the photos.
  const sortedGroupedPhotos = grouping.param === "taxon_id"
    ? _.sortBy( _.values( groupedPhotos ), group => group.groupObject.name )
    : _.sortBy( _.values( groupedPhotos ), "groupName" );

  const photoLicenses = useMemo( ( ) => _.sortBy(
    _.keys( _.pickBy( iNaturalist.Licenses, ( v, k ) => k.indexOf( "cc" ) === 0 ) ),
    k => I18n.t( `${_.snakeCase( k )}_name`, { defaultValue: k } )
  ), [] );

  const renderObservationPhotos = useCallback( ( obsPhotos: ObservationPhoto[] | undefined ) => (
    ( obsPhotos || [] ).map( observationPhoto => {
      let itemDim: number | undefined;
      let width: number | undefined;
      if ( layout === "fluid" ) {
        itemDim = 233;
        const dims = observationPhoto.photo.dimensions( );
        width = dims ? ( itemDim / dims.height ) * dims.width : itemDim;
      }
      return (
        <TaxonPhoto
          key={`taxon-photo-${observationPhoto.photo.id}`}
          photo={observationPhoto.photo}
          taxon={observationPhoto.observation.taxon}
          observation={observationPhoto.observation}
          width={width}
          height={itemDim}
          square={layout !== "fluid"}
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
  ), [layout, showTaxonPhotoModal, config] );

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
      { sortedGroupedPhotos.map( ( group, i ) => {
        const title = grouping.param === "taxon_id" && group.groupObject
          ? (
            <SplitTaxon
              taxon={group.groupObject}
              user={config.currentUser}
              url={urlForTaxonPhotos(
                group.groupObject,
                $.deparam( window.location.search.replace( /^\?/, "" ) )
              )}
            />
          )
          : I18n.t( `controlled_term_labels.${_.snakeCase( group.groupName )}`, {
            defaultValue: group.groupName
          } );
        let obsUrl;
        if ( group?.groupObject?.id ) {
          if ( grouping.param === "taxon_id" ) {
            const query = $.param( {
              ...params,
              taxon_id: group.groupObject.id
            } );
            obsUrl = `/observations?${query}`;
          } else if ( grouping.param?.match( /terms/ ) ) {
            const query = $.param( {
              ...params,
              taxon_id: taxon?.id,
              term_id: grouping.values,
              term_value_id: group.groupObject.id
            } );
            obsUrl = `/observations?${query}`;
          }
        }
        return (
          <div key={`group-${group.groupName}`} className={`photo-group ${i === 0 ? "first" : ""}`}>
            <div className="photo-group-header">
              <h3>{ title }</h3>
              { obsUrl && <a href={obsUrl}>{ I18n.t( "view_observations" ) }</a> }
            </div>
            <div className="photos">
              { group.observationPhotos.length === 0 ? (
                <div className="nocontent text-muted">{ I18n.t( "no_observations_yet" ) }</div>
              ) : null }
              { renderObservationPhotos( group.observationPhotos ) }
            </div>
          </div>
        );
      } ) }
    </div>
  );
  const groupingDisplay = useCallback( ( param: string | null ) => {
    if ( param === "taxon_id" ) {
      return I18n.t( "taxonomic" );
    }
    if ( param && grouping.values !== undefined && terms[grouping.values] ) {
      const displayText = terms[grouping.values][0].controlled_attribute.label;
      return I18n.t( `controlled_term_labels.${_.snakeCase( displayText )}`, { defaultValue: displayText } );
    }
    return I18n.t( "none" );
  }, [grouping, terms] );
  const groupingMenuItems = useMemo( ( ) => {
    let items: React.ReactNode[] = [];
    if ( showTaxonGrouping ) {
      items.push(
        <MenuItem
          key="grouping-menu-item-taxon-id"
          eventKey="taxon_id"
          active={grouping.param === "taxon_id"}
        >
          { groupingDisplay( "taxon_id" ) }
        </MenuItem>
      );
    }
    items = items.concat(
      _.map( terms, values => (
        <MenuItem
          key={`grouping-chooser-item-${values[0].controlled_attribute.label}`}
          eventKey={values[0].controlled_attribute}
          active={grouping.param === `field:${values[0].controlled_attribute.label}`}
        >
          { I18n.t(
            `controlled_term_labels.${_.snakeCase( values[0].controlled_attribute.label )}`,
            { defaultValue: values[0].controlled_attribute.label }
          ) }
        </MenuItem>
      ) )
    );
    if ( items.length > 0 ) {
      items.unshift(
        <MenuItem
          key="grouping-menu-item-none"
          eventKey="none"
          active={!grouping.param}
        >
          { groupingDisplay( null ) }
        </MenuItem>
      );
    }
    return items;
  }, [showTaxonGrouping, terms, grouping.param, groupingDisplay] );
  return (
    <div className={`PhotoBrowser ${layout}`}>
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
                onSelect={( key: string | ControlledAttribute ) => {
                  if ( key === "none" ) {
                    setGrouping?.( null );
                  } else if ( key === "taxon_id" ) {
                    setGrouping?.( "taxon_id" );
                  } else if ( typeof key !== "string" ) {
                    setGrouping?.( `terms:${key.id}`, key.id );
                  }
                }}
              >
                <Dropdown.Toggle bsStyle="link">
                  { I18n.t( "grouping" ) }
                  { ": " }
                  <strong>{ groupingDisplay( grouping.param ?? null ) }</strong>
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
                  onSelect={( key: string ) => setTerm?.( attr.id, key )}
                >
                  <Dropdown.Toggle bsStyle="link">
                    { I18n.t( `controlled_term_labels.${_.snakeCase( attr.label )}`, { defaultValue: attr.label } ) }
                    { ": " }
                    <strong>
                      {( selectedTerm && selectedTerm.id === attr.id && selectedTermValue
                        ? I18n.t(
                          `controlled_term_labels.${_.snakeCase( selectedTermValue.label )}`,
                          { defaultValue: selectedTermValue.label }
                        )
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
              onSelect={( key: string ) => {
                setParam?.( "order_by", key );
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
                  active={params.order_by === "created_at"}
                >
                  { orderByDisplay( "created_at" ) }
                </MenuItem>
              </Dropdown.Menu>
            </Dropdown>
          </span>
          <span className="control-group">
            <Dropdown
              id="license-control"
              onSelect={( key: string ) => { setParam?.( "photo_license", key ); }}
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
              onSelect={( key: string ) => {
                setParam?.( "quality_grade", key );
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
      <div>
        { sortedGroupedPhotos && sortedGroupedPhotos.length > 0
          ? renderGroupedPhotos( ) : renderUngroupedPhotos( ) }
      </div>
    </div>
  );
};

export default PhotoBrowser;
