import React, { useState, useMemo } from "react";
import CoverImage from "../../../shared/components/cover_image";
import { urlForTaxonPhotos } from "../../shared/util";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import type {
  Photo, Taxon, Observation, Config
} from "../../../shared/types";

// On this page `dimensions()` is guaranteed by the inaturalistjs Photo model.
type PreviewPhoto = Photo & {
  dimensions: ( ) => { width: number; height: number } | null | undefined;
};

interface TaxonPhotoEntry {
  photo: PreviewPhoto;
  taxon: Taxon;
}

interface Props {
  taxon: Taxon;
  taxonPhotos: TaxonPhotoEntry[];
  layout?: string;
  showTaxonPhotoModal?: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  showPhotoChooserModal?: ( ) => void;
  showNewTaxon?: ( taxon: Taxon ) => void;
  config?: Config;
}

const PhotoPreview = ( {
  taxon,
  taxonPhotos: taxonPhotosProp,
  layout,
  showTaxonPhotoModal,
  showPhotoChooserModal,
  showNewTaxon,
  config = {}
}: Props ) => {
  const [currentPhotoIdx, setCurrentPhotoIdx] = useState<number>( 0 );

  const taxonPhotos = useMemo( ( ) => (
    layout === "gallery"
      ? taxonPhotosProp.slice( 0, 5 )
      : taxonPhotosProp.slice( 0, 8 )
  ), [taxonPhotosProp, layout] );

  const thumbnailHeight = layout === "gallery" ? 98 : 196.5;
  const { currentUser } = config;

  if ( taxonPhotos.length === 0 ) {
    return (
      <div className="PhotoPreview no-content text-center text-muted">
        <div>
          <h3>
            { I18n.t( "this_taxon_has_no_default_photo" ) }
          </h3>
          { !currentUser?.content_creation_restrictions && (
            <button
              type="button"
              className="btn btn-primary"
              onClick={( ) => showPhotoChooserModal?.( )}
            >
              { I18n.t( "add_one_now" ) }
            </button>
          ) }
        </div>
      </div>
    );
  }

  let currentPhoto: React.ReactNode;
  let bgImage: React.ReactNode;
  let currentPhotoHeight = 590;
  let backgroundSize = "cover";

  if ( taxonPhotos[currentPhotoIdx] && layout === "gallery" ) {
    const { photo } = taxonPhotos[currentPhotoIdx];
    const dims = photo.dimensions( );
    let ratio = 1;
    if ( dims && dims.height ) {
      ratio = dims.width / dims.height;
    }
    if ( ratio > 1.3 ) {
      backgroundSize = "contain";
    }
    if ( backgroundSize === "contain" ) {
      currentPhotoHeight = 500;
      bgImage = (
        <div
          className="photo-bg"
          style={{ backgroundImage: `url('${photo.photoUrl( "small" )}')` }}
        />
      );
    }
    currentPhoto = (
      <TaxonPhoto
        taxon={taxon}
        photo={photo}
        size="large"
        showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
        height={currentPhotoHeight}
        backgroundSize={backgroundSize}
        config={config}
      />
    );
  }

  const displayPhotos = taxonPhotos.length === 1 ? [] : taxonPhotos;

  // TODO: split render between grid and gallery
  return (
    <div className={`PhotoPreview ${layout}${layout === "gallery" && backgroundSize === "cover" ? " cover-bg" : ""}`}>
      { bgImage }
      <div className="foreground-container">
        { currentPhoto }
        <ul className="plain others">
          { displayPhotos.map( ( taxonPhoto, idx ) => {
            // TODO: Modernize
            let content: React.ReactNode;
            if ( layout === "grid" ) {
              content = (
                <TaxonPhoto
                  photo={taxonPhoto.photo}
                  height={thumbnailHeight}
                  taxon={taxonPhoto.taxon}
                  size="medium"
                  square={false}
                  showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
                  className="photoItem"
                  showTaxon
                  linkTaxon={taxonPhoto.taxon.id !== taxon.id}
                  onClickTaxon={newTaxon => showNewTaxon?.( newTaxon )}
                  config={config}
                />
              );
            } else {
              content = (
                <a
                  className="photoItem"
                  href={taxonPhoto.photo.photoUrl( )}
                  aria-label={I18n.t( "view_photo" )}
                  onClick={e => {
                    e.preventDefault( );
                    setCurrentPhotoIdx( idx );
                    return false;
                  }}
                >
                  <CoverImage
                    src={taxonPhoto.photo.photoUrl( "small" )}
                    low={taxonPhoto.photo.photoUrl( "small" )}
                    height={thumbnailHeight}
                  />
                </a>
              );
            }
            return (
              <li key={`taxon-photo-${taxonPhoto.taxon.id}-${taxonPhoto.photo.id}`}>
                { content }
              </li>
            );
          } ) }
          <li className="viewmore">
            <a
              href={urlForTaxonPhotos( taxon )}
              style={{ height: layout === "grid" ? `${thumbnailHeight}px` : "inherit" }}
            >
              <span className="inner">
                <span>{ I18n.t( "view_more" ) }</span>
                <i className="fa fa-arrow-circle-right" />
              </span>
            </a>
          </li>
        </ul>
      </div>
    </div>
  );
};

export default PhotoPreview;
