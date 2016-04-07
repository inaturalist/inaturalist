import React, { PropTypes, Component } from "react";
import { Grid, Row, Col, Button, Glyphicon } from "react-bootstrap";
import Dropzone from "react-dropzone";
import inatjs from "inaturalistjs";
import ObsCardComponent from "./obs_card_component";
import TaxonAutocomplete from "../../identify/components/taxon_autocomplete";

class DragDropZone extends Component {
  componentDidUpdate( ) {
    if ( Object.keys( this.props.obsCards ).length > 0 ) {
      $( "#imageGrid" ).selectable( { filter: ".card",
        cancel: ".glyphicon, input, button",
        selecting: this.selectObsCards.bind( this ),
        unselecting: this.selectObsCards.bind( this )
      } );
      $( "#imageGrid" ).selectable( "enable" );
    } else {
      $( "#imageGrid" ).selectable( "disable" );
    }
  }

  onOpenClick( ) {
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
    const { onDrop, updateObsCard, removeObsCard, updateSelectedObsCards, onCardDrop,
      obsCards, submitObservations, createBlankObsCard, selectedObsCards } = this.props;
    let leftColumn;
    let menu;
    let intro;
    let mainColumnSpan = 12;
    let className = "uploader";
    if ( Object.keys( obsCards ).length > 0 ) {
      mainColumnSpan = 9;
      className += " populated";
      let multiMenu;
      if ( Object.keys( selectedObsCards ).length > 0 ) {
        const uniqDescriptions = _.uniq( _.map( selectedObsCards, c => c.description ) );
        const uniqSelectedTaxa = _.uniq( _.map( selectedObsCards, c => c.selected_taxon ) );
        let initialSelection = ( uniqSelectedTaxa.length === 1 ) ? uniqSelectedTaxa[0] : undefined;
        let value;
        let placeholder = "Enter description";
        if ( uniqDescriptions.length > 1 ) {
          placeholder = "Edit multiple descriptions";
        } else if ( uniqDescriptions.length === 1 ) {
          value = uniqDescriptions[0];
        }
        multiMenu = (
          <div>
            <TaxonAutocomplete
              bootstrapClear
              searchExternal={false}
              initialSelection={ initialSelection }
              afterSelect={ function ( result ) {
                updateSelectedObsCards( { taxon_id: result.item.id,
                  selected_taxon: new inatjs.Taxon( result.item ) } );
              } }
              afterUnselect={ function ( ) {
                updateSelectedObsCards( { taxon_id: undefined, selected_taxon: undefined } );
              } }
            />
            <input type="text" placeholder={ placeholder } value={ value }
              onChange={ e => updateSelectedObsCards( { description: e.target.value } ) }
            />
          </div>
        );
      } else {
        multiMenu = "Select photos";
      }
      leftColumn = (
        <Col xs={ 3 } className="leftColumn">
          { multiMenu }
        </Col>
      );
    } else {
      intro = (
        <div className="intro">
          <div className="start">
            <p>Drag and drop some photos</p>
            <p>or</p>
            <Button bsStyle="primary" bsSize="large" onClick={ this.onOpenClick.bind( this ) }>
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
    menu = (
      <Row>
        <Col cs="12" className="conrol-menu">
          <Button bsStyle="primary" bsSize="large" onClick={ createBlankObsCard }>
            New/Blank
            <Glyphicon glyph="file" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ this.onOpenClick.bind( this ) }>
            Add
            <Glyphicon glyph="plus" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ () => {} }>
            Remove
            <Glyphicon glyph="minus" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ submitObservations }>
            Submit
            <Glyphicon glyph="floppy-saved" />
          </Button>
        </Col>
      </Row>
    );
    return (
      <Dropzone ref="dropzone" onDrop={ onDrop } className={ className } activeClassName="hover"
        disableClick disablePreview
      >
        <Grid fluid>
          { menu }
          <Row>
            { leftColumn }
            <Col xs={ mainColumnSpan } id="imageGrid">
              <div>
                { _.map( obsCards, ( obsCard ) => (
                    <ObsCardComponent key={obsCard.id}
                      obsCard={obsCard}
                      onCardDrop={onCardDrop}
                      updateObsCard={ updateObsCard }
                      removeObsCard={ ( ) => removeObsCard( obsCard ) }
                    />
                ) ) }
              </div>
              { intro }
            </Col>
          </Row>
        </Grid>
      </Dropzone>
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
  onCardDrop: PropTypes.func
};

export default DragDropZone;
