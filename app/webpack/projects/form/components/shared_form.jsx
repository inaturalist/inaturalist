import React, { PropTypes } from "react";
import { Grid, Row, Col, OverlayTrigger, Popover, Overlay } from "react-bootstrap";
import Dropzone from "react-dropzone";
import { ChromePicker } from "react-color";

$( document ).bind( "drop dragover", e => {
  e.preventDefault( );
} );

class SharedForm extends React.Component {
  render( ) {
    const {
      project,
      setDescription,
      setTitle,
      onFileDrop,
      updateProject,
      deleteProject
    } = this.props;
    const bgColor = project.banner_color;
    return (
      <div id="SharedForm" className="Form">
        <Grid>
          <Row>
            <Col xs={12}>
              <h1>
                Project Details
                { project.id && (
                  <button
                    className="btn-white delete"
                    onClick={ deleteProject }
                  >
                    <i className="fa fa-trash" />
                    Delete Project
                  </button>
                ) }
              </h1>
            </Col>
          </Row>
          <Row className="first-row">
            <Col xs={4}>
              <div className={ `form-group ${project.errors.title && "has-error"}` }>
                <label htmlFor="project-title">
                  Project Name *
                </label>
                <input
                  type="text"
                  className="form-control"
                  name="project-title"
                  ref="title"
                  placeholder={ "Birds of Chicago, Amazing Dragonflies, etc." }
                  defaultValue={ project.title }
                  onChange={ e => setTitle( e.target.value ) }
                />
                { project.errors.title && (
                  <Overlay
                    show
                    placement="top"
                    target={ ( ) => this.refs.title }
                  >
                    <Popover
                      id="popover-title"
                      className="popover-error"
                    >
                      { project.errors.title }
                    </Popover>
                  </Overlay>
                ) }
              </div>
              <input
                type="checkbox"
                id="project-display-name"
                defaultChecked={ !project.hide_title }
                onChange={ e => updateProject( { hide_title: !e.target.checked } ) }
              />
              <label className="inline" htmlFor="project-display-name">Display project name</label>
            </Col>
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
                <div className="icon-cell icon">
                  <label>Project Icon (PNG, JPG, or GIF)</label>
                  <div className="help-text">
                    Optional icon. Should be a minimum of 72px x 72px
                    and will be cropped to a square.
                  </div>
                  <div>
                    <button className="btn-white"
                      onClick={ ( ) => this.refs.iconDropzone.open( ) }
                    >
                      <i className="fa fa-upload" />
                      Choose File
                    </button>
                    (Or drag and drop)
                  </div>
                  { project.iconURL( ) && (
                    <div className="icon-previews icon-preview">
                      <div
                        className="icon"
                        style={ { backgroundImage: `url( '${project.iconURL( )}' )` } }
                      />
                      { project.droppedIcon ? project.droppedIcon.name : project.icon_file_name }
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
                <div className="icon-cell banner">
                  <label>Project Banner (PNG, JPG, or GIF)</label>
                  <div className="help-text">
                    Optional banner image. Must be 77px wide, less than 300px tall.
                  </div>
                  <div>
                    <button className="btn-white"
                      onClick={ ( ) => this.refs.bannerDropzone.open( ) }
                    >
                      <i className="fa fa-upload" />
                      Choose File
                    </button>
                    (Or drag and drop)
                  </div>
                  { project.bannerURL( ) && (
                    <div className="icon-previews icon-preview">
                      <div
                        className="banner"
                        style={ { backgroundImage: `url( '${project.bannerURL( )}' )` } }
                      />
                      { project.droppedBanner ?
                          project.droppedBanner.name : project.header_image_file_name }
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
          </Row>
          <Row className="styles-row">
            <Col xs={8}>
              <div className={ `form-group ${project.errors.description && "has-error"}` }>
                <label htmlFor="project-description">Project Summary *</label>
                <div className="help-text">
                  Give a concise explanation of your project. Approximately the first 200 characters
                  will be visible to the right of the project home screen banner so put the best
                  stuff first!
                </div>
                <textarea
                  id="project-description"
                  ref="description"
                  className="form-control"
                  placeholder="Discover and track the birds of Golden Gate Park..."
                  onChange={ e => setDescription( e.target.value ) }
                  value={ project.description }
                />
                { project.errors.description && (
                  <Overlay
                    show
                    placement="top"
                    target={ ( ) => this.refs.description }
                  >
                    <Popover
                      id="popover-description"
                      className="popover-error"
                    >
                      { project.errors.description }
                    </Popover>
                  </Overlay>
                ) }
              </div>
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
          <Row className="project-type">
            <Col xs={ 12 }>
              <h2>Project Type</h2>
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
        </Grid>
      </div>
    );
  }
}

SharedForm.propTypes = {
  project: PropTypes.object,
  onFileDrop: PropTypes.func,
  setDescription: PropTypes.func,
  setTitle: PropTypes.func,
  updateProject: PropTypes.func,
  deleteProject: PropTypes.func
};

export default SharedForm;
