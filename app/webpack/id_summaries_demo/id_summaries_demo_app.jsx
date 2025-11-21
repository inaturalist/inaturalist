/* global I18n, SITE, CURRENT_USER */

import React, { Component } from "react";
import inatjs from "inaturalistjs";
import TaxaListContainer from "./containers/TaxaListContainer";
import TaxonDetailPanel from "./components/TaxonDetailPanel";
import { LANGUAGE_OPTIONS } from "./constants/languages";
import {
  determineDefaultSpecies,
  loadGroupLabels,
  getFallbackGroupLabel
} from "./utils/taxaGrouping";

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
      referenceUsers: {},
      activeOnly: true,
      selectedRunName: null,
      runNames: [],
      runNamesLoading: false,
      showPhotoTips: false,
      selectedLanguage: LANGUAGE_OPTIONS[0]?.value || "en"
    };
    this.currentUserIsAdmin = IdSummariesDemoApp.userIsAdmin();
    this.adminExtrasEnabled = this.currentUserIsAdmin
      && IdSummariesDemoApp.adminExtrasRequested();
    const hashTarget = IdSummariesDemoApp.hashTargetFromLocation();
    this.hashSelectedTaxonId = hashTarget?.id || null;
    this.hashSelectedTaxonSlug = hashTarget?.slug || null;
    this.latestLoadedTaxa = [];

    this.reset = this.reset.bind( this );
    this.handleSpeciesClick = this.handleSpeciesClick.bind( this );
    this.handleVote = this.handleVote.bind( this );
    this.fetchReferenceUsers = this.fetchReferenceUsers.bind( this );
    this.handleActiveToggle = this.handleActiveToggle.bind( this );
    this.handleRunNameChange = this.handleRunNameChange.bind( this );
    this.handlePhotoTipsToggle = this.handlePhotoTipsToggle.bind( this );
    this.fetchRunNames = this.fetchRunNames.bind( this );
    this.renderFilters = this.renderFilters.bind( this );
    this.handleLanguageChange = this.handleLanguageChange.bind( this );
    this.renderLanguagePicker = this.renderLanguagePicker.bind( this );
    this.handleHashChange = this.handleHashChange.bind( this );
    this.trySelectSpeciesFromHash = this.trySelectSpeciesFromHash.bind( this );
    this.updateLocationHash = this.updateLocationHash.bind( this );

    this.pendingUserFetches = new Set();
    this.groupingOptions = {
      groupLabels: loadGroupLabels(),
      fallbackGroupLabel: getFallbackGroupLabel()
    };
  }

  static userIsAdmin() {
    if ( typeof CURRENT_USER === "undefined" || !CURRENT_USER ) {
      return false;
    }
    const { roles } = CURRENT_USER;
    return Array.isArray( roles ) && roles.includes( "admin" );
  }

  static slugifyTaxonName( name ) {
    if ( typeof name !== "string" ) return null;
    const normalized = name.normalize ? name.normalize( "NFD" ) : name;
    const withoutMarks = normalized.replace( /[\u0300-\u036f]/g, "" );
    const slug = withoutMarks
      .toLowerCase()
      .replace( /[^a-z0-9]+/g, "-" )
      .replace( /-{2,}/g, "-" )
      .replace( /^-+|-+$/g, "" );
    return slug || null;
  }

  static hashTargetFromLocation( hashString ) {
    if ( typeof window === "undefined" && typeof hashString !== "string" ) {
      return { slug: null, id: null };
    }
    const hash = typeof hashString === "string"
      ? hashString
      : window.location?.hash || "";
    const cleaned = hash.trim();
    if ( !cleaned || cleaned.length < 2 ) {
      return { slug: null, id: null };
    }
    const withoutHash = cleaned.replace( /^#/, "" );
    let decoded = withoutHash;
    try {
      decoded = decodeURIComponent( withoutHash );
    } catch ( e ) {
      decoded = withoutHash;
    }
    const value = decoded.trim();
    if ( !value ) {
      return { slug: null, id: null };
    }
    if ( /^\d+$/.test( value ) ) {
      const taxonId = Number.parseInt( value, 10 );
      return {
        slug: null,
        id: Number.isFinite( taxonId ) && taxonId > 0 ? taxonId : null
      };
    }
    return {
      slug: IdSummariesDemoApp.slugifyTaxonName( value ),
      id: null
    };
  }

  static adminExtrasRequested() {
    if ( typeof window === "undefined" || !window.location ) {
      return false;
    }
    try {
      const params = new URLSearchParams( window.location.search || "" );
      const rawValue = params.get( "admin_mode" );
      if ( !rawValue ) {
        return false;
      }
      return ["1", "true", "yes", "on"].includes( rawValue.toLowerCase() );
    } catch ( error ) {
      return false;
    }
  }

  componentDidMount() {
    this.fetchRunNames( 1, new Set(), this.state.selectedLanguage );
    if ( typeof window !== "undefined" && window.addEventListener ) {
      window.addEventListener( "hashchange", this.handleHashChange );
    }
    this.trySelectSpeciesFromHash();
  }

  componentWillUnmount() {
    if ( typeof window !== "undefined" && window.removeEventListener ) {
      window.removeEventListener( "hashchange", this.handleHashChange );
    }
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

  fetchRunNames( page = 1, accumulator = new Set(), language = this.state.selectedLanguage ) {
    const targetLanguage = language || this.state.selectedLanguage;
    const taxonIdSummariesAPI = inatjs?.taxon_id_summaries;
    if ( !taxonIdSummariesAPI || typeof taxonIdSummariesAPI.search !== "function" ) {
      return;
    }
    if ( page === 1 ) {
      this.setState( { runNamesLoading: true } );
    }
    const searchParams = {
      page,
      per_page: 200,
      fields: "run_name",
      order_by: "run_generated_at",
      order: "desc"
    };
    if ( targetLanguage ) {
      searchParams.language = targetLanguage;
    }
    taxonIdSummariesAPI.search(
      searchParams,
      { useAuth: true }
    )
      .then( response => {
        const results = Array.isArray( response?.results ) ? response.results : [];
        results.forEach( item => {
          const runName = typeof item?.run_name === "string" ? item.run_name.trim() : "";
          if ( runName ) {
            accumulator.add( runName );
          }
        } );
        const totalResults = Number.isFinite( response?.total_results )
          ? response.total_results
          : results.length;
        const perPage = Number.isFinite( response?.per_page ) ? response.per_page : 200;
        const totalPages = perPage > 0 ? Math.ceil( totalResults / perPage ) : 1;
        if ( page < totalPages ) {
          this.fetchRunNames( page + 1, accumulator, targetLanguage );
          return;
        }
        const runNames = Array.from( accumulator ).sort( ( a, b ) => a.localeCompare( b ) );
        if ( this.state.selectedLanguage !== targetLanguage ) {
          return;
        }
        this.setState( prev => {
          let selectedRunName = prev.selectedRunName;
          if ( !selectedRunName && runNames.length ) {
            [selectedRunName] = runNames;
          } else if ( selectedRunName && !runNames.includes( selectedRunName ) ) {
            selectedRunName = runNames[0] || null;
          }
          return {
            runNames,
            runNamesLoading: false,
            selectedRunName
          };
        } );
      } )
      .catch( error => {
        // eslint-disable-next-line no-console
        console.warn( "Failed to load run names", error );
        if ( this.state.selectedLanguage === targetLanguage ) {
          this.setState( {
            runNames: [],
            runNamesLoading: false
          } );
        }
      } );
  }

  normalizeIncomingData( data ) {
    const normalizeTip = ( t = {} ) => ( {
      id: t?.id,
      text: t?.content || t?.tip || t?.summary || "",
      group: t?.key_visual_trait_group || t?.group || t?.visual_key_group || null,
      photoTip: t?.photo_tip || t?.photoTip || null,
      score: Number.isFinite( t?.score )
        ? t.score
        : Number.isFinite( t?.global_score )
          ? t.global_score
          : null,
      sources: Array.isArray( t?.sources )
        ? t.sources.map( s => ( {
          id: s?.id,
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
            id: r?.id,
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
      language: item?.language || null,
      runGeneratedAt: item?.run_generated_at || null,
        taxonPhotoId: item?.taxon_photo_id,
        taxonPhotoAttribution: item?.taxon_photo_attribution || null,
        taxonPhotoObservationId: item?.taxon_photo_observation_id
          || item?.taxon_photo?.observation_id
          || null,
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

  handleHashChange() {
    const { slug, id } = IdSummariesDemoApp.hashTargetFromLocation();
    const currentSlug = IdSummariesDemoApp.slugifyTaxonName( this.state.selectedSpecies?.name );
    const currentId = this.state.selectedSpecies?.id || null;
    if ( slug && slug === currentSlug ) {
      this.hashSelectedTaxonSlug = null;
      this.hashSelectedTaxonId = null;
      return;
    }
    if ( !slug && id && currentId === id ) {
      this.hashSelectedTaxonSlug = null;
      this.hashSelectedTaxonId = null;
      return;
    }
    this.hashSelectedTaxonSlug = slug || null;
    this.hashSelectedTaxonId = !slug && id ? id : null;
    if ( slug || id ) {
      this.trySelectSpeciesFromHash();
    }
  }

  trySelectSpeciesFromHash( list ) {
    const taxaList = Array.isArray( list ) ? list : this.latestLoadedTaxa;
    const targetSlug = this.hashSelectedTaxonSlug;
    const targetId = this.hashSelectedTaxonId;
    if (
      ( !targetSlug && !targetId )
      || !Array.isArray( taxaList )
      || !taxaList.length
    ) {
      return false;
    }
    if ( targetSlug ) {
      const slugMatch = taxaList.find( species => (
        IdSummariesDemoApp.slugifyTaxonName( species?.name ) === targetSlug
      ) );
      if ( slugMatch ) {
        this.handleSpeciesClick( slugMatch );
        this.hashSelectedTaxonSlug = null;
        this.hashSelectedTaxonId = null;
        return true;
      }
    }
    if ( targetId ) {
      const idMatch = taxaList.find( species => species?.id === targetId );
      if ( idMatch ) {
        this.handleSpeciesClick( idMatch );
        this.hashSelectedTaxonSlug = null;
        this.hashSelectedTaxonId = null;
        return true;
      }
    }
    return false;
  }

  updateLocationHash( species = null ) {
    if ( typeof window === "undefined" || !window.location ) {
      return;
    }
    const { pathname = "", search = "", hash = "" } = window.location;
    const targetSlug = IdSummariesDemoApp.slugifyTaxonName( species?.name );
    const identifier = targetSlug || ( species?.id ? String( species.id ) : "" );
    const desiredHash = identifier ? `#${identifier}` : "";
    if ( hash === desiredHash ) return;
    const nextUrl = `${pathname}${search}${desiredHash}`;
    if ( window.history && typeof window.history.replaceState === "function" ) {
      window.history.replaceState( window.history.state, "", nextUrl );
    } else {
      window.location.hash = desiredHash;
    }
  }

  handleSpeciesClick( species ) {
    this.updateLocationHash( species || null );
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
      "taxon_photo_attribution",
      "taxon_photo_observation_id",
      "language",
      "uuid",
      "run_generated_at",
      "id_summaries",
      "id_summaries.id",
      "id_summaries.summary",
      "id_summaries.photo_tip",
      "id_summaries.score",
      "id_summaries.visual_key_group",
      "id_summaries.references.url",
      "id_summaries.references.comment_uuid",
      "id_summaries.references.user_id",
      "id_summaries.references.body",
      "id_summaries.references.reference_content",
      "id_summaries.references.id",
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
    this.updateLocationHash( null );
    this.hashSelectedTaxonSlug = null;
    this.hashSelectedTaxonId = null;
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

  handleActiveToggle( event ) {
    const nextActive = event.target.checked;
    this.setState( prev => {
      let nextRunName = prev.selectedRunName;
      if ( !nextActive && !nextRunName && prev.runNames.length ) {
        [nextRunName] = prev.runNames;
      }
      return {
        activeOnly: nextActive,
        selectedRunName: nextRunName,
        selectedSpecies: null,
        speciesImage: null,
        error: null
      };
    } );
  }

  handleRunNameChange( event ) {
    const value = event.target.value;
    this.setState( {
      selectedRunName: value || null,
      selectedSpecies: null,
      speciesImage: null,
      error: null
    } );
  }

  handlePhotoTipsToggle( event ) {
    const nextValue = event.target.checked;
    this.setState( { showPhotoTips: nextValue } );
  }

  handleLanguageChange( event ) {
    const nextLanguage = event?.target?.value;
    if ( !nextLanguage || nextLanguage === this.state.selectedLanguage ) {
      return;
    }
    this.setState( {
      selectedLanguage: nextLanguage,
      selectedSpecies: null,
      speciesImage: null,
      error: null
    }, () => {
      this.fetchRunNames( 1, new Set(), nextLanguage );
    } );
  }

  renderLanguagePicker() {
    const { selectedLanguage } = this.state;
    return (
      <div className="fg-language-picker">
        <label className="fg-filter-select">
          <span>{I18n.t( "id_summaries.demo.filters.language_label" )}</span>
          <select value={selectedLanguage} onChange={this.handleLanguageChange}>
            {LANGUAGE_OPTIONS.map( option => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ) )}
          </select>
        </label>
      </div>
    );
  }

  renderFilters( inline = false ) {
    if ( !this.adminExtrasEnabled ) {
      return null;
    }
    const {
      activeOnly,
      selectedRunName,
      runNames,
      runNamesLoading,
      showPhotoTips,
      selectedSpecies
    } = this.state;
    const hasPhotoTips = Array.isArray( selectedSpecies?.tips )
      && selectedSpecies.tips.some( tip => typeof tip?.photoTip === "string" && tip.photoTip.trim().length > 0 );
    const photoTipsTargetId = hasPhotoTips && selectedSpecies
      ? `photo-tips-${selectedSpecies.id || selectedSpecies.uuid}`
      : undefined;

    return (
      <div className={`fg-controls${inline ? " fg-controls-inline" : ""}`}>
        <div className="fg-filter-bar">
          <label className="fg-filter-checkbox">
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={this.handleActiveToggle}
            />
            <span>{I18n.t( "id_summaries.demo.filters.active_only" )}</span>
          </label>
          <div className="fg-run-controls">
            <label className="fg-filter-select">
              <span>{I18n.t( "id_summaries.demo.filters.run_label" )}</span>
              <select
                value={selectedRunName || ""}
                onChange={this.handleRunNameChange}
                disabled={activeOnly || runNamesLoading || runNames.length === 0}
              >
                {!selectedRunName ? (
                  <option value="" disabled>
                    {runNamesLoading
                      ? I18n.t( "id_summaries.demo.filters.run_loading" )
                      : I18n.t( "id_summaries.demo.filters.run_placeholder" )}
                  </option>
                ) : null}
                {runNames.map( name => (
                  <option key={name} value={name}>
                    {name}
                  </option>
                ) )}
              </select>
            </label>
            <label className="fg-filter-checkbox fg-photo-tip-checkbox">
              <input
                type="checkbox"
                checked={showPhotoTips}
                onChange={this.handlePhotoTipsToggle}
                aria-controls={photoTipsTargetId}
              />
              <span>{I18n.t( "id_summaries.demo.filters.photo_tips_toggle" )}</span>
            </label>
          </div>
        </div>
      </div>
    );
  }

  header() {
    return (
      <nav className="navbar navbar-default">
        <div className="container fg-header">
          <div className="navbar-header fg-header-brand">
            <div className="logo">
              <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                <img alt="Site Logo" src="https://static.inaturalist.org/sites/1-logo.svg" />
              </a>
            </div>
            <div className="title">
              <a
                href="/id_summaries_demo"
                onClick={e => {
                  e.preventDefault();
                  this.reset();
                }}
              >
                {I18n.t( "id_summaries.demo.app.header_link" )}
              </a>
            </div>
          </div>
          <div className="fg-header-filters">
            {this.renderLanguagePicker()}
            {this.adminExtrasEnabled ? this.renderFilters( true ) : null}
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
      referenceUsers,
      activeOnly,
      selectedRunName,
      showPhotoTips,
      selectedLanguage
    } = this.state;
    const votesForSelected = selectedSpecies ? tipVotes?.[selectedSpecies.id] : {};
    const selectedPhotoAttribution = selectedSpecies?.taxonPhotoAttribution || null;

    return (
      <div className="bootstrap fg-app">
        {this.header()}
        {this.infoSection()}

        <div className="container">
          <div className="fg-layout">
            <div className="fg-sidebar">
              <TaxaListContainer
                activeOnly={activeOnly}
                runName={selectedRunName}
                language={selectedLanguage}
                selectedId={selectedSpecies?.id}
                images={speciesImages}
                onTileClick={this.handleSpeciesClick}
                onLoaded={list => {
                  this.latestLoadedTaxa = list;
                  const mapped = this.buildSpeciesImageMap( list );
                  if ( Object.keys( mapped ).length ) {
                    this.setState( prev => ( {
                      speciesImages: { ...prev.speciesImages, ...mapped }
                    } ) );
                  }
                  const hashSelected = this.trySelectSpeciesFromHash( list );
                  if ( hashSelected ) {
                    return;
                  }
                  const defaultSpecies = determineDefaultSpecies( list, this.groupingOptions );
                  if ( defaultSpecies && !this.state.selectedSpecies ) {
                    this.handleSpeciesClick( defaultSpecies );
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
                showPhotoTips={showPhotoTips}
                photoAttribution={selectedPhotoAttribution}
                adminExtrasVisible={this.adminExtrasEnabled}
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
