import React, { useCallback, useMemo } from "react";
import _ from "lodash";
import {
  ButtonGroup,
  Button
} from "react-bootstrap";
import GroupedPhotos from "./grouped_photos";
import UngroupedPhotos from "./ungrouped_photos";
import FilterDropdown, { FilterOption } from "./filter_dropdown";
import { controlledTermLabel } from "../../../shared/util";
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
      return controlledTermLabel( terms[grouping.values][0].controlled_attribute.label );
    }
    return I18n.t( "none" );
  }, [grouping, terms] );
  // Grouping options use canonical string values matching grouping.param
  // ("taxon_id" / "terms:<id>"), plus a "none" sentinel, so a single
  // selected={grouping.param ?? "none"} drives the active highlight.
  const groupingOptions = useMemo( ( ) => {
    const items: FilterOption[] = [];
    if ( showTaxonGrouping ) {
      items.push( { value: "taxon_id", label: groupingDisplay( "taxon_id" ) } );
    }
    Object.values( terms ).forEach( values => {
      const attr = values[0].controlled_attribute;
      items.push( { value: `terms:${attr.id}`, label: controlledTermLabel( attr.label ) } );
    } );
    if ( items.length > 0 ) {
      items.unshift( { value: "none", label: groupingDisplay( null ) } );
    }
    return items;
  }, [showTaxonGrouping, terms, groupingDisplay] );

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
          { groupingOptions.length === 0 ? null : (
            <FilterDropdown
              id="grouping-control"
              label={I18n.t( "grouping" )}
              selected={grouping.param ?? "none"}
              options={groupingOptions}
              onSelect={( key: string | number ) => {
                if ( key === "none" ) {
                  setGrouping?.( null );
                } else if ( key === "taxon_id" ) {
                  setGrouping?.( "taxon_id" );
                } else if ( typeof key === "string" && key.startsWith( "terms:" ) ) {
                  const id = Number( key.slice( "terms:".length ) );
                  setGrouping?.( key, id );
                }
              }}
            />
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
              label: controlledTermLabel( v.controlled_value.label )
            } ) );
            return (
              <FilterDropdown
                key={`term-${attr.label}`}
                id={`term-chooser-${attr.label}`}
                label={controlledTermLabel( attr.label )}
                selected={isSelectedTerm ? selectedTermValue!.id : "any"}
                options={[{ value: "any", label: translatedAny }, ...termOptions]}
                onSelect={( key: string | number ) => setTerm?.( attr.id, key as string )}
              />
            );
          } ) }
          <FilterDropdown
            id="sort-control"
            label={I18n.t( "order_by" )}
            selected={params.order_by}
            options={[
              { value: "votes", label: orderByDisplay( "votes" ) },
              { value: "created_at", label: orderByDisplay( "created_at" ) }
            ]}
            onSelect={( key: string | number ) => setParam?.( "order_by", key as string )}
          />
          <FilterDropdown
            id="license-control"
            label={I18n.t( "photo_licensing" )}
            selected={params.photo_license ?? "any"}
            options={[
              { value: "any", label: I18n.t( "any_license" ) },
              ...licenseOptions
            ]}
            onSelect={( key: string | number ) => setParam?.( "photo_license", key as string )}
          />
          <FilterDropdown
            id="quality-grade-control"
            label={I18n.t( "quality_grade_" )}
            selected={params.quality_grade ?? "any"}
            options={[
              { value: "any", label: I18n.t( "any_quality_grade" ) },
              { value: "research", label: qualityGradeDisplay( "research" ) }
            ]}
            onSelect={( key: string | number ) => setParam?.( "quality_grade", key as string )}
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
