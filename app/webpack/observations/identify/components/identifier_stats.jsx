import React, { PropTypes } from "react";
import UserImage from "./user_image";

const IdentifierStats = ( {
  loading,
  users
} ) => {
  let content;
  if ( loading ) {
    content = (
      <div className="text-center text-muted">
        <i className="fa fa-refresh fa-spin"></i> { I18n.t( "loading" ) }
      </div>
    );
  } else if ( users.length === 0 ) {
    content = <div className="text-center text-muted">{ I18n.t( "no_matching_users" ) }</div>;
  } else {
    content = (
      <table className="table">
        <thead>
          <tr>
            <th>{ I18n.t( "rank" ) }</th>
            <th colSpan={2} className="identifications">{ I18n.t( "identifications" ) }</th>
          </tr>
        </thead>
        <tbody>
          {users.map( ( item, i ) => (
            <tr
              key={`identifier-${item.user.id}`}
            >
              <td className="position">{ i + 1 }</td>
              <td className="user">
                <UserImage user={ item.user } />
                <a href={ `/people/${item.user.login}` }>{ item.user.login }</a>
              </td>
              <td className="identifications">
                { I18n.toNumber( item.count, { precision: 0 } ) }
              </td>
            </tr>
          ) ) }
        </tbody>
      </table>
    );
  }
  return (
    <div className="IdentifierStats">
      <h4>Top Identifiers</h4>
      { content }
    </div>
  );
};

IdentifierStats.propTypes = {
  loading: PropTypes.bool,
  users: PropTypes.array
};

export default IdentifierStats;
