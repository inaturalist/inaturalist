import React from "react";
import PropTypes from "prop-types";
import {
  Grid, Row, Col, OverlayTrigger, Popover, Overlay
} from "react-bootstrap";
import Dropzone from "react-dropzone";
import { ChromePicker } from "react-color";

$( document ).bind( "drop dragover", e => {
  e.preventDefault( );
} );

class SharedForm extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.titleInput = React.createRef( );
    this.iconDropzone = React.createRef( );
    this.bannerDropzone = React.createRef( );
    this.descriptionInput = React.createRef( );
    this.bgColorInput = React.createRef( );
  }

  render( ) {
    const {
      config,
      project,
      setDescription,
      setTitle,
      onFileDrop,
      updateProject,
      deleteProject,
      duplicateProject
    } = this.props;
    const bgColor = project.banner_color;
    return (
      <div id="SharedForm" className="Form">
        <Grid>
          <Row>
            <Col xs={12}>
              <h1>
                { I18n.t( "views.projects.new.project_details" ) }
                { project.id && config.currentUser.id === project.user.id && (
                  <button
                    type="button"
                    className="btn-white delete"
                    onClick={deleteProject}
                  >
                    <i className="fa fa-trash" />
                    { I18n.t( "views.projects.new.delete_project" ) }
                  </button>
                ) }
                { project.id && (
                  <button
                    type="button"
                    className="btn-white"
                    onClick={duplicateProject}
                  >
                    <i className="fa fa-clone" />
                    { I18n.t( "views.projects.new.duplicate_project" ) }
                  </button>
                ) }
              </h1>
            </Col>
          </Row>
          <Row className="first-row">
            <Col xs={4}>
              <div className={`form-group ${project.errors.title && "has-error"}`}>
                <label htmlFor="project-title">
                  { I18n.t( "views.projects.new.project_name" ) }
                  { " * " }
                </label>
                <input
                  type="text"
                  className="form-control"
                  name="project-title"
                  ref={this.titleInput}
                  placeholder={I18n.t( "views.projects.new.name_placeholder" )}
                  defaultValue={project.title}
                  onChange={e => setTitle( e.target.value )}
                />
                { project.errors.title && (
                  <Overlay
                    show
                    placement="top"
                    target={( ) => this.titleInput.current}
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
                defaultChecked={!project.hide_title}
                onChange={e => updateProject( { hide_title: !e.target.checked } )}
              />
              <label className="inline" htmlFor="project-display-name">
                { I18n.t( "views.projects.new.display_project_name" ) }
              </label>
            </Col>
            <Col xs={4}>
              <Dropzone
                ref={this.iconDropzone}
                className="dropzone"
                onDrop={droppedFiles => onFileDrop( droppedFiles, "droppedIcon" )}
                activeClassName="hover"
                disableClick
                accept="image/png,image/jpeg,image/gif"
                multiple={false}
              >
                <div className="icon-cell icon">
                  <label>{ I18n.t( "views.projects.new.project_icon" ) }</label>
                  <div className="help-text">
                    { I18n.t( "views.projects.new.project_icon_help" ) }
                  </div>
                  <div>
                    <button
                      type="button"
                      className="btn-white"
                      onClick={( ) => this.iconDropzone.current.open( )}
                    >
                      <i className="fa fa-upload" />
                      { I18n.t( "choose_file" ) }
                    </button>
                    { I18n.t( "views.projects.new.or_drag_and_drop" ) }
                  </div>
                  { project.iconURL( ) && (
                    <div className="icon-previews icon-preview">
                      <div
                        className="icon"
                        style={{ backgroundImage: `url( '${project.iconURL( )}' )` }}
                      />
                      { project.droppedIcon ? project.droppedIcon.name : project.icon_file_name }
                      <button
                        type="button"
                        className="btn btn-nostyle"
                        onClick={( ) => updateProject(
                          project.customIcon( )
                            ? { iconDeleted: true, droppedIcon: null }
                            : { droppedIcon: null }
                        )}
                      >
                        <i className="fa fa-times-circle" />
                      </button>
                    </div>
                  ) }
                </div>
              </Dropzone>
            </Col>
            <Col xs={4}>
              <Dropzone
                ref={this.bannerDropzone}
                className="dropzone"
                onDrop={droppedFiles => onFileDrop( droppedFiles, "droppedBanner" )}
                activeClassName="hover"
                disableClick
                accept="image/*"
                multiple={false}
              >
                <div className="icon-cell banner">
                  <label>{ I18n.t( "views.projects.new.project_banner" ) }</label>
                  <div className="help-text">
                    { I18n.t( "views.projects.new.project_banner_help" ) }
                  </div>
                  <div>
                    <button
                      type="button"
                      className="btn-white"
                      onClick={( ) => this.bannerDropzone.current.open( )}
                    >
                      <i className="fa fa-upload" />
                      { I18n.t( "choose_file" ) }
                    </button>
                    { I18n.t( "views.projects.new.or_drag_and_drop" ) }
                  </div>
                  { project.bannerURL( ) && (
                    <div>
                      <div className="icon-previews icon-preview">
                        <div
                          className="banner"
                          style={{
                            backgroundImage: `url( '${project.bannerURL( )}' )`,
                            backgroundSize: project.header_image_contain ? "contain" : "cover"
                          }}
                        />
                        {
                          project.droppedBanner
                            ? project.droppedBanner.name
                            : project.header_image_file_name
                        }
                        <button
                          type="button"
                          className="btn btn-nostyle"
                          onClick={( ) => updateProject(
                            project.customBanner( )
                              ? { bannerDeleted: true, droppedBanner: null }
                              : { droppedBanner: null }
                          )}
                        >
                          <i className="fa fa-times-circle" />
                        </button>
                      </div>
                      <input
                        type="checkbox"
                        id="project-header-contain"
                        defaultChecked={project.header_image_contain}
                        onChange={e => updateProject( { header_image_contain: e.target.checked } )}
                      />
                      <label className="inline" htmlFor="project-header-contain">
                        { I18n.t( "views.projects.new.contain_entire_image_without_cropping" ) }
                      </label>
                    </div>
                  ) }
                </div>
              </Dropzone>
            </Col>
          </Row>
          <Row className="styles-row">
            <Col xs={8}>
              <div className={`form-group ${project.errors.description && "has-error"}`}>
                <label htmlFor="project-description">
                  { I18n.t( "views.projects.new.project_summary" ) }
                  { " *" }
                </label>
                <div className="help-text">
                  { I18n.t( "views.projects.new.project_summary_help" ) }
                </div>
                <textarea
                  id="project-description"
                  ref={this.descriptionInput}
                  className="form-control"
                  placeholder={I18n.t( "views.projects.new.project_summary_placeholder" )}
                  onChange={e => setDescription( e.target.value )}
                  value={project.description || ""}
                />
                { project.errors.description && (
                  <Overlay
                    show
                    placement="top"
                    target={( ) => this.descriptionInput.current}
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
              <label htmlFor="project-bgcolor">
                { I18n.t( "views.projects.new.project_background_color" ) }
              </label>
              <div className="help-text">
                { I18n.t( "views.projects.new.project_background_color_help" ) }
              </div>
              <div className="input-group">
                <OverlayTrigger
                  trigger="click"
                  rootClose
                  placement="top"
                  animation={false}
                  container={this}
                  overlay={(
                    <Popover id="color-picker-popover" className="color-picker">
                      <ChromePicker
                        disableAlpha
                        color={bgColor}
                        onChange={color => {
                          updateProject( { banner_color: color.hex } );
                          $( this.bgColorInput.current ).val( color.hex );
                        }}
                      />
                    </Popover>
                  )}
                >
                  <div className="input-group-addon color">
                    <div className="color-preview" style={{ background: bgColor }} />
                  </div>
                </OverlayTrigger>
                <input
                  type="text"
                  ref={this.bgColorInput}
                  className="form-control"
                  defaultValue={bgColor}
                  onChange={e => updateProject( { banner_color: e.target.value } )}
                />
              </div>
            </Col>
          </Row>
          <Row className="separator-row">
            <Col xs={12}>
              <div className="separator" />
            </Col>
          </Row>
          { !project.id && (
            <Row className="project-type">
              <Col xs={12}>
                <h2>{ I18n.t( "views.projects.project_type" ) }</h2>
                <label className="inline checkboxradio" htmlFor="project-type-regular">
                  <input
                    type="radio"
                    id="project-type-regular"
                    value="regular"
                    checked={project.project_type !== "umbrella"}
                    onChange={( ) => updateProject( { project_type: "regular" } )}
                  />
                  { I18n.t( "views.projects.collection" ) }
                </label>
                <label className="inline checkboxradio" htmlFor="project-type-umbrella">
                  <input
                    type="radio"
                    id="project-type-umbrella"
                    value="regular"
                    checked={project.project_type === "umbrella"}
                    onChange={( ) => updateProject( { project_type: "umbrella" } )}
                  />
                  { I18n.t( "views.projects.umbrella" ) }
                  { ` (${I18n.t( "views.projects.tracks_multiple_projects" )})` }
                </label>
              </Col>
            </Row>
          ) }
        </Grid>
      </div>
    );
  }
}

SharedForm.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  onFileDrop: PropTypes.func,
  setDescription: PropTypes.func,
  setTitle: PropTypes.func,
  updateProject: PropTypes.func,
  deleteProject: PropTypes.func,
  duplicateProject: PropTypes.func
};

export default SharedForm;
