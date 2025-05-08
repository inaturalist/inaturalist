// Shows children up to a limited height with a toggle to show more

import React from "react";
import PropTypes from "prop-types";

const PartialDetails = ( { children } ) => {
  const [moreShown, setMoreShown] = React.useState( false );
  return (
    <div className={`PartialDetails ${moreShown ? "more" : "less"}`}>
      <div className="preview">
        { children }
      </div>
      <button
        type="button"
        onClick={() => setMoreShown( !moreShown )}
        className="btn btn-nostyle btn-sm toggle"
      >
        { moreShown ? I18n.t( "show_less" ) : I18n.t( "show_more" )}
        <i className={`fa fa-chevron-${moreShown ? "up" : "down"}`} />
      </button>
    </div>
  );
};

PartialDetails.propTypes = {
  children: PropTypes.any
};

export default PartialDetails;
