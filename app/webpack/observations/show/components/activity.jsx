import _ from "lodash";
import React, { PropTypes } from "react";
import { Button, Tabs, Tab } from "react-bootstrap";
import moment from "moment-timezone";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import UserImage from "../../identify/components/user_image";
import ActivityItem from "./activity_item";

const Activity = ( { observation, config, addComment, deleteComment, addID, deleteID,
                     restoreID, setFlaggingModalState, createFlag, deleteFlag } ) => {
  if ( !observation ) { return ( <div /> ); }
  const activity = _.sortBy(
    observation.identifications.concat( observation.comments ), a => (
      moment.parseZone( a.created_at ) ) );
  const tabs = (
    <Tabs defaultActiveKey="comment">
      <Tab eventKey="comment" title="Comment" className="comment_tab">
        <div className="form-group">
          <textarea
            placeholder="Leave a comment"
            className="form-control"
          />
        </div>
      </Tab>
      <Tab eventKey="add_id" title="Suggest an ID" className="id_tab">
        <TaxonAutocomplete
          bootstrap
          searchExternal
          perPage={ 6 }
          resetOnChange={ false }
        />
        <div className="form-group">
          <textarea
            placeholder="Tell us why..."
            className="form-control"
          />
        </div>
      </Tab>
    </Tabs>
  );
  const loggedIn = config && config.currentUser;
  const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
    i.current && i.user && i.user.id === config.currentUser.id
  ) );
  return (
    <div className="Activity">
      <h3>Activity</h3>
      <div className="activity">
        { activity.map( item => (
          <ActivityItem
            key={ `activity-${item.id}` }
            observation={ observation }
            item={ item }
            currentUserID={ currentUserID }
            config={ config }
            deleteComment={ deleteComment }
            deleteID={ deleteID }
            restoreID={ restoreID }
            setFlaggingModalState={ setFlaggingModalState }
            createFlag={ createFlag }
            deleteFlag={ deleteFlag }
          /> ) ) }
        <div className="icon">
          <UserImage user={ config.currentUser } />
        </div>
        <div className="comment_id_panel">
          { tabs }
        </div>
        <Button bsSize="small" onClick={
          ( ) => {
            if ( $( ".comment_tab" ).is( ":visible" ) ) {
              addComment( $( ".comment_tab textarea" ).val( ) );
              $( ".comment_tab textarea" ).val( "" );
            } else {
              addID( $( ".id_tab input[name='taxon_id']" ).val( ),
                $( ".id_tab textarea" ).val( ) );
              $( ".id_tab input[name='taxon_id']" ).val( "" );
              $( ".id_tab textarea" ).val( "" );
            }
          } }
        >
          Done
        </Button>
      </div>
    </div>
  );
};

Activity.propTypes = {
  observation: PropTypes.object,
  config: PropTypes.object,
  observation_places: PropTypes.object,
  addComment: PropTypes.func,
  deleteComment: PropTypes.func,
  addID: PropTypes.func,
  deleteID: PropTypes.func,
  restoreID: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  createFlag: PropTypes.func,
  deleteFlag: PropTypes.func
};

export default Activity;
