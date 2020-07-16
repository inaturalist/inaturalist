import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import {
  Modal,
  Button,
  OverlayTrigger,
  Popover,
  Tooltip,
  Overlay
} from "react-bootstrap";
import _ from "lodash";
import moment from "moment";
import DiscussionListContainer from "../containers/discussion_list_container";
import CommentFormContainer from "../containers/comment_form_container";
import IdentificationFormContainer from "../containers/identification_form_container";
import SuggestionsContainer from "../containers/suggestions_container";
import AnnotationsContainer from "../containers/annotations_container";
import QualityMetricsContainer from "../containers/quality_metrics_container";
import ObservationFieldsContainer from "../containers/observation_fields_container";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonMap from "./taxon_map";
import UserText from "../../../shared/components/user_text";
import { formattedDateTimeInTimeZone } from "../../../shared/util";
import ZoomableImageGallery from "./zoomable_image_gallery";
import FollowButtonContainer from "../containers/follow_button_container";
import FavesContainer from "../containers/faves_container";
import { TABS } from "../actions/current_observation_actions";
import { annotationShortcuts } from "../keyboard_shortcuts";

class ObservationModal extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.state = {
      brightnesses: {}
    };
  }

  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".IdentificationForm textarea,.CommentForm textarea", domNode ).textcompleteUsers( );
  }

  componentDidUpdate( prevProps ) {
    // this is a stupid hack to get the google map to render correctly if it
    // was created while it wasn't visible
    const { tab, observation } = this.props;
    if ( tab === "info" && prevProps.tab !== "info" ) {
      const that = this;
      setTimeout( ( ) => {
        const map = $( ".TaxonMap", ReactDOM.findDOMNode( that ) ).data( "taxonMap" );
        google.maps.event.trigger( map, "resize" );
        if ( observation && observation.latitude ) {
          map.setCenter( new google.maps.LatLng(
            observation.latitude,
            observation.longitude
          ) );
        }
      }, 500 );
    }
  }

  render( ) {
    const {
      addComment,
      addIdentification,
      blind,
      captiveByCurrentUser,
      chooseSuggestedTaxon,
      chooseTab,
      commentFormVisible,
      controlledTerms,
      currentUser,
      hidePrevNext,
      hideTools,
      identificationFormVisible,
      images,
      imagesCurrentIndex,
      keyboardShortcutsShown,
      loadingDiscussionItem,
      observation,
      onClose,
      reviewedByCurrentUser,
      setImagesCurrentIndex,
      showNextObservation,
      showPrevObservation,
      tab,
      tabs,
      tabTitles,
      toggleCaptive,
      toggleKeyboardShortcuts,
      toggleReviewed,
      visible,
      updateCurrentUser,
      mapZoomLevel,
      onMapZoomChanged,
      mapZoomLevelLocked,
      setMapZoomLevelLocked
    } = this.props;
    if ( !observation ) {
      return <div />;
    }
    let taxonMap;
    const currentUserPrefersMedialessObs = currentUser
      && currentUser.prefers_medialess_obs_maps;
    if ( observation.latitude ) {
      // Select a small set of attributes that won't change wildy as the
      // observation changes.
      const obsForMap = _.pick( observation, [
        "id",
        "species_guess",
        "latitude",
        "longitude",
        "positional_accuracy",
        "geoprivacy",
        "taxon",
        "user",
        "map_scale"
      ] );
      obsForMap.coordinates_obscured = observation.obscured && !observation.private_geojson;
      const taxonLayer = {
        observationLayers: [
          {
            label: I18n.t( "verifiable_observations" ),
            verifiable: true,
            observation_id: observation.obscured && observation.private_geojson && obsForMap.id
          },
          {
            label: I18n.t( "observations_without_media" ),
            verifiable: false,
            captive: false,
            photos: false,
            sounds: false,
            disabled: !currentUserPrefersMedialessObs,
            onChange: e => updateCurrentUser( { prefers_medialess_obs_maps: e.target.checked } ),
            observation_id: observation.obscured && observation.private_geojson && obsForMap.id
          }
        ],
        places: { disabled: true }
      };
      if ( !blind ) {
        taxonLayer.taxon = obsForMap.taxon;
        taxonLayer.gbif = { disabled: true };
      }
      taxonMap = (
        <TaxonMap
          key={`map-for-${obsForMap.id}`}
          reloadKey={`map-for-${obsForMap.id}`}
          taxonLayers={[taxonLayer]}
          observations={[obsForMap]}
          clickable={!blind}
          latitude={obsForMap.latitude}
          longitude={obsForMap.longitude}
          zoomLevel={
            mapZoomLevelLocked && mapZoomLevel ? mapZoomLevel : ( obsForMap.map_scale || 5 )
          }
          onZoomChanged={onMapZoomChanged}
          mapTypeControl
          mapTypeControlOptions={{
            style: google.maps.MapTypeControlStyle.DROPDOWN_MENU,
            position: google.maps.ControlPosition.TOP_RIGHT
          }}
          showAccuracy
          showAllLayer={false}
          overlayMenu={false}
          zoomControlOptions={{ position: google.maps.ControlPosition.TOP_LEFT }}
          currentUser={currentUser}
          updateCurrentUser={updateCurrentUser}
        />
      );
    } else if ( observation.obscured ) {
      taxonMap = (
        <div className="TaxonMap empty">
          <i className="fa fa-map-marker" />
          { " " }
          { I18n.t( "location_private" ) }
        </div>
      );
    } else {
      taxonMap = (
        <div className="TaxonMap empty">
          <i className="fa fa-map-marker" />
          { " " }
          { I18n.t( "location_unknown" ) }
        </div>
      );
    }

    let photos = null;
    if ( images && images.length > 0 ) {
      const brightnessKey = `${observation.id}-${imagesCurrentIndex}`;
      const { brightnesses } = this.state;
      const brightness = brightnesses[brightnessKey] || 1;
      const brightnessClass = `brightness-${brightness.toString( ).replace( ".", "-" )}`;
      photos = (
        <div className={`photos-wrapper ${brightnessClass}`}>
          <ZoomableImageGallery
            key={`map-for-${observation.id}`}
            items={images}
            slideIndex={imagesCurrentIndex}
            showThumbnails={images && images.length > 1}
            lazyLoad={false}
            server
            showNav={false}
            disableArrowKeys
            showFullscreenButton={false}
            showPlayButton={false}
            onSlide={setImagesCurrentIndex}
            onThumbnailClick={( event, index ) => setImagesCurrentIndex( index )}
          />
          <div className="photo-controls" role="toolbar">
            <div className="btn-group-vertical btn-group-xs" role="group">
              <a
                href={images[imagesCurrentIndex].zoom || images[imagesCurrentIndex].original}
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-default"
                title={I18n.t( "view_full_size_photo" )}
              >
                <i className="icon-link-external" />
              </a>
            </div>
            <div className="brightness-control btn-group-vertical btn-group-xs" role="group">
              <button
                type="button"
                className="btn btn-default btn-adjust-brightness"
                onClick={( ) => {
                  const newBrightnesses = Object.assign( {}, brightnesses, { [brightnessKey]: 1 } );
                  this.setState( { brightnesses: newBrightnesses } );
                }}
                title={brightness === 1 ? I18n.t( "adjust_brightness" ) : I18n.t( "reset_brightness" )}
              >
                <i className="icon-adjust" />
              </button>
              <button
                type="button"
                className="btn btn-default btn-increase-brightness"
                onClick={( ) => {
                  const existing = brightnesses[brightnessKey] || 1;
                  let newBrightness = _.round( existing + 0.2, 2 );
                  if ( newBrightness > 3 ) {
                    newBrightness = 3;
                  }
                  const newBrightnesses = Object.assign( {}, brightnesses, {
                    [brightnessKey]: newBrightness
                  } );
                  this.setState( { brightnesses: newBrightnesses } );
                }}
                title={I18n.t( "increase_brightness" )}
              >
                +
              </button>
              <button
                type="button"
                className="btn btn-default btn-decrease-brightness"
                onClick={( ) => {
                  const existing = brightnesses[brightnessKey] || 1;
                  let newBrightness = _.round( existing - 0.2, 2 );
                  if ( newBrightness < 0.2 ) {
                    newBrightness = 0.2;
                  }
                  const newBrightnesses = Object.assign( {}, brightnesses, {
                    [brightnessKey]: newBrightness
                  } );
                  this.setState( { brightnesses: newBrightnesses } );
                }}
                title={I18n.t( "decrease_brightness" )}
              >
                -
              </button>
            </div>
          </div>
        </div>
      );
    }
    let sounds = null;
    if ( observation.sounds && observation.sounds.length > 0 ) {
      sounds = observation.sounds.map( s => {
        const soundKey = `sound-${s.id}`;
        let player;
        if ( s.subtype === "SoundcloudSound" || !s.file_url ) {
          player = (
            <iframe
              key={soundKey}
              title={soundKey}
              width="100%"
              height="100"
              scrolling="no"
              frameBorder="no"
              src={`https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/${s.native_sound_id}&auto_play=false&hide_related=false&show_comments=false&show_user=false&show_reposts=false&visual=false&show_artwork=false`}
            />
          );
        } else {
          player = (
            <audio key={soundKey} controls preload="none" controlsList="nodownload">
              <source src={s.file_url} type={s.file_content_type} />
              { I18n.t( "your_browser_does_not_support_the_audio_element" ) }
            </audio>
          );
        }
        let flagNotice;
        if ( _.find( s.flags, f => !f.resolved ) ) {
          flagNotice = (
            <p className="flag-notice alert alert-warning">
              { I18n.t( "sounds.sound_has_been_flagged" )}
              { " " }
              <a href={`/sounds/${s.id}/flags`} className="linky">
                { I18n.t( "view_flags" ) }
              </a>
            </p>
          );
        }
        if ( flagNotice ) {
          if (
            currentUser.id === observation.user.id
            || currentUser.roles.indexOf( "curator" ) >= 0
            || currentUser.roles.indexOf( "admin" ) >= 0
          ) {
            return (
              <div key={soundKey}>
                { flagNotice }
                { player }
              </div>
            );
          }
          return (
            <div key={soundKey}>
              { flagNotice }
            </div>
          );
        }
        return <div key={soundKey}>{ player }</div>;
      } );
      sounds = (
        <div className="sounds">
          { sounds }
        </div>
      );
    }

    const scrollSidebarToForm = form => {
      const sidebar = $( form ).parents( ".ObservationModal:first" ).find( ".sidebar" );
      if ( $( form ).hasClass( "IdentificationForm" ) ) {
        $( ":input:visible:first", form ).focus( );
      } else {
        $( "textarea:visible:first", form ).focus( );
      }
      // Note that you need to scroll the element that can actually scroll.
      // There are a lot of nested divs here, so make sure you're scrolling the
      // right one
      $( ".info-tab-content", sidebar ).scrollTo( form );
    };

    const qualityGrade = ( ) => {
      if ( observation.quality_grade === "research" ) {
        return I18n.t( "research_grade" );
      }
      if ( observation.quality_grade === "needs_id" ) {
        return I18n.t( "needs_id_" );
      }
      return I18n.t( "casual_" );
    };

    const defaultShortcuts = [
      { keys: ["x"], label: I18n.t( "organism_appears_captive_cultivated" ) },
      { keys: ["r"], label: I18n.t( "mark_as_reviewed" ) },
      { keys: ["c"], label: I18n.t( "comment_" ), skipBlind: true },
      { keys: ["a"], label: I18n.t( "agree_" ), skipBlind: true },
      { keys: ["i"], label: I18n.t( "add_id" ) },
      { keys: ["f"], label: I18n.t( "add_to_favorites" ) },
      { keys: ["z"], label: I18n.t( "zoom_photo" ) },
      { keys: ["&larr;"], label: I18n.t( "previous_observation" ) },
      { keys: ["&rarr;"], label: I18n.t( "next_observation" ) },
      { keys: ["SHIFT", "&larr;"], label: I18n.t( "previous_tab" ) },
      { keys: ["SHIFT", "&rarr;"], label: I18n.t( "next_tab" ) },
      { keys: ["ALT/CMD", "&larr;"], label: I18n.t( "previous_photo" ) },
      { keys: ["ALT/CMD", "&rarr;"], label: I18n.t( "next_photo" ) },
      { keys: ["?"], label: I18n.t( "show_keyboard_shortcuts" ) }
    ];

    const defaultShortcutsBody = (
      <tbody>
        {
          defaultShortcuts.map( shortcut => (
            blind && shortcut.skipBlind ? null : (
              <tr
                className="keyboard-shortcuts"
                key={`keyboard-shortcuts-${shortcut.keys.join( "-" )}`}
              >
                <td>
                  <span dangerouslySetInnerHTML={{ __html: shortcut.keys.map( k => `<code>${k}</code>` ).join( " + " ) }} />
                </td>
                <td>{ shortcut.label }</td>
              </tr>
            )
          ) )
        }
      </tbody>
    );

    let activeTabs = tabs;
    if ( blind ) {
      activeTabs = [activeTabs[0]];
    }
    let activeTab = tab;
    if ( activeTabs.indexOf( activeTab ) < 0 ) {
      activeTab = activeTabs[0];
    }

    const annoShortcuts = [];
    if ( activeTab === "annotations" ) {
      controlledTerms.forEach( ct => {
        let availableValues = _.filter( ct.values, v => v.label );
        if ( observation.taxon ) {
          availableValues = _.filter( availableValues, v => (
            !v.taxon_ids
            || _.intersection( observation.taxon.ancestor_ids, v.taxon_ids ).length > 0
          ) );
        }
        availableValues.forEach( v => {
          const shortcut = _.find(
            annotationShortcuts,
            as => as.term === ct.label && v.label === as.value
          );
          if ( shortcut ) {
            annoShortcuts.push( {
              attributeLabel: ct.label,
              valueLabel: v.label,
              keys: shortcut.shortcut.split( " " )
            } );
          }
        } );
      } );
    }

    const country = _.find( observation.places || [], p => p.admin_level === 0 );
    let dateTimeObserved = I18n.t( "unknown" );
    if ( observation.observed_on ) {
      if ( observation.time_observed_at ) {
        dateTimeObserved = formattedDateTimeInTimeZone(
          observation.time_observed_at, observation.observed_time_zone
        );
      } else {
        dateTimeObserved = moment( observation.observed_on ).format( "LL" );
      }
    }
    return (
      <Modal
        show={visible}
        onHide={onClose}
        bsSize="large"
        backdrop
        className={`ObservationModal FullScreenModal ${blind ? "blind" : ""}`}
      >
        <div className="nav-buttons">
          { hidePrevNext ? null : (
            <Button alt={I18n.t( "previous" )} className="nav-button" onClick={( ) => showPrevObservation( )}>
              &lsaquo;
            </Button>
          ) }
          { hidePrevNext ? null : (
            <Button alt={I18n.t( "next" )} className="next nav-button" onClick={( ) => showNextObservation( )}>
              &rsaquo;
            </Button>
          ) }
          <Button alt={I18n.t( "close" )} className="close-button nav-button" onClick={onClose}>
            &times;
          </Button>
        </div>
        <div className="inner">
          <div className="left-col">
            <div className="obs-modal-header">
              <div className={`quality_grade pull-right ${observation.quality_grade}`}>
                { qualityGrade( ) }
              </div>
              { blind ? null : (
                <SplitTaxon
                  taxon={observation.taxon}
                  url={`/observations/${observation.id}`}
                  target="_blank"
                  placeholder={observation.species_guess}
                  user={currentUser}
                  noParens
                />
              ) }
            </div>
            <div className="obs-media">
              { photos }
              { sounds }
            </div>
            { hideTools ? null : (
              <div className="tools">
                <div className="keyboard-shortcuts-container">
                  <Button
                    bsStyle="link"
                    className="btn-keyboard-shortcuts"
                    onClick={e => {
                      toggleKeyboardShortcuts( keyboardShortcutsShown );
                      e.preventDefault( );
                      return false;
                    }}
                  >
                    <i className="fa fa-keyboard-o" />
                  </Button>
                  <Overlay
                    placement="top"
                    show={keyboardShortcutsShown}
                    container={$( ".ObservationModal" ).get( 0 )}
                    target={( ) => $( ".keyboard-shortcuts-container > .btn" ).get( 0 )}
                  >
                    <Popover title={I18n.t( "keyboard_shortcuts" )} id="keyboard-shortcuts-popover">
                      <table>
                        { annoShortcuts.length === 0 ? defaultShortcutsBody : (
                          <tbody>
                            <tr>
                              <td className="default-shortcuts">
                                <table>
                                  { defaultShortcutsBody }
                                </table>
                              </td>
                              <td className="anno-shortcuts">
                                <table>
                                  <tbody>
                                    {
                                      annoShortcuts.map( shortcut => {
                                        // If you add more controlled terms, you'll need to
                                        // add keys like
                                        // add_plant_phenology_flowering_annotation to
                                        // inaturalist.rake generate_translations_js
                                        const labelKey = _.snakeCase( `add ${shortcut.attributeLabel} ${shortcut.valueLabel} annotation` );
                                        return (
                                          <tr
                                            className="keyboard-shortcuts"
                                            key={`keyboard-shortcuts-${labelKey}`}
                                          >
                                            <td>
                                              <code>{ shortcut.keys[0] }</code>
                                              { " " }
                                              { I18n.t( "then_keybord_sequence" ) }
                                              { " " }
                                              <code>{ shortcut.keys[1] }</code>
                                            </td>
                                            <td>
                                              {
                                                I18n.t( labelKey, {
                                                  defaultValue: `Add "${shortcut.attributeLabel}: ${shortcut.valueLabel}" annotation`
                                                } )
                                              }
                                            </td>
                                          </tr>
                                        );
                                      } )
                                    }
                                  </tbody>
                                </table>
                              </td>
                            </tr>
                          </tbody>
                        ) }
                      </table>
                    </Popover>
                  </Overlay>
                </div>
                <div className="action-tools">
                  { blind ? null : <div className="btn"><FavesContainer /></div> }
                  <OverlayTrigger
                    placement="top"
                    trigger={["hover", "focus"]}
                    delayShow={1000}
                    overlay={(
                      <Tooltip id="captive-btn-tooltip">
                        { I18n.t( "organism_appears_captive_cultivated" ) }
                      </Tooltip>
                    )}
                    container={$( "#wrapper.bootstrap" ).get( 0 )}
                  >
                    <label
                      className={
                        `btn btn-link btn-checkbox ${captiveByCurrentUser ? "checked" : ""}`
                      }
                    >
                      <input
                        type="checkbox"
                        checked={captiveByCurrentUser || false}
                        onChange={function ( ) {
                          toggleCaptive( );
                        }}
                      />
                      { " " }
                      { I18n.t( "captive_cultivated" ) }
                    </label>
                  </OverlayTrigger>
                  <OverlayTrigger
                    placement="top"
                    delayShow={1000}
                    overlay={(
                      <Tooltip id={`modal-reviewed-tooltip-${observation.id}`}>
                        { I18n.t( "mark_as_reviewed" ) }
                      </Tooltip>
                    )}
                    container={$( "#wrapper.bootstrap" ).get( 0 )}
                  >
                    <label
                      className={
                        `btn btn-link btn-checkbox ${( observation.reviewedByCurrentUser || reviewedByCurrentUser ) ? "checked" : ""}`
                      }
                    >
                      <input
                        type="checkbox"
                        checked={
                          observation.reviewedByCurrentUser || reviewedByCurrentUser || false
                        }
                        onChange={function ( ) {
                          toggleReviewed( );
                        }}
                      />
                      { I18n.t( "reviewed" ) }
                    </label>
                  </OverlayTrigger>
                </div>
              </div>
            ) }
          </div>
          <div className="right-col">
            <ul className="inat-tabs">
              {activeTabs.map( tabName => (
                <li key={`obs-modal-tabs-${tabName}`} className={activeTab === tabName ? "active" : ""}>
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={e => {
                      e.preventDefault( );
                      chooseTab( tabName, { observation } );
                      return false;
                    }}
                  >
                    {
                      tabTitles[tabName]
                      || I18n.t( _.snakeCase( tabName ), { defaultValue: tabName } )
                    }
                  </button>
                </li>
              ) ) }
            </ul>
            <div className="sidebar">
              { activeTabs.indexOf( "info" ) < 0 ? null : (
                <div className={`inat-tab info-tab ${activeTab === "info" ? "active" : ""}`}>
                  <div className="info-tab-content">
                    <div className="info-tab-inner">
                      <div className="map-and-details">
                        { taxonMap }
                        <div className="details">
                          <ul>
                            { blind ? null : (
                              <li className="user-obs-count">
                                <a
                                  href={`/people/${observation.user.login}`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="user-link"
                                >
                                  <i className="icon-person bullet-icon" />
                                  { " " }
                                  <span className="login">{ observation.user.login }</span>
                                </a>
                                <span className="separator">&bull;</span>
                                <a
                                  href={`/observations?user_id=${observation.user.login}&verifiable=any&place_id=any`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                >
                                  <i className="fa fa-binoculars" />
                                  { " " }
                                  {
                                    I18n.toNumber(
                                      observation.user.observations_count,
                                      { precision: 0 }
                                    )
                                  }
                                </a>
                              </li>
                            ) }
                            <li>
                              <i className="fa fa-calendar bullet-icon" />
                              { " " }
                              { dateTimeObserved }
                            </li>
                            <li>
                              <i className="fa fa-map-marker bullet-icon" />
                              { " " }
                              { observation.place_guess || I18n.t( "unknown" ) }
                            </li>
                            { observation.positional_accuracy && (
                              <li>
                                <i className="fa fa-circle-o bullet-icon" />
                                { `${I18n.t( "label_colon", { label: I18n.t( "acc" ) } )}` }
                                { " " }
                                { I18n.toNumber( observation.positional_accuracy, { precision: 0 } ) }
                              </li>
                            ) }
                            <li>
                              <i className="fa fa-globe bullet-icon" />
                              { " " }
                              { country ? (
                                I18n.t( `places_name.${_.snakeCase( country.name )}`, { defaultValue: country.name } ) || I18n.t( "somewhere_on_earth" )
                              ) : I18n.t( "somewhere_on_earth" ) }
                            </li>
                            { blind ? null : (
                              <li className="view-follow">
                                <a
                                  className="permalink"
                                  href={`/observations/${observation.id}`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                >
                                  <i className="icon-link-external bullet-icon" />
                                  { I18n.t( "view" ) }
                                </a>
                                { observation.user.id === currentUser.id ? null : (
                                  <div style={{ display: "inline-block" }}>
                                    <span className="separator">&bull;</span>
                                    <FollowButtonContainer observation={observation} btnClassName="btn btn-link" />
                                  </div>
                                ) }
                              </li>
                            ) }
                          </ul>
                          { mapZoomLevel !== undefined && mapZoomLevelLocked !== undefined && (
                            <div>
                              <label className="zoom-level-lock-control">
                                <input
                                  type="checkbox"
                                  defaultChecked={mapZoomLevelLocked}
                                  onChange={e => setMapZoomLevelLocked( e.target.checked )}
                                />
                                { I18n.t( "lock_zoom_level" ) }
                              </label>
                            </div>
                          ) }
                        </div>
                      </div>
                      { blind ? null : (
                        <UserText
                          text={observation.description}
                          truncate={200}
                          className="observation-description"
                        />
                      ) }
                      <DiscussionListContainer observation={observation} />
                      <center className={loadingDiscussionItem ? "loading" : "loading collapse"}>
                        <div className="big loading_spinner" />
                      </center>
                      <CommentFormContainer
                        key={`comment-form-obs-${observation.id}`}
                        observation={observation}
                        className={commentFormVisible ? "" : "collapse"}
                        ref={elt => {
                          const domNode = ReactDOM.findDOMNode( elt );
                          if ( domNode && commentFormVisible ) {
                            scrollSidebarToForm( domNode );
                            if (
                              $( "textarea", domNode ).val() === ""
                              && $( ".IdentificationForm textarea" ).val() !== ""
                            ) {
                              $( "textarea", domNode ).val( $( ".IdentificationForm textarea" ).val( ) );
                            }
                          }
                        }}
                      />
                      <IdentificationFormContainer
                        key={`identification-form-obs-${observation.id}`}
                        observation={observation}
                        className={identificationFormVisible ? "" : "collapse"}
                        ref={elt => {
                          const domNode = ReactDOM.findDOMNode( elt );
                          if ( domNode && identificationFormVisible ) {
                            scrollSidebarToForm( domNode );
                            if (
                              $( "textarea", domNode ).val() === ""
                              && $( ".CommentForm textarea" ).val() !== ""
                            ) {
                              $( "textarea", domNode ).val( $( ".CommentForm textarea" ).val( ) );
                            }
                          }
                        }}
                      />
                    </div>
                  </div>
                  <div className="tools">
                    <Button bsStyle="default" onClick={( ) => addIdentification( )}>
                      <i className="icon-identification" />
                      { " " }
                      { I18n.t( "add_id" ) }
                    </Button>
                    <Button
                      bsStyle="default"
                      className="comment-btn"
                      onClick={( ) => addComment( )}
                    >
                      <i className="fa fa-comment" />
                      { " " }
                      { I18n.t( "comment_" ) }
                    </Button>
                  </div>
                </div>
              ) }
              { activeTabs.indexOf( "suggestions" ) < 0 ? null : (
                <div className={`inat-tab suggestions-tab ${activeTab === "suggestions" ? "active" : ""}`}>
                  <SuggestionsContainer chooseTaxon={chooseSuggestedTaxon} />
                </div>
              ) }
              { activeTabs.indexOf( "annotations" ) < 0 ? null : (
                <div className={`inat-tab annotations-tab ${activeTab === "annotations" ? "active" : ""}`}>
                  <div className="column-header">{ I18n.t( "annotations" ) }</div>
                  <AnnotationsContainer />
                  <div className="column-header">{ I18n.t( "observation_fields" ) }</div>
                  <ObservationFieldsContainer />
                </div>
              ) }
              { activeTabs.indexOf( "data-quality" ) < 0 ? null : (
                <div className={`inat-tab data-quality-tab ${activeTab === "data-quality" ? "active" : ""}`}>
                  <QualityMetricsContainer />
                </div>
              ) }
            </div>
          </div>
        </div>
      </Modal>
    );
  }
}

ObservationModal.propTypes = {
  addComment: PropTypes.func,
  addIdentification: PropTypes.func,
  blind: PropTypes.bool,
  captiveByCurrentUser: PropTypes.bool,
  chooseSuggestedTaxon: PropTypes.func,
  chooseTab: PropTypes.func,
  commentFormVisible: PropTypes.bool,
  controlledTerms: PropTypes.array,
  currentUser: PropTypes.object,
  hidePrevNext: PropTypes.bool,
  hideTools: PropTypes.bool,
  identificationFormVisible: PropTypes.bool,
  images: PropTypes.array,
  imagesCurrentIndex: PropTypes.number,
  keyboardShortcutsShown: PropTypes.bool,
  loadingDiscussionItem: PropTypes.bool,
  observation: PropTypes.object,
  onClose: PropTypes.func.isRequired,
  reviewedByCurrentUser: PropTypes.bool,
  setImagesCurrentIndex: PropTypes.func,
  showNextObservation: PropTypes.func,
  showPrevObservation: PropTypes.func,
  tab: PropTypes.string,
  tabs: PropTypes.array,
  tabTitles: PropTypes.object,
  toggleCaptive: PropTypes.func,
  toggleKeyboardShortcuts: PropTypes.func,
  toggleReviewed: PropTypes.func,
  updateCurrentUser: PropTypes.func,
  visible: PropTypes.bool,
  mapZoomLevel: PropTypes.number,
  onMapZoomChanged: PropTypes.func,
  mapZoomLevelLocked: PropTypes.bool,
  setMapZoomLevelLocked: PropTypes.func
};

ObservationModal.defaultProps = {
  controlledTerms: [],
  imagesCurrentIndex: 0,
  tabs: TABS,
  tabTitles: {}
};

export default ObservationModal;
