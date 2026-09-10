import React, {
  useCallback, useEffect, useMemo, useRef, useState
} from "react";
import inaturalistjs from "inaturalistjs";
import Combobox, { ComboboxGroup, ComboboxOption } from "./combobox";
import { updateSession } from "../util";
import type { Config } from "../types";
import css from "./taxon_combobox.module.css";

const SEARCH_EXTERNAL_KEY = "search_external";
const MAX_VISION_RESULTS = 8;

const TAXON_FIELDS = {
  ancestor_ids: true,
  default_photo: { url: true },
  representative_photo: { url: true },
  iconic_taxon_id: true,
  iconic_taxon_name: true,
  is_active: true,
  matched_term: true,
  name: true,
  preferred_common_name: true,
  rank: true,
  rank_level: true
};

export interface VisionParams {
  observationID?: number;
  observationUUID?: string;
}

interface VisionTaxon extends INatTaxonRecord {
  visionScore?: number;
  frequencyScore?: number;
  isCommonAncestor?: boolean;
}

interface VisionResult {
  taxon: object;
  vision_score?: number;
  frequency_score?: number;
}

interface VisionResponse {
  results: VisionResult[];
  common_ancestor?: { taxon: object };
  experimental?: string;
}

export interface TaxonComboboxProps {
  config?: Config;
  onSelect: ( taxon: INatTaxonRecord | null ) => void;
  visionParams?: VisionParams | null;
  perPage?: number;
  searchExternal?: boolean;
  placeholder?: string;
  onKeyDown?: ( event: React.KeyboardEvent<HTMLInputElement> ) => void;
}

const photoOf = ( taxon: INatTaxonRecord ) => taxon.representative_photo || taxon.default_photo;

const iconicIcon = ( taxon: INatTaxonRecord ) => {
  const name = taxon.iconicTaxonName ? taxon.iconicTaxonName( ).toLowerCase( ) : "unknown";
  return <i className={`icon icon-iconic-${name}`} />;
};

const commonNames = ( taxon: INatTaxonRecord ) => (
  taxon.preferred_common_names && taxon.preferred_common_names.length > 0
    ? taxon.preferred_common_names.map( n => iNatModels.Taxon.titleCaseName( n.name ) ).join( " · " )
    : iNatModels.Taxon.titleCaseName( taxon.preferred_common_name )
);

const taxonTitle = ( taxon: INatTaxonRecord, scinameFirst: boolean ) => (
  scinameFirst ? taxon.name || "" : commonNames( taxon ) || taxon.name || ""
);

const taxonSubtitle = ( taxon: INatTaxonRecord, scinameFirst: boolean, title: string ) => {
  const name = scinameFirst ? commonNames( taxon ) : taxon.name;
  const subtitle = name && name !== title ? name : "";
  const rank = taxon.rank && ( ( taxon.rank_level || 0 ) > 10 || !subtitle )
    ? I18n.t( `ranks.${taxon.rank}`, { defaultValue: taxon.rank } )
    : "";
  return [rank, subtitle].filter( Boolean ).join( " " );
};

// The matched term is worth showing only when it is absent from both displayed names.
const matchedTermSuffix = ( taxon: INatTaxonRecord, title: string, subtitle: string ) => {
  const term = taxon.matched_term;
  if ( !term || title.includes( term ) || subtitle.includes( term ) ) { return ""; }
  return ` (${term})`;
};

interface ResultProps {
  taxon: VisionTaxon;
  title: string;
  subtitle: string;
  isVision: boolean;
}

const TaxonResult = ( {
  taxon, title, subtitle, isVision
}: ResultProps ) => {
  const photo = photoOf( taxon );
  const visionLabels = [
    taxon.visionScore ? I18n.t( "visually_similar" ) : null,
    taxon.frequencyScore ? I18n.t( "expected_nearby" ) : null
  ].filter( Boolean );
  return (
    <div className={`${css.result} ${isVision ? css.vision : ""}`}>
      <div className={css.resultThumb}>
        { photo ? <img alt="" src={photo.url} /> : iconicIcon( taxon ) }
      </div>
      <div className={css.label}>
        <div>
          <span className={css.title}>{ title }</span>
          <span className={css.subtitle}>{ subtitle }</span>
          { visionLabels.length > 0 && (
            <span className={css.visionSubtitle}>{ visionLabels.join( " / " ) }</span>
          ) }
        </div>
      </div>
    </div>
  );
};

// `defaultValue` only applies when the key is missing from every locale, so fall back by hand.
const commonAncestorTitle = ( taxon: VisionTaxon ) => {
  const rank = ( taxon.rank || "" ).replace( /\W+/g, "_" ).toLowerCase( );
  const generic = I18n.t( "were_pretty_sure_this_is_in_the_rank", {
    rank: I18n.t( `ranks_lowercase_${rank}`, { defaultValue: taxon.rank } ),
    gender: rank,
    iconic_taxon: taxon.iconic_taxon_name
  } );
  const specific = I18n.t( `were_pretty_sure_this_is_in_the_${rank}`, {
    defaultValue: generic,
    iconic_taxon: taxon.iconic_taxon_name
  } );
  const inEnglish = I18n.t( `were_pretty_sure_this_is_in_the_${rank}`, { locale: "en" } );
  return I18n.locale !== "en" && specific === inEnglish ? generic : specific;
};

const TaxonCombobox = ( {
  config,
  onSelect,
  visionParams,
  perPage = 10,
  searchExternal = false,
  placeholder,
  onKeyDown
}: TaxonComboboxProps ) => {
  const [inputValue, setInputValue] = useState( "" );
  const [options, setOptions] = useState<ComboboxOption[]>( [] );
  const [groups, setGroups] = useState<ComboboxGroup[]>( [] );
  const [header, setHeader] = useState<string | null>( null );
  const [message, setMessage] = useState<string | null>( null );
  const [selected, setSelected] = useState<INatTaxonRecord | null>( null );
  const [counts, setCounts] = useState( { nearby: 0, suggested: 0 } );
  const [viewNotNearby, setViewNotNearby] = useState(
    !!config?.currentUser?.prefers_not_nearby_suggestions
  );
  const taxaByKey = useRef( new Map<string, INatTaxonRecord>( ) );
  const visionCache = useRef<VisionResponse | null>( null );
  const requestID = useRef( 0 );

  const scinameFirst = !!config?.currentUser?.prefers_scientific_name_first;

  useEffect( ( ) => { visionCache.current = null; }, [visionParams] );

  const toOption = useCallback( ( taxon: VisionTaxon ): ComboboxOption => {
    const title = taxonTitle( taxon, scinameFirst );
    const subtitle = taxonSubtitle( taxon, scinameFirst, title );
    const key = String( taxon.id );
    taxaByKey.current.set( key, taxon );
    return {
      key,
      textValue: title + matchedTermSuffix( taxon, title, subtitle ),
      content: (
        <TaxonResult
          taxon={taxon}
          title={title + matchedTermSuffix( taxon, title, subtitle )}
          subtitle={subtitle}
          isVision={!!( taxon.visionScore || taxon.frequencyScore || taxon.isCommonAncestor )}
        />
      )
    };
  }, [scinameFirst] );

  const clearResults = ( ) => {
    setOptions( [] );
    setGroups( [] );
    setHeader( null );
    setMessage( null );
  };

  const showVisionResults = useCallback( ( response: VisionResponse ) => {
    const all = response.results || [];
    const nearby = all.filter( r => ( r.frequency_score || 0 ) > 0 );
    setCounts( { suggested: all.length, nearby: nearby.length } );
    const shown = nearby.length > 0 && !viewNotNearby ? nearby : all;
    const suggestions = shown.slice( 0, MAX_VISION_RESULTS ).map( result => {
      const taxon = new iNatModels.Taxon( result.taxon ) as VisionTaxon;
      taxon.visionScore = result.vision_score;
      taxon.frequencyScore = result.frequency_score;
      return { ...toOption( taxon ), group: "suggestions" };
    } );
    const nextGroups: ComboboxGroup[] = [];
    const nextOptions: ComboboxOption[] = [];
    if ( response.common_ancestor ) {
      const ancestor = new iNatModels.Taxon( response.common_ancestor.taxon ) as VisionTaxon;
      ancestor.isCommonAncestor = true;
      nextGroups.push( { key: "ancestor", title: commonAncestorTitle( ancestor ) } );
      nextOptions.push( { ...toOption( ancestor ), group: "ancestor" } );
    }
    if ( suggestions.length > 0 ) {
      nextGroups.push( {
        key: "suggestions",
        title: response.common_ancestor
          ? I18n.t( "here_are_our_top_suggestions" )
          : I18n.t( "not_confident_top_suggestions" )
      } );
      nextOptions.push( ...suggestions );
    }
    setGroups( nextGroups );
    setOptions( nextOptions );
    setHeader( response.experimental ? `Experimental: ${response.experimental}` : null );
    setMessage( nextOptions.length === 0 ? I18n.t( "not_confident" ) : null );
  }, [toOption, viewNotNearby] );

  const searchVision = useCallback( ( id: number ) => {
    if ( !visionParams ) {
      clearResults( );
      return;
    }
    if ( visionCache.current ) {
      showVisionResults( visionCache.current );
      return;
    }
    setGroups( [] );
    setOptions( [] );
    setMessage( I18n.t( "loading_suggestions" ) );
    const params: Record<string, unknown> = { include_representative_photos: true };
    if ( config?.testingApiV2 ) {
      params.fields = { frequency_score: true, vision_score: true, taxon: TAXON_FIELDS };
    }
    if ( config?.currentUser?.isAdmin && config?.testFeature ) {
      params.test_feature = config.testFeature;
    }
    params.id = config?.testingApiV2 && visionParams.observationUUID
      ? visionParams.observationUUID
      : visionParams.observationID;
    inaturalistjs.computervision.score_observation( params )
      .then( ( response: VisionResponse ) => {
        visionCache.current = response;
        if ( requestID.current !== id ) { return; }
        showVisionResults( response );
      } )
      .catch( ( ) => {
        if ( requestID.current !== id ) { return; }
        setMessage( I18n.t( "not_confident" ) );
      } );
  }, [config, visionParams, showVisionResults] );

  const externalSearchOption = ( query: string ): ComboboxOption => ( {
    key: SEARCH_EXTERNAL_KEY,
    // Leaves the query in place, since choosing this searches rather than picks a taxon.
    textValue: query,
    keepMenuOpenOnSelect: true,
    content: (
      <div className={css.result}>
        <div className={css.resultThumb}>
          <i className="glyphicon glyphicon-search" />
        </div>
        <div className={css.label}>
          <span className={css.title}>{ I18n.t( "search_external_name_providers" ) }</span>
        </div>
      </div>
    )
  } );

  const searchTaxa = useCallback( ( query: string, id: number ) => {
    const params: Record<string, unknown> = {
      q: query,
      per_page: perPage,
      locale: I18n.locale,
      preferred_place_id: typeof PREFERRED_PLACE === "undefined" ? null : PREFERRED_PLACE?.id
    };
    if ( config?.testingApiV2 ) { params.fields = TAXON_FIELDS; }
    inaturalistjs.taxa.autocomplete( params ).then( ( response: { results?: object[] } ) => {
      if ( requestID.current !== id ) { return; }
      const results = ( response.results || [] )
        .map( result => toOption( new iNatModels.Taxon( result ) ) );
      const frozen = typeof CONFIG !== "undefined" && CONFIG?.content_freeze_enabled;
      setGroups( [] );
      setOptions( searchExternal && !frozen
        ? [...results, externalSearchOption( query )]
        : results );
      setHeader( null );
      setMessage( results.length === 0 ? I18n.t( "no_results_found" ) : null );
    } );
  }, [config, perPage, searchExternal, toOption] );

  const search = useCallback( ( query: string ) => {
    requestID.current += 1;
    if ( query ) {
      searchTaxa( query, requestID.current );
    } else {
      searchVision( requestID.current );
    }
  }, [searchTaxa, searchVision] );

  const searchExternalProviders = ( query: string ) => {
    requestID.current += 1;
    const id = requestID.current;
    setOptions( [] );
    setMessage( I18n.t( "loading" ) );
    fetch(
      `/taxa/search.json?per_page=${perPage}&include_external=1&partial=elastic&q=${encodeURIComponent( query )}`,
      { headers: { Accept: "application/json" } }
    )
      .then( response => response.json( ) )
      .then( ( results: object[] ) => {
        if ( requestID.current !== id ) { return; }
        setOptions( results.map( result => toOption( new iNatModels.Taxon( result ) ) ) );
        setMessage( results.length === 0 ? I18n.t( "no_results_found" ) : null );
      } )
      .catch( ( ) => {
        if ( requestID.current !== id ) { return; }
        setMessage( I18n.t( "no_results_found" ) );
      } );
  };

  const handleSelect = ( option: ComboboxOption ) => {
    if ( option.key === SEARCH_EXTERNAL_KEY ) {
      searchExternalProviders( option.textValue );
      return;
    }
    const taxon = taxaByKey.current.get( option.key );
    if ( !taxon ) { return; }
    setSelected( taxon );
    clearResults( );
    onSelect( taxon );
  };

  const handleClear = ( ) => {
    setInputValue( "" );
    setSelected( null );
    clearResults( );
    onSelect( null );
  };

  const selectedPhoto = selected && photoOf( selected );
  const thumbStyle = selectedPhoto?.square_url
    ? { backgroundImage: `url('${selectedPhoto.square_url}')` }
    : undefined;
  const thumbInner = !selectedPhoto?.square_url && ( selected
    ? iconicIcon( selected )
    : <i className="glyphicon glyphicon-search" /> );
  // The per-result view link would nest a control in a listbox option (a11y violation), so the
  // view affordance lives on the selected chip instead.
  const thumb = selected
    ? (
      <a
        className={css.thumb}
        style={thumbStyle}
        href={`/taxa/${selected.id}`}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={I18n.t( "view" )}
        title={I18n.t( "view" )}
      >
        { thumbInner }
      </a>
    )
    : <div className={css.thumb} style={thumbStyle}>{ thumbInner }</div>;

  const footer = useMemo( ( ) => {
    if ( inputValue || counts.nearby === 0 || counts.nearby === counts.suggested ) { return null; }
    return (
      <button
        type="button"
        onClick={( ) => {
          setViewNotNearby( !viewNotNearby );
          updateSession( { prefers_not_nearby_suggestions: !viewNotNearby } );
        }}
      >
        { viewNotNearby
          ? I18n.t( "only_view_nearby_suggestions" )
          : I18n.t( "include_suggestions_not_expected_nearby" ) }
      </button>
    );
  }, [inputValue, counts, viewNotNearby] );

  return (
    <div className="TaxonCombobox form-group">
      <input type="hidden" name="taxon_id" value={selected ? selected.id : ""} readOnly />
      <Combobox
        label={I18n.t( "species_name_cap" )}
        placeholder={placeholder || I18n.t( "species_name_cap" )}
        inputName="taxon_name"
        inputClassName={`form-control ${css.input}`}
        clearLabel={I18n.t( "clear" )}
        minLength={0}
        options={options}
        groups={groups}
        header={header}
        message={message}
        footer={footer}
        startAddon={thumb}
        inputValue={inputValue}
        onInputChange={setInputValue}
        onSearch={search}
        onSelect={handleSelect}
        onClear={handleClear}
        onInputKeyDown={onKeyDown}
      />
    </div>
  );
};

export default TaxonCombobox;
