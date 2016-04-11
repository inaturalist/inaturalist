import React, { PropTypes, Component } from "react";
import { Grid, Row, Col, Button, Glyphicon } from "react-bootstrap";
import Dropzone from "react-dropzone";
import ObsCardComponent from "./obs_card_component";
import LocationChooser from "./location_chooser";
import StatusModal from "./status_modal";
import LeftMenu from "./left_menu";
import TopMenu from "./top_menu";
import _ from "lodash";

class DragDropZone extends Component {

  constructor( props, context ) {
    super( props, context );
    this.fileChooser = this.fileChooser.bind( this );
    this.selectObsCards = this.selectObsCards.bind( this );
  }

  componentDidUpdate( ) {
    if ( Object.keys( this.props.obsCards ).length > 0 ) {
      $( "#imageGrid" ).selectable( { filter: ".card",
        cancel: ".glyphicon, input, button, .input-group-addon, " +
          ".bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
        selecting: this.selectObsCards,
        unselecting: this.selectObsCards
      } );
      $( "#imageGrid" ).selectable( "enable" );
    } else {
      $( "#imageGrid" ).selectable( "disable" );
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

  render( ) {
    const { onDrop, updateObsCard, removeObsCard, onCardDrop, updateSelectedObsCards,
      obsCards, submitObservations, createBlankObsCard, selectedObsCards, locationChooser,
      selectAll, removeSelected, mergeObsCards, saveStatus, saveCounts, setState,
      updateState } = this.props;
    let leftColumn;
    let intro;
    let mainColumnSpan = 12;
    let className = "uploader";
    const obsCardsArray = Object.values( obsCards );
    if ( obsCardsArray.length > 0 ) {
      mainColumnSpan = 9;
      className += " populated";
      let leftMenu;
      if ( Object.keys( selectedObsCards ).length > 0 ) {
        leftMenu = (
          <LeftMenu
            setState={this.props.setState}
            selectedObsCards={this.props.selectedObsCards}
            updateSelectedObsCards={this.props.updateSelectedObsCards}
          />
        );
      } else {
        leftMenu = "Select photos";
      }
      leftColumn = (
        <Col xs={ 3 } className="leftColumn">
          { leftMenu }
        </Col>
      );
    } else {
      intro = (
        <div className="intro">
          <div className="start">
            <p>Drag and drop some photos</p>
            <p>or</p>
            <Button bsStyle="primary" bsSize="large" onClick={ () => this.onOpenClick( ) }>
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
        <Dropzone ref="dropzone" onDrop={ onDrop } className={ className } activeClassName="hover"
          disableClick disablePreview
        >
          <Grid fluid>
            <TopMenu
              createBlankObsCard={ createBlankObsCard }
              removeSelected={ removeSelected }
              selectAll={ selectAll }
              submitObservations={ submitObservations }
              fileChooser={ this.fileChooser }
              count={ obsCardsArray.length }
            />
            <Row>
              { leftColumn }
              <Col xs={ mainColumnSpan } id="imageGrid">
                <div>
                  { _.map( obsCards, obsCard => (
                    <ObsCardComponent key={ obsCard.id }
                      obsCard={ obsCard }
                      onCardDrop={ onCardDrop }
                      updateObsCard={ updateObsCard }
                      mergeObsCards={ mergeObsCards }
                      removeObsCard={ ( ) => removeObsCard( obsCard ) }
                      setState={ setState }
                    />
                  ) ) }
                </div>
                { intro }
              </Col>
            </Row>
          </Grid>
        </Dropzone>
        <StatusModal show={saveStatus === "saving"} saveCounts={saveCounts}
          total={obsCardsArray.length} className="status"
        />
        <LocationChooser
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
  setState: PropTypes.func,
  updateState: PropTypes.func
};

export default DragDropZone;
