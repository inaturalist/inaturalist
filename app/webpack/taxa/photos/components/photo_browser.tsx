import React, { useCallback, useMemo } from "react";
import _ from "lodash";
import {
  ButtonGroup,
  Button,
  MenuItem
} from "react-bootstrap";
import GroupedPhotos from "./grouped_photos";
import UngroupedPhotos from "./ungrouped_photos";
import FilterDropdown from "./filter_dropdown";
import type {
  Config, Place, Taxon, ControlledAttribute, ControlledValue, TermValue
} from "../../../shared/types";
import type {
  ObservationPhoto, PhotoGroup, Grouping, Params, ShowTaxonPhotoModal
} from "./types";

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
  showTaxonPhotoModal: ShowTaxonPhotoModal;
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
  // The cc* licenses as ready-to-use dropdown options, sorted by display label.
  const licenseOptions = useMemo( ( ) => _.sortBy(
    Object.keys( iNaturalist.Licenses )
      .filter( k => k.startsWith( "cc" ) )
      .map( k => ( { value: k, label: licenseDisplay( k ) } ) ),
    "label"
  ), [] );

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
      Object.values( terms ).map( values => (
        <MenuItem
          key={`grouping-chooser-item-${values[0].controlled_attribute.label}`}
          eventKey={values[0].controlled_attribute}
          active={grouping.param === `terms:${values[0].controlled_attribute.id}`}
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

  const hasGroups = Object.keys( groupedPhotos ).length > 0;

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
            <FilterDropdown
              id="grouping-control"
              label={I18n.t( "grouping" )}
              display={groupingDisplay( grouping.param ?? null )}
              onSelect={( key: unknown ) => {
                if ( key === "none" ) {
                  setGrouping?.( null );
                } else if ( key === "taxon_id" ) {
                  setGrouping?.( "taxon_id" );
                } else if ( key && typeof key !== "string" ) {
                  setGrouping?.( `terms:${( key as ControlledAttribute ).id}`, ( key as ControlledAttribute ).id );
                }
              }}
            >
              { groupingMenuItems }
            </FilterDropdown>
          ) }
          { Object.values( terms ).map( values => {
            const attr = values[0].controlled_attribute;
            const isSelectedTerm = selectedTerm?.id === attr.id && !!selectedTermValue;
            const translatedAny = I18n.t(
              `controlled_term_labels.any_${_.snakeCase( attr.label )}`,
              {
                defaultValue: I18n.t( "any_annotation_attribute", {
                  defaultValue: I18n.t( "any" )
                } )
              }
            );
            const termOptions = values.map( v => ( {
              value: v.controlled_value.id,
              label: I18n.t(
                `controlled_term_labels.${_.snakeCase( v.controlled_value.label )}`,
                { defaultValue: v.controlled_value.label }
              )
            } ) );
            return (
              <FilterDropdown
                key={`term-${attr.label}`}
                id={`term-chooser-${attr.label}`}
                label={I18n.t( `controlled_term_labels.${_.snakeCase( attr.label )}`, { defaultValue: attr.label } )}
                display={isSelectedTerm
                  ? I18n.t(
                    `controlled_term_labels.${_.snakeCase( selectedTermValue!.label )}`,
                    { defaultValue: selectedTermValue!.label }
                  )
                  : translatedAny}
                selected={isSelectedTerm ? selectedTermValue!.id : undefined}
                options={[{ value: "any", label: translatedAny }, ...termOptions]}
                onSelect={( key: unknown ) => setTerm?.( attr.id, key as string )}
              />
            );
          } ) }
          <FilterDropdown
            id="sort-control"
            label={I18n.t( "order_by" )}
            display={orderByDisplay( params.order_by )}
            selected={params.order_by}
            options={[
              { value: "votes", label: orderByDisplay( "votes" ) },
              { value: "created_at", label: orderByDisplay( "created_at" ) }
            ]}
            onSelect={( key: unknown ) => setParam?.( "order_by", key as string )}
          />
          <FilterDropdown
            id="license-control"
            label={I18n.t( "photo_licensing" )}
            display={licenseDisplay( params.photo_license )}
            selected={params.photo_license}
            options={[
              { value: "any", label: I18n.t( "any_license" ) },
              ...licenseOptions
            ]}
            onSelect={( key: unknown ) => setParam?.( "photo_license", key as string )}
          />
          <FilterDropdown
            id="quality-grade-control"
            label={I18n.t( "quality_grade_" )}
            display={qualityGradeDisplay( params.quality_grade )}
            selected={params.quality_grade}
            options={[
              { value: "any", label: I18n.t( "any_quality_grade" ) },
              { value: "research", label: qualityGradeDisplay( "research" ) }
            ]}
            onSelect={( key: unknown ) => setParam?.( "quality_grade", key as string )}
          />
        </div>
      </div>
      <div>
        { hasGroups
          ? (
            <GroupedPhotos
              groupedPhotos={groupedPhotos}
              grouping={grouping}
              params={params}
              taxon={taxon}
              layout={layout}
              showTaxonPhotoModal={showTaxonPhotoModal}
              config={config}
            />
          )
          : (
            <UngroupedPhotos
              observationPhotos={observationPhotos}
              hasMorePhotos={hasMorePhotos}
              loadMorePhotos={loadMorePhotos}
              place={place}
              layout={layout}
              showTaxonPhotoModal={showTaxonPhotoModal}
              config={config}
            />
          ) }
      </div>
    </div>
  );
};

export default PhotoBrowser;
