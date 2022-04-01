import React from "react";
import PropTypes from "prop-types";

const CheckboxRow = ( {
  confirm,
  confirmChangeTo,
  description,
  disabled,
  handleCheckboxChange,
  label,
  modalDescription,
  modalDescriptionTitle,
  name,
  profile,
  showModalDescription
} ) => (
  <div className="row">
    <div className="col-xs-12">
      <div className="checkbox">
        <label>
          <input
            id={`user_${name}`}
            type="checkbox"
            // false when profile[name] is undefined
            checked={profile[name] || false}
            name={name}
            disabled={disabled}
            onChange={e => {
              if ( confirm ) {
                confirmChangeTo( name, confirm, e );
                return false;
              }
              handleCheckboxChange( e );
              return true;
            }}
          />
          { label }
        </label>
        { modalDescription && (
          <div className="checkbox-description-margin">
            <button
              type="button"
              className="btn btn-link btn-nostyle"
              onClick={( ) => showModalDescription(
                modalDescription,
                { title: modalDescriptionTitle }
              )}
            >
              <i className="fa fa-info-circle" />
              { " " }
              { I18n.t( "learn_more" ) }
            </button>
          </div>
        ) }
        { description && typeof ( description ) === "string" && (
          <div className="checkbox-description-margin">
            <p
              className="text-muted"
              // eslint-disable-next-line react/no-danger
              dangerouslySetInnerHTML={{ __html: description }}
            />
          </div>
        ) }
        { description && typeof ( description ) === "object" && (
          <div className="checkbox-description-margin">
            { description }
          </div>
        ) }
      </div>
    </div>
  </div>
);

CheckboxRow.propTypes = {
  profile: PropTypes.object,
  name: PropTypes.string,
  handleCheckboxChange: PropTypes.func,
  label: PropTypes.string,
  description: PropTypes.any,
  disabled: PropTypes.bool,
  confirm: PropTypes.string,
  confirmChangeTo: PropTypes.func,
  modalDescription: PropTypes.string,
  modalDescriptionTitle: PropTypes.string,
  showModalDescription: PropTypes.func
};

export default CheckboxRow;
