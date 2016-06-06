import moment from "moment-timezone";

const DroppedFile = class DroppedFile {
  constructor( attrs ) {
    Object.assign( this, attrs );
  }

  additionalPhotoMetadata( reference = { } ) {
    if ( !this.photo || !this.photo.to_observation ) { return { }; }
    const updates = { };
    const ref = Object.assign( { }, reference );
    const obs = this.photo.to_observation;
    if ( !ref.date && obs.time_observed_at ) {
      updates.time_zone = obs.zic_time_zone;
      updates.date = moment( obs.time_observed_at ).
        tz( ref.time_zone ).
        format( "YYYY/MM/DD h:mm A z" );
      updates.selected_date = ref.date;
    }
    if ( !ref.latitude && obs.latitude && obs.longitude ) {
      updates.latitude = parseFloat( obs.latitude );
      updates.longitude = parseFloat( obs.longitude );
    }
    if ( !ref.locality_notes && obs.place_guess ) {
      updates.locality_notes = obs.place_guess;
    }
    if ( !ref.taxon_id && obs.taxon_id ) {
      updates.taxon_id = obs.taxon_id;
    }
    if ( ref.observation_field_values.length === 0 && obs.observation_field_values ) {
      updates.observation_field_values = obs.observation_field_values;
    }
    if ( ref.tags.length === 0 && obs.tag_list ) {
      updates.tags = obs.tag_list;
    }
    if ( !ref.description && obs.description ) {
      updates.description = obs.description;
    }
    return updates;
  }

  static fromFile( file, id ) {
    return new DroppedFile( {
      id,
      name: file.name,
      lastModified: file.lastModified,
      lastModifiedDate: file.lastModifiedDate,
      size: file.size,
      type: file.type,
      preview: file.preview,
      upload_state: "pending",
      file
    } );
  }
};

export default DroppedFile;
