/* global I18n, SITE */

import React, { Component } from "react";
import inatjs from "inaturalistjs";
import TaxaListContainer from "./containers/TaxaListContainer";
import TaxonDetailPanel from "./components/TaxonDetailPanel";

class IdSummariesDemoApp extends Component {
  constructor( props ) {
    super( props );
    this.state = {
      selectedSpecies: null,
      speciesImages: {},
      speciesImage: null,
      loading: false,
      error: null,
      tipVotes: {},
      referenceUsers: {}
    };

    this.reset = this.reset.bind( this );
    this.handleSpeciesClick = this.handleSpeciesClick.bind( this );
    this.handleVote = this.handleVote.bind( this );
    this.fetchReferenceUsers = this.fetchReferenceUsers.bind( this );

    this.pendingUserFetches = new Set();
  }

  photoUrlFromId( photoId, size = "square" ) {
    const id = Number( photoId );
    if ( !Number.isFinite( id ) || id <= 0 ) return null;
    return `https://inaturalist-open-data.s3.amazonaws.com/photos/${id}/${size}.jpg`;
  }

  buildSpeciesImageMap( list = [] ) {
    return list.reduce( ( acc, species ) => {
      if ( !species?.id ) return acc;
      const thumbUrl = species?.photoSquareUrl || this.photoUrlFromId( species?.taxonPhotoId, "square" );
      if ( thumbUrl ) {
        acc[species.id] = thumbUrl;
      }
      return acc;
    }, {} );
  }

  normalizeIncomingData( data ) {
    const normalizeTip = ( t = {} ) => ( {
      id: t?.id,
      text: t?.content || t?.tip || t?.summary || "",
      group: t?.key_visual_trait_group || t?.group || t?.visual_key_group || null,
      score: Number.isFinite( t?.score )
        ? t.score
        : Number.isFinite( t?.global_score )
          ? t.global_score
          : null,
      sources: Array.isArray( t?.sources )
        ? t.sources.map( s => ( {
          url: s?.url,
          comment_uuid: s?.comment_uuid,
          user_id: s?.user_id,
          body: s?.body,
          created_at: s?.reference_date || s?.created_at || s?.updated_at || null,
          reference_source: s?.reference_source || s?.source || null,
          reference_uuid: s?.reference_uuid || s?.comment_uuid || null
        } ) )
        : Array.isArray( t?.references )
          ? t.references.map( r => ( {
            url: r?.url,
            comment_uuid: r?.comment_uuid,
            user_id: r?.user_id,
            body: r?.body || r?.reference_content,
            created_at: r?.reference_date || r?.created_at || r?.reference_created_at || r?.updated_at || null,
            reference_source: r?.reference_source || r?.source || null,
            reference_uuid: r?.reference_uuid || r?.comment_uuid || null
          } ) )
          : []
    } );

    if ( !Array.isArray( data ) ) return [];

    return data.map( item => {
      const rawTips = Array.isArray( item?.tips )
        ? item.tips
        : Array.isArray( item?.id_summaries )
          ? item.id_summaries
          : [];
      return {
        id: item?.taxon_id,
        uuid: item?.uuid,
        name: item?.taxon_name || item?.name,
        commonName: item?.taxon_common_name?.name || item?.taxon_common_name || null,
        taxonGroup: item?.taxon_group || null,
        runGeneratedAt: item?.run_generated_at || null,
        taxonPhotoId: item?.taxon_photo_id,
        photoSquareUrl: this.photoUrlFromId( item?.taxon_photo_id, "square" ),
        photoMediumUrl: this.photoUrlFromId( item?.taxon_photo_id, "medium" ),
        tips: rawTips.map( normalizeTip )
      };
    } );
  }

  fetchReferenceUsers( species ) {
    if ( !species || !Array.isArray( species.tips ) ) return;
    const allSources = species.tips.flatMap( t => ( Array.isArray( t.sources ) ? t.sources : [] ) );
    const userIds = [
      ...new Set(
        allSources
          .map( s => s?.user_id )
          .filter( id => Number.isInteger( id ) )
      )
    ];
    if ( userIds.length === 0 ) return;

    const missing = userIds.filter( id => !this.state.referenceUsers[id] && !this.pendingUserFetches.has( id ) );
    if ( missing.length === 0 ) return;

    missing.forEach( id => {
      this.pendingUserFetches.add( id );
      inatjs.users.fetch( id, {
        fields: "id,login,name,icon_url,medium_user_icon_url,large_user_icon_url,user_icon_url"
      } )
        .then( response => {
          const user = response?.results?.[0];
          if ( !user ) return;
          const icon = user?.icon_url
            || user?.medium_user_icon_url
            || user?.user_icon_url
            || user?.large_user_icon_url
            || null;
          this.setState( prev => ( {
            referenceUsers: {
              ...prev.referenceUsers,
              [id]: {
                id: user.id,
                login: user.login,
                name: user.name || user.login,
                icon
              }
            }
          } ) );
        } )
        .catch( err => {
          console.warn( `Failed to fetch user ${id}`, err );
        } )
        .finally( () => {
          this.pendingUserFetches.delete( id );
        } );
    } );
  }

  handleSpeciesClick( species ) {
    this.setState( prev => {
      const squareUrl = species?.photoSquareUrl || this.photoUrlFromId( species?.taxonPhotoId, "square" );
      const mediumUrl = species?.photoMediumUrl || this.photoUrlFromId( species?.taxonPhotoId, "medium" );
      const cachedImage = species?.id ? prev.speciesImages?.[species.id] : null;
      const updatedImages = squareUrl
        ? { ...prev.speciesImages, [species.id]: squareUrl }
        : prev.speciesImages;
      return {
        selectedSpecies: species,
        speciesImages: updatedImages,
        speciesImage: mediumUrl || squareUrl || cachedImage || null,
        loading: true,
        error: null
      };
    } );
    this.fetchReferenceUsers( species );
    if ( !species?.uuid ) {
      this.setState( {
        loading: false,
        error: I18n.t( "id_summaries.demo.app.missing_identifier" )
      } );
      return;
    }

    const summaryFields = [
      "uuid",
      "taxon_name",
      "taxon_common_name",
      "taxon_photo_id",
      "run_generated_at",
      "id_summaries",
      "id_summaries.id",
      "id_summaries.summary",
      "id_summaries.score",
      "id_summaries.visual_key_group",
      "id_summaries.references.url",
      "id_summaries.references.comment_uuid",
      "id_summaries.references.user_id",
      "id_summaries.references.body",
      "id_summaries.references.reference_content",
      "id_summaries.references.reference_source",
      "id_summaries.references.reference_uuid",
      "id_summaries.references.reference_date",
      "id_summaries.references.created_at",
      "id_summaries.references.updated_at"
    ].join( "," );

    const taxonIdSummariesAPI = inatjs?.taxon_id_summaries;
    if ( !taxonIdSummariesAPI || typeof taxonIdSummariesAPI.fetch !== "function" ) {
      this.setState( {
        loading: false,
        error: I18n.t( "id_summaries.demo.app.service_unavailable" )
      } );
      return;
    }
    taxonIdSummariesAPI.fetch( species.uuid, { fields: summaryFields } )
      .then( response => {
        const result = response?.results?.[0];
        if ( !result ) {
          this.setState( {
            loading: false,
            error: I18n.t( "id_summaries.demo.app.no_summary_data" )
          } );
          return;
        }
        const [normalized] = this.normalizeIncomingData( [result] );
        const normalizedSpecies = normalized || species;
        this.setState( prev => {
          const squareUrl = normalizedSpecies?.photoSquareUrl
            || this.photoUrlFromId( normalizedSpecies?.taxonPhotoId, "square" );
          const mediumUrl = normalizedSpecies?.photoMediumUrl
            || this.photoUrlFromId( normalizedSpecies?.taxonPhotoId, "medium" );
          const updatedImages = squareUrl
            ? { ...prev.speciesImages, [normalizedSpecies.id]: squareUrl }
            : prev.speciesImages;
          const fallbackImage = mediumUrl
            || squareUrl
            || updatedImages?.[normalizedSpecies?.id]
            || prev.speciesImage
            || null;
          return {
            selectedSpecies: normalizedSpecies,
            speciesImage: fallbackImage,
            speciesImages: updatedImages,
            loading: false,
            error: null
          };
        }, () => {
          this.fetchReferenceUsers( normalizedSpecies );
        } );
      } )
      .catch( error => {
        // eslint-disable-next-line no-console
        console.error( "inatjs.taxon_id_summaries.fetch failed", error );
        this.setState( prev => ( {
          selectedSpecies: species,
          speciesImage:
            prev.selectedSpecies?.id === species?.id
              ? prev.speciesImage
                || prev.speciesImages?.[species?.id]
                || species?.photoMediumUrl
                || species?.photoSquareUrl
                || this.photoUrlFromId( species?.taxonPhotoId, "medium" )
                || this.photoUrlFromId( species?.taxonPhotoId, "square" )
                || null
              : prev.speciesImages?.[species?.id]
                || species?.photoSquareUrl
                || this.photoUrlFromId( species?.taxonPhotoId, "square" )
                || null,
          loading: false,
          error: I18n.t( "id_summaries.demo.app.load_failed" )
        } ) );
      } );
  }

  reset() {
    this.setState( {
      selectedSpecies: null,
      speciesImage: null,
      loading: false,
      error: null
    } );
  }

  handleVote( speciesId, tipIndex, value ) {
    this.setState( prev => {
      const current = prev.tipVotes?.[speciesId]?.[tipIndex] || 0;
      const nextValue = current === value ? 0 : value;
      const speciesVotes = { ...( prev.tipVotes[speciesId] || {} ), [tipIndex]: nextValue };
      return { tipVotes: { ...prev.tipVotes, [speciesId]: speciesVotes } };
    } );
  }

  header() {
    return (
      <nav className="navbar navbar-default">
        <div className="container">
          <div className="navbar-header">
            <div className="logo">
              <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                <img alt="Site Logo" src="https://static.inaturalist.org/sites/1-logo.svg" />
              </a>
            </div>
            <div className="title">
              <a
                href="/field_guide"
                onClick={e => {
                  e.preventDefault();
                  this.reset();
                }}
              >
                {I18n.t( "id_summaries.demo.app.header_link" )}
              </a>
            </div>
          </div>
        </div>
      </nav>
    );
  }

  infoSection() {
    return (
      <div className="fg-info-band">
        <p className="fg-info-text">
          {I18n.t( "id_summaries.demo.app.info_line_one" )}
          <br />
          {I18n.t( "id_summaries.demo.app.info_line_two" )}
          {" "}
          <a href="/blog">{I18n.t( "id_summaries.demo.app.blog_link_text" )}</a>
          .
        </p>
      </div>
    );
  }

  render() {
    const {
      selectedSpecies,
      speciesImages,
      speciesImage,
      loading,
      error,
      tipVotes,
      referenceUsers
    } = this.state;
    const votesForSelected = selectedSpecies ? tipVotes?.[selectedSpecies.id] : {};

    return (
      <div className="bootstrap fg-app">
        {this.header()}
        {this.infoSection()}

        <div className="container">
          <div className="fg-layout">
            <div className="fg-sidebar">
              <TaxaListContainer
                selectedId={selectedSpecies?.id}
                images={speciesImages}
                onTileClick={this.handleSpeciesClick}
                onLoaded={list => {
                  const mapped = this.buildSpeciesImageMap( list );
                  if ( Object.keys( mapped ).length ) {
                    this.setState( prev => ( {
                      speciesImages: { ...prev.speciesImages, ...mapped }
                    } ) );
                  }
                }}
              />
            </div>
            <div className="fg-main">
              <TaxonDetailPanel
                species={selectedSpecies}
                imageUrl={speciesImage}
                isSummaryLoading={loading}
                error={error}
                tipVotes={votesForSelected}
                referenceUsers={referenceUsers}
                onVote={this.handleVote}
              />
            </div>
          </div>
        </div>

        {this.footer?.()}
      </div>
    );
  }
}

export default IdSummariesDemoApp;
