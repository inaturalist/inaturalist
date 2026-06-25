import React from "react";
import _ from "lodash";
import SplitTaxon from "../../../shared/components/split_taxon";
import ObservationPhotos from "./observation_photos";
import { urlForTaxonPhotos } from "../../shared/util";
import { controlledTermLabel } from "../../../shared/util";
import type { Config, Taxon } from "../../../shared/types";
import type {
  PhotoGroup, Grouping, Params, ShowTaxonPhotoModal
} from "./types";

interface GroupedPhotosProps {
  groupedPhotos: Record<string, PhotoGroup>;
  grouping: Grouping;
  params: Params;
  taxon?: Taxon;
  layout: string;
  showTaxonPhotoModal: ShowTaxonPhotoModal;
  config?: Config;
}

const GroupedPhotos = ( {
  groupedPhotos,
  grouping,
  params,
  taxon,
  layout,
  showTaxonPhotoModal,
  config = {}
}: GroupedPhotosProps ) => {
  // Do not memoize - groupedPhotos is mutated in place, so its identity does not
  // change when groups are filled with photos. Memoizing on it would strand the
  // initial empty groups, so photos would never appear when grouping is selected.
  const sortedGroupedPhotos = grouping.param === "taxon_id"
    ? _.sortBy( Object.values( groupedPhotos ), group => group.groupObject.name )
    : _.sortBy( Object.values( groupedPhotos ), "groupName" );

  return (
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
          : controlledTermLabel( group.groupName );
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
              <ObservationPhotos
                observationPhotos={group.observationPhotos}
                layout={layout}
                showTaxonPhotoModal={showTaxonPhotoModal}
                config={config}
              />
            </div>
          </div>
        );
      } ) }
    </div>
  );
};

export default GroupedPhotos;
