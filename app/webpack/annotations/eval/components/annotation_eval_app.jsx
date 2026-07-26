import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import {
  Grid, Row, Col, Button, Glyphicon
} from "react-bootstrap";
import Dropzone from "react-dropzone";
import ObservationPanelContainer from "../containers/observation_panel_container";
import AnnotationsTable from "./annotations_table";
import AnnotationsMeta from "./annotations_meta";
import RawResponse from "./raw_response";

/* eslint react/no-string-refs: 0 */

class AnnotationEvalApp extends Component {
  constructor( props, context ) {
    super( props, context );
    this.initialDisplay = this.initialDisplay.bind( this );
    this.results = this.results.bind( this );
    this.state = { observationID: "" };
  }

  initialDisplay( ) {
    const { lookupObservation, error } = this.props;
    const { observationID } = this.state;
    return (
      <Grid fluid>
        <Row>
          <Col md={12}>
            <div className="intro">
              <div className="start">
                <div className="drag_or_choose">
                  <h1>Drag &amp; drop a photo of wildlife</h1>
                  <p>{ I18n.t( "or" ) }</p>
                  <Button
                    bsStyle="primary"
                    bsSize="large"
                    onClick={( ) => { this.refs.dropzone.open( ); }}
                  >
                    Choose photo
                    <Glyphicon glyph="upload" />
                  </Button>
                  <p>{ I18n.t( "or" ) }</p>
                  Enter observation ID:
                  <input
                    name="observation_id"
                    id="observation_id"
                    type="text"
                    value={observationID}
                    onChange={e => this.setState( { observationID: e.target.value } )}
                    onKeyPress={e => {
                      if ( e.key === "Enter" && observationID ) {
                        lookupObservation( observationID );
                      }
                    }}
                  />
                  <Button
                    bsStyle="success"
                    bsSize="small"
                    disabled={!observationID}
                    onClick={( ) => lookupObservation( observationID )}
                  >
                    Go
                  </Button>
                  { error && <p className="text-danger">{ error }</p> }
                </div>
              </div>
              <div className="hover">
                <p>{ I18n.t( "drop_it" ) }</p>
              </div>
            </div>
          </Col>
        </Row>
      </Grid>
    );
  }

  results( ) {
    const {
      annotations, annotationsMeta, species, status, rawResponse
    } = this.props;
    if ( status === "loading" ) {
      return (
        <div className="statement">
          Scoring…
          <div className="loading_spinner" />
        </div>
      );
    }
    if ( _.isEmpty( annotations ) ) { return null; }
    return (
      <div className="annotations-results">
        <AnnotationsTable annotations={annotations} />
        <AnnotationsMeta meta={annotationsMeta} species={species} />
        <RawResponse response={rawResponse} />
      </div>
    );
  }

  mainContent( ) {
    const { obsCard, resetState, rescore } = this.props;
    if ( !obsCard ) { return this.initialDisplay( ); }
    return (
      <Grid fluid className="main-content">
        <ObservationPanelContainer />
        <div className="actions">
          <Button bsStyle="success" onClick={( ) => rescore( )}>
            Re-score
          </Button>
          <Button onClick={resetState}>
            Reset
          </Button>
        </div>
        { this.results( ) }
      </Grid>
    );
  }

  render( ) {
    const { onFileDrop } = this.props;
    return (
      <Dropzone
        ref="dropzone"
        onDrop={( acceptedFiles, rejectedFiles, dropEvent ) => {
          if ( dropEvent.nativeEvent.dataTransfer
            && dropEvent.nativeEvent.dataTransfer.items
            && dropEvent.nativeEvent.dataTransfer.items.length > 0
            && dropEvent.nativeEvent.dataTransfer.items[0].kind === "string" ) {
            return;
          }
          _.each( acceptedFiles, file => {
            try {
              file.preview = file.preview || window.URL.createObjectURL( file );
            } catch ( err ) {
              // eslint-disable-next-line no-console
              console.error( "Failed to generate preview for file", file, err );
            }
          } );
          onFileDrop( acceptedFiles );
        }}
        className="uploader"
        activeClassName="hover"
        disableClick
        disablePreview
        accept="image/jpeg,image/png,image/gif"
        multiple={false}
      >
        <nav className="navbar navbar-default">
          <div className="container-fluid">
            <div className="navbar-header">
              <div className="logo">
                <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                  <img alt="Site Logo" src={SITE.logo} />
                </a>
              </div>
              <div className="title">
                Annotation Eval
              </div>
            </div>
          </div>
        </nav>
        { this.mainContent( ) }
      </Dropzone>
    );
  }
}

AnnotationEvalApp.propTypes = {
  obsCard: PropTypes.object,
  annotations: PropTypes.array,
  annotationsMeta: PropTypes.object,
  species: PropTypes.object,
  status: PropTypes.string,
  rawResponse: PropTypes.object,
  error: PropTypes.string,
  onFileDrop: PropTypes.func,
  lookupObservation: PropTypes.func,
  rescore: PropTypes.func,
  resetState: PropTypes.func
};

export default AnnotationEvalApp;
