import React, { useState, useEffect } from "react";
import CoverImage from "../../../shared/components/cover_image";
import { urlForTaxonPhotos } from "../../shared/util";
import TaxonPhoto from "../../../shared/components/taxon_photo";

interface Photo {
  id: number;
  photoUrl: ( size?: string ) => string;
  dimensions: ( ) => { width: number; height: number } | null | undefined;
}

interface Taxon {
  id: number;
  name: string;
  [key: string]: unknown;
}

interface TaxonPhotoEntry {
  photo: Photo;
  taxon: Taxon;
}

interface CurrentUser {
  content_creation_restrictions?: boolean;
  [key: string]: unknown;
}

interface Props {
  taxon: Taxon;
  taxonPhotos: TaxonPhotoEntry[];
  layout?: string;
  showTaxonPhotoModal?: ( photo: Photo, taxon: Taxon, observation?: unknown ) => void;
  showPhotoChooserModal?: ( ) => void;
  showNewTaxon?: ( taxon: Taxon ) => void;
  config?: { currentUser?: CurrentUser; [key: string]: unknown };
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
  const [current, setCurrent] = useState<TaxonPhotoEntry | undefined>( undefined );
  const [taxonPhotos, setTaxonPhotos] = useState<TaxonPhotoEntry[]>( [] );

  useEffect( ( ) => {
    const sliced = layout === "gallery"
      ? taxonPhotosProp.slice( 0, 5 )
      : taxonPhotosProp.slice( 0, 8 );
    setTaxonPhotos( sliced );
    setCurrent( taxonPhotosProp[0] );
  }, [taxonPhotosProp, layout] );

  const showPhoto = ( photoId: number ) => {
    const found = taxonPhotos.find( p => p.photo.id === photoId );
    if ( found ) setCurrent( found );
  };

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

  if ( current && layout === "gallery" ) {
    const { photo } = current;
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
          style={{ backgroundImage: `url('${current.photo.photoUrl( "small" )}')` }}
        />
      );
    }
    currentPhoto = (
      <TaxonPhoto
        taxon={taxon}
        photo={photo as any}
        size="large"
        showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
        height={currentPhotoHeight}
        backgroundSize={backgroundSize}
        config={config}
      />
    );
  }

  const displayPhotos = taxonPhotos.length === 1 ? [] : taxonPhotos;

  return (
    <div className={`PhotoPreview ${layout}${layout === "gallery" && backgroundSize === "cover" ? " cover-bg" : ""}`}>
      { bgImage }
      <div className="foreground-container">
        { currentPhoto }
        <ul className="plain others">
          { displayPhotos.map( tp => {
            let content: React.ReactNode;
            if ( layout === "grid" ) {
              content = (
                <TaxonPhoto
                  photo={tp.photo as any}
                  height={thumbnailHeight}
                  taxon={tp.taxon}
                  size="medium"
                  showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
                  className="photoItem"
                  showTaxon
                  linkTaxon={tp.taxon.id !== taxon.id}
                  onClickTaxon={newTaxon => showNewTaxon?.( newTaxon )}
                  config={config}
                />
              );
            } else {
              content = (
                <a
                  className="photoItem"
                  href={tp.photo.photoUrl( )}
                  aria-label={I18n.t( "view_photo" )}
                  onClick={e => {
                    e.preventDefault( );
                    showPhoto( tp.photo.id );
                    return false;
                  }}
                >
                  <CoverImage
                    src={tp.photo.photoUrl( "small" )}
                    low={tp.photo.photoUrl( "small" )}
                    height={thumbnailHeight}
                  />
                </a>
              );
            }
            return (
              <li key={`taxon-photo-${tp.taxon.id}-${tp.photo.id}`}>
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
