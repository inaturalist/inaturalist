import React, { PropTypes } from "react";
import { Grid, Row, Col, OverlayTrigger, Popover } from "react-bootstrap";
import Dropzone from "react-dropzone";
import { ChromePicker } from "react-color";

$( document ).bind( "drop dragover", e => {
  e.preventDefault( );
} );

class SharedForm extends React.Component {
  render( ) {
    const {
      project,
      setTitle,
      onFileDrop,
      updateProject
    } = this.props;
    const bgColor = project.banner_color;
    return (
      <div id="SharedForm" className="Form">
        <Grid>
          <Row className="text">
            <Col xs={12}>
              <h1>Project Details</h1>
            </Col>
          </Row>
          <Row className="first-row">
            <Col xs={4}>
              <div className={ `form-group ${project.titleError && "has-error"}` }>
                <label htmlFor="project-title">
                  Project Name
                  { project.titleError && (
                    <span className="error">{ project.titleError }</span>
                  ) }
                </label>
                <input
                  type="text"
                  className="form-control"
                  name="project-title"
                  placeholder={ "Birds of Chicago, Amazing Dragonflies, etc." }
                  defaultValue={ project.title }
                  onChange={ e => setTitle( e.target.value ) }
                />
              </div>
              <input
                type="checkbox"
                id="project-display-name"
                defaultChecked={ !project.hide_title }
                onChange={ e => updateProject( { hide_title: !e.target.checked } ) }
              />
              <label className="inline" htmlFor="project-display-name">Display project name</label>
            </Col>
            <Col xs={8}>
              <label>ProjectType</label>
              <input
                type="radio"
                id="project-type-regular"
                value="regular"
                checked={ project.project_type !== "umbrella" }
                onChange={ ( ) => updateProject( { project_type: "regular" } ) }
              />
              <label className="inline" htmlFor="project-type-regular">Regular</label>
              <input
                type="radio"
                id="project-type-umbrella"
                value="regular"
                checked={ project.project_type === "umbrella" }
                onChange={ ( ) => updateProject( { project_type: "umbrella" } ) }
              />
              <label className="inline" htmlFor="project-type-umbrella">
                Umbrella (Tracks multiple projects)
              </label>
            </Col>
          </Row>
          <Row className="styles-row">
            <Col xs={4}>
              <Dropzone
                ref="iconDropzone"
                className="dropzone"
                onDrop={ droppedFiles => onFileDrop( droppedFiles, "droppedIcon" ) }
                activeClassName="hover"
                disableClick
                accept={ "image/png,image/jpeg,image/gif" }
                multiple={ false }
              >
                <div className="icon-cell">
                  <label htmlFor="project-title">Project Icon (PNG, JPG, or GIF)</label>
                  <div className="help-text">
                    Optional icon. Should be a minimum of 72px x 72px
                    and will be cropped to a square.
                  </div>
                  <button className="btn-white"
                    onClick={ ( ) => this.refs.iconDropzone.open( ) }
                  >
                    <i className="fa fa-upload" />
                    Choose File
                  </button>
                  { project.iconURL( ) && (
                    <div className="icon-previews icon-preview">
                      <div
                        className="icon"
                        style={ { backgroundImage: `url( '${project.iconURL( )}' )` } }
                      />
                      <i
                        className="fa fa-times-circle"
                        onClick={ ( ) => updateProject( project.customIcon( ) ?
                          { iconDeleted: true } :
                          { droppedIcon: null }
                        ) }
                      />
                    </div>
                  ) }
                </div>
              </Dropzone>
            </Col>
            <Col xs={4}>
              <Dropzone
                ref="bannerDropzone"
                className="dropzone"
                onDrop={ droppedFiles => onFileDrop( droppedFiles, "droppedBanner" ) }
                activeClassName="hover"
                disableClick
                accept={ "image/*" }
                multiple={ false }
              >
                <div className="icon-cell">
                  <label htmlFor="project-title">Project Banner (PNG, JPG, or GIF)</label>
                  <div className="help-text">
                    Optional banner image. Must be 77px wide, less than 300px tall.
                  </div>
                  <button className="btn-white"
                    onClick={ ( ) => this.refs.bannerDropzone.open( ) }
                  >
                    <i className="fa fa-upload" />
                    Choose File
                  </button>
                  { project.bannerURL( ) && (
                    <div className="icon-previews icon-preview">
                      <div
                        className="banner"
                        style={ { backgroundImage: `url( '${project.bannerURL( )}' )` } }
                      />
                      <i
                        className="fa fa-times-circle"
                        onClick={ ( ) => updateProject( project.customIcon( ) ?
                          { bannerDeleted: true } :
                          { droppedBanner: null }
                        ) }
                      />
                    </div>
                  ) }
                </div>
              </Dropzone>
            </Col>
            <Col xs={4}>
              <label htmlFor="project-bgcolor">Project Summary Background Color</label>
              <div className="help-text">
                Make sure to choose a color dark enough so the white overlaid text is legible.
              </div>
              <div className="input-group">
                <OverlayTrigger
                  trigger="click"
                  rootClose
                  placement="top"
                  animation={false}
                  overlay={ (
                    <Popover id="color-picker-popover" className="color-picker">
                      <ChromePicker
                        disableAlpha
                        color={ bgColor }
                        onChange={ color => {
                          updateProject( { banner_color: color.hex } );
                          $( this.refs["bgcolor-input"] ).val( color.hex );
                        } }
                      />
                    </Popover>
                  ) }
                >
                  <div className="input-group-addon color">
                    <div className="color-preview" style={ { background: bgColor } } />
                  </div>
                </OverlayTrigger>
                <input
                  type="text"
                  ref="bgcolor-input"
                  className="form-control"
                  defaultValue={ bgColor }
                  onChange={ e => updateProject( { banner_color: e.target.value } ) }
                />
              </div>
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

SharedForm.propTypes = {
  project: PropTypes.object,
  onFileDrop: PropTypes.func,
  setTitle: PropTypes.func,
  updateProject: PropTypes.func
};

export default SharedForm;
