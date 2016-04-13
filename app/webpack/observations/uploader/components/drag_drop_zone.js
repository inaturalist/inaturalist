import React, { PropTypes, Component } from "react";
import { Grid, Row, Col, Button, Glyphicon } from "react-bootstrap";
import Dropzone from "react-dropzone";
import ObsCardComponent from "./obs_card_component";
import LocationChooser from "./location_chooser";
import StatusModal from "./status_modal";
import LeftMenu from "./left_menu";
import TopMenu from "./top_menu";
import RemoveModal from "./remove_modal";
import _ from "lodash";

class DragDropZone extends Component {

  constructor( props, context ) {
    super( props, context );
    this.fileChooser = this.fileChooser.bind( this );
    this.selectObsCards = this.selectObsCards.bind( this );
    this.unselectAll = this.unselectAll.bind( this );
  }

  componentDidUpdate( ) {
    if ( Object.keys( this.props.obsCards ).length > 0 ) {
      if ( this.props.saveStatus !== "saving" ) {
        window.onbeforeunload = ( ) =>
          "These observations have not been uploaded yet.";
      } else {
        window.onbeforeunload = undefined;
      }
      $( "body" ).unbind( "click" );
      $( "body" ).on( "click", this.unselectAll );
      $( "#imageGrid" ).selectable( { filter: ".card",
        cancel: ".glyphicon, input, button, .input-group-addon, " +
          ".bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
        selecting: this.selectObsCards,
        unselecting: this.selectObsCards,
        distance: 0
      } );
      $( "#imageGrid" ).selectable( "enable" );
    } else {
      $( "#imageGrid" ).selectable( "disable" );
      window.onbeforeunload = undefined;
    }
  }

  fileChooser( ) {
    this.refs.dropzone.open( );
  }

  selectObsCards( ) {
    const selectedIDs = { };
    $( ".card.ui-selecting, .card.ui-selected" ).each( function ( ) {
      selectedIDs[$( this ).data( "id" )] = true;
    } );
    this.props.selectObsCards( selectedIDs );
  }

  unselectAll( e ) {
    if ( $( ".card, #multiMenu, button, .modal" ).
           has( e.target || e.nativeEvent.target ).length > 0 ) {
      return;
    }
    this.props.selectObsCards( {} );
  }

  render( ) {
    const { onDrop, updateObsCard, confirmRemoveObsCard, onCardDrop, updateSelectedObsCards,
      obsCards, submitObservations, createBlankObsCard, selectedObsCards, locationChooser,
      selectAll, removeSelected, mergeObsCards, saveStatus, saveCounts, setState,
      updateState, removeModal, confirmRemoveSelected, removeObsCard,
      selectObsCards } = this.props;
    let leftColumn;
    let intro;
    let mainColumnSpan = 12;
    let className = "uploader";
    const cardCount = Object.keys( obsCards ).length;
    if ( cardCount > 0 ) {
      mainColumnSpan = 9;
      className += " populated";
      leftColumn = (
        <Col xs={ 3 } className="leftColumn">
          <LeftMenu
            count={cardCount}
            setState={this.props.setState}
            selectedObsCards={this.props.selectedObsCards}
            updateSelectedObsCards={this.props.updateSelectedObsCards}
          />
        </Col>
      );
    } else {
      intro = (
        <div className="intro">
          <div className="start">
            <p>Drag and drop some photos</p>
            <p>or</p>
            <Button bsStyle="primary" bsSize="large" onClick={ ( ) => this.fileChooser( ) }>
              Choose photos
              <Glyphicon glyph="upload" />
            </Button>
          </div>
          <div className="hover">
            <p>Drop it</p>
          </div>
        </div>
      );
    }
    return (
      <div>
        <Dropzone
          ref="dropzone"
          onDrop={ onDrop }
          className={ className }
          activeClassName="hover"
          disableClick
          disablePreview
        >
          <Grid fluid>
            <TopMenu
              createBlankObsCard={ createBlankObsCard }
              confirmRemoveSelected={ confirmRemoveSelected }
              selectAll={ selectAll }
              selectedObsCards={ selectedObsCards }
              submitObservations={ submitObservations }
              fileChooser={ this.fileChooser }
              count={ cardCount }
            />
            <Row className="body">
              { leftColumn }
              <Col xs={ mainColumnSpan } id="imageGrid">
                <div>
                  { _.map( obsCards, obsCard => (
                    <ObsCardComponent key={ obsCard.id }
                      obsCard={ obsCard }
                      onCardDrop={ onCardDrop }
                      updateObsCard={ updateObsCard }
                      mergeObsCards={ mergeObsCards }
                      selectObsCards={ selectObsCards }
                      confirmRemoveObsCard={ ( ) => confirmRemoveObsCard( obsCard ) }
                      setState={ setState }
                    />
                  ) ) }
                </div>
                { intro }
              </Col>
            </Row>
          </Grid>
        </Dropzone>
        <StatusModal
          show={ saveStatus === "saving" }
          saveCounts={ saveCounts }
          total={ cardCount } className="status"
        />
        <RemoveModal
          setState={ setState }
          removeObsCard={ removeObsCard }
          removeSelected={ removeSelected }
          { ...removeModal }
        />
        <LocationChooser
          obsCards={ obsCards }
          setState={ setState }
          updateObsCard={ updateObsCard }
          updateState={ updateState }
          updateSelectedObsCards={ updateSelectedObsCards }
          { ...locationChooser }
        />
      </div>
    );
  }
}

DragDropZone.propTypes = {
  onDrop: PropTypes.func.isRequired,
  updateObsCard: PropTypes.func,
  removeObsCard: PropTypes.func,
  confirmRemoveObsCard: PropTypes.func,
  obsCards: PropTypes.object,
  selectedObsCards: PropTypes.object,
  submitObservations: PropTypes.func,
  createBlankObsCard: PropTypes.func,
  selectObsCards: PropTypes.func,
  updateSelectedObsCards: PropTypes.func,
  onCardDrop: PropTypes.func,
  selectAll: PropTypes.func,
  removeSelected: PropTypes.func,
  mergeObsCards: PropTypes.func,
  saveStatus: PropTypes.string,
  saveCounts: PropTypes.object,
  locationChooser: PropTypes.object,
  removeModal: PropTypes.object,
  setState: PropTypes.func,
  updateState: PropTypes.func,
  confirmRemoveSelected: PropTypes.func
};

export default DragDropZone;
