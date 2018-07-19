import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Dropzone from "react-dropzone";
import { DropTarget } from "react-dnd";
import { pipe } from "ramda";
import ConfirmModal from "./confirm_modal";
import LeftMenu from "./left_menu";
import LocationChooser from "./location_chooser";
import ObsCardComponent from "./obs_card_component";
import OpeningActionMenu from "./opening_action_menu";
import PhotoViewer from "./photo_viewer";
import RemoveModal from "./remove_modal";
import StatusModal from "./status_modal";
import TopMenu from "./top_menu";
import HeaderUserMenu from "./header_user_menu";
import { ACCEPTED_FILE_TYPES } from "../models/util";

const fileTarget = {
  drop( props, monitor, component ) {
    if ( monitor.didDrop( ) ) { return; }
    const item = monitor.getItem( );
    const dropResult = component.props;
    if ( dropResult ) {
      props.newCardFromMedia( item, dropResult.obsCard );
    }
  }
};

class DragDropZone extends Component {

  static fileDrop( connect, monitor ) {
    return {
      connectDropTarget: connect.dropTarget( ),
      fileIsOver: monitor.isOver( ),
      canDrop: monitor.canDrop( )
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.fileChooser = this.fileChooser.bind( this );
    this.selectObsCards = this.selectObsCards.bind( this );
    this.unselectAll = this.unselectAll.bind( this );
    this.selectCard = this.selectCard.bind( this );
    this.resize = this.resize.bind( this );
    this.selectNone = this.selectNone.bind( this );
  }

  componentDidMount( ) {
    this.resize( );
    $( window ).on( "resize", this.resize );
    $( "body" ).unbind( "keydown keyup click" );
    const commandKeys = [17, 91, 93, 224];
    const shiftKeys = [16];
    $( "body" ).on( "keydown", e => {
      if ( _.includes( commandKeys, e.which ) ) {
        this.props.setState( { commandKeyPressed: true } );
      } else if ( _.includes( shiftKeys, e.which ) ) {
        this.props.setState( { shiftKeyPressed: true } );
      }
    } );
    $( "body" ).on( "keyup", e => {
      if ( _.includes( commandKeys, e.which ) ) {
        this.props.setState( { commandKeyPressed: false } );
      } else if ( _.includes( shiftKeys, e.which ) ) {
        this.props.setState( { shiftKeyPressed: false } );
      }
    } );
    $( "body" ).on( "click", this.unselectAll );
    $( ".uploader" ).selectable( { filter: ".card",
      cancel: ".card, .glyphicon, input, button, .input-group-addon, " +
        ".input-group-addon, .intro, select, .leftColumn, " +
        ".bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
      selected: this.selectObsCards,
      unselected: this.selectObsCards,
      start: () => $( "body" ).off( "click" ),
      stop: () => setTimeout( () => $( "body" ).on( "click", this.unselectAll ), 100 ),
      distance: 1
    } );
    // prevent these keys from being stuck in the "pressed" state
    $( window ).blur( () => {
      this.props.setState( { shiftKeyPressed: false } );
      this.props.setState( { commandKeyPressed: false } );
    } );
  }

  componentDidUpdate( ) {
    this.resize( );
    const count = Object.keys( this.props.obsCards ).length;
    $( ".uploader" ).selectable( count > 0 ? "enable" : "disable" );
    if ( count > 0 && this.props.saveStatus !== "saving" ) {
      window.onbeforeunload = ( ) => I18n.t( "these_observations_have_not_been_uploaded_yet" );
    } else {
      window.onbeforeunload = undefined;
    }
  }

  closeAutocompletes( e ) {
    const ignore = "input[name='taxon_name'], .ui-autocomplete";
    const target = e.target || e.nativeEvent.target;
    if ( $( ignore ).has( target ).length > 0 ||
         $( target ).is( ignore ) ) {
      return;
    }
    $( ".ui-autocomplete" ).hide( );
  }

  fileChooser( ) {
    this.refs.dropzone.open( );
  }

  resize( ) {
    this.resizeElement( $( ".uploader" ) );
    this.resizeElement( $( "#imageGrid" ) );
    this.resizeElement( $( ".leftColumn" ) );
  }

  resizeElement( el ) {
    if ( el.length === 0 ) { return; }
    const topOffset = el.offset( ).top;
    const height = $( window ).height( );
    const difference = height - topOffset;
    if ( difference > 450 ) {
      el.css( "min-height", difference );
    }
  }

  selectObsCards( e ) {
    e.preventDefault( );
    e.stopPropagation( );
    const selectedIDs = { };
    $( ".card.ui-selecting, .card.ui-selected" ).each( function ( ) {
      selectedIDs[$( this ).data( "id" )] = true;
    } );
    this.props.selectObsCards( selectedIDs );
  }

  unselectAll( e ) {
    const ignore = "a, .card, button, .modal, span.title, .leftColumn, " +
      ".bootstrap-datetimepicker-widget, .ui-autocomplete, #react-images-container, " +
      ".navbar .select, input, .form-group, select";
    const target = e.target || e.nativeEvent.target;
    if ( $( ignore ).has( target ).length > 0 ||
         $( target ).is( ignore ) ) {
      return;
    }
    // some targets will be gone by this point, like taxon autocomplete results
    // don't count those as unselecting
    if ( $( "body" ).has( target ).length === 0 ) {
      return;
    }
    this.selectNone( );
  }

  selectNone( ) {
    $( "input, textarea" ).blur( );
    this.props.selectObsCards( { } );
  }

  selectCard( obsCard ) {
    let newSelected;
    const selectedIDs = _.keys( this.props.selectedObsCards );
    if ( this.props.commandKeyPressed ) {
      // command + click
      if ( this.props.selectedObsCards[obsCard.id] ) {
        // the card was already selected
        newSelected = Object.assign( { }, this.props.selectedObsCards );
        delete newSelected[obsCard.id];
      } else {
        newSelected = Object.assign( { }, this.props.selectedObsCards, { [obsCard.id]: true } );
      }
    } else if ( this.props.shiftKeyPressed && selectedIDs.length > 0 ) {
      // shift + click
      const firstSelected = _.min( selectedIDs );
      newSelected = Object.assign( { }, this.props.selectedObsCards );
      _.each( this.props.obsCards, ( card, id ) => {
        // select anything between the first selected and this selection
        if ( ( obsCard.id < firstSelected && _.inRange( id, obsCard.id, firstSelected ) ) ||
             ( obsCard.id > firstSelected && _.inRange( id, firstSelected, obsCard.id + 1 ) ) ) {
          newSelected[id] = true;
        }
      } );
    } else {
      // normal click
      newSelected = { [obsCard.id]: true };
    }
    this.props.selectObsCards( newSelected );
  }

  render( ) {
    const { obsCards, selectedObsCards, draggingProps } = this.props;
    let leftColumn;
    let intro;
    let className = "uploader";
    if ( draggingProps && draggingProps.obsCard ) { className += " hover"; }
    if ( this.props.fileIsOver ) { className += " fileOver"; }
    const cardCount = Object.keys( obsCards ).length;
    if ( cardCount > 0 ) {
      const keys = _.keys( selectedObsCards );
      const countSelected = _.keys( selectedObsCards ).length;
      const lastUpdate = _.max( _.map( selectedObsCards, c => c.updatedAt ) );
      const first = keys[0];
      let leftMenuKey = `leftmenu${countSelected}${first}${lastUpdate}`;
      if ( this.props.observationField ) {
        leftMenuKey += `field${this.props.observationField.id}`;
      }
      if ( this.props.observationFieldValue ) {
        leftMenuKey += this.props.observationFieldValue;
      }
      if ( this.props.observationFieldSelectedDate ) {
        leftMenuKey += this.props.observationFieldSelectedDate;
      }
      let leftClass = "col-fixed-250 leftColumn";
      leftColumn = (
        <Col className={ leftClass }>
          <LeftMenu
            reactKey={ leftMenuKey }
            count={ cardCount }
            { ...this.props }
          />
        </Col>
      );
    } else {
      intro = ( <OpeningActionMenu fileChooser={ this.fileChooser } /> );
    }
    const countSelected = _.keys( selectedObsCards ).length;
    const countSelectedPending =
      _.sum( _.map( selectedObsCards, c => c.nonUploadedFiles().length ) );
    const countPending = _.sum( _.map( obsCards, c => c.nonUploadedFiles().length ) );
    /* global SITE */
    return (
      <div onClick={ this.closeAutocompletes }>
        <Dropzone
          ref="dropzone"
          onDrop={ this.props.onDrop }
          className={ className }
          activeClassName="hover"
          disableClick
          accept={ ACCEPTED_FILE_TYPES }
        >
          <nav className="navbar navbar-default">
            <div className="container-fluid">
              <div className="navbar-header">
                <button
                  type="button"
                  className="navbar-toggle collapsed"
                  data-toggle="collapse"
                  data-target="#header-user-menu"
                  aria-expanded="false"
                >
                  <span className="sr-only">Toggle navigation</span>
                  <span className="icon-bar"></span>
                  <span className="icon-bar"></span>
                  <span className="icon-bar"></span>
                </button>
                <a href="/" className="navbar-brand" title={ SITE.name } alt={ SITE.name }>
                  <img src={ SITE.logo } />
                </a>
              </div>
              <HeaderUserMenu user={ CURRENT_USER } />
            </div>
          </nav>
          <TopMenu
            key={ `topMenu${cardCount}${countSelected}` }
            reactKey={ `topMenu${cardCount}${countSelected}` }
            selectNone={ this.selectNone }
            fileChooser={ this.fileChooser }
            countTotal={ cardCount }
            countSelected={ countSelected }
            countSelectedPending={ countSelectedPending }
            countPending={ countPending }
            { ...this.props }
          />
          <Grid fluid>
            <div className="row-fluid">
              <Col md={ 12 }>
                <Row>
                  { intro }
                </Row>
              </Col>
            </div>
          </Grid>
          <Grid fluid>
            <div className="row-fluid">
              { leftColumn }
              { this.props.connectDropTarget(
                <div id="imageGrid" className="col-offset-290 col-md-12">
                  <Row>
                    <ul className="obs">
                      { _.map( obsCards, obsCard => (
                        <ObsCardComponent
                          { ...this.props }
                          key={ obsCard.id }
                          ref={ `obsCard${obsCard.id}` }
                          obsCard={ obsCard }
                          selectCard={ this.selectCard }
                          confirmRemoveObsCard={ ( ) => this.props.confirmRemoveObsCard( obsCard ) }
                        />
                      ) ) }
                    </ul>
                  </Row>
                </div>
              ) }
            </div>
          </Grid>
        </Dropzone>
        <StatusModal
          { ...this.props }
          className="status"
          show={ this.props.saveStatus === "saving" && !this.props.confirmModal.show }
          total={ cardCount }
        />
        <ConfirmModal
          { ...this.props }
          { ...this.props.confirmModal }
        />
        <RemoveModal
          { ...this.props }
          { ...this.props.removeModal }
        />
        <LocationChooser
          { ...this.props }
          { ...this.props.locationChooser }
        />
        <PhotoViewer
          { ...this.props }
          { ...this.props.photoViewer }
        />
      </div>
    );
  }
}

DragDropZone.propTypes = {
  commandKeyPressed: PropTypes.bool,
  config: PropTypes.object,
  confirmModal: PropTypes.object,
  confirmRemoveObsCard: PropTypes.func,
  connectDropTarget: PropTypes.func,
  draggingProps: PropTypes.object,
  fileIsOver: PropTypes.bool,
  files: PropTypes.object,
  locationChooser: PropTypes.object,
  newCardFromMedia: PropTypes.func,
  obsCards: PropTypes.object,
  observationField: PropTypes.object,
  observationFieldSelectedDate: PropTypes.string,
  observationFieldValue: PropTypes.any,
  onDrop: PropTypes.func.isRequired,
  photoViewer: PropTypes.object,
  removeModal: PropTypes.object,
  removeObsCard: PropTypes.func,
  saveStatus: PropTypes.string,
  selectedObsCards: PropTypes.object,
  selectObsCards: PropTypes.func,
  setState: PropTypes.func,
  shiftKeyPressed: PropTypes.bool
};

export default pipe(
  DropTarget( ["Photo", "Sound"], fileTarget, DragDropZone.fileDrop )
)( DragDropZone );
