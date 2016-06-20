import _ from "lodash";
import piexif from "piexifjs";
import moment from "moment-timezone";
import util from "../models/util";

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

  // returns a Promise
  readExif( obsCard ) {
    const reader = new FileReader();
    const metadata = { };
    return new Promise( ( resolve ) => {
      reader.onloadend = e => {
        const exif = { };
        // read EXIF into an object
        let exifObj;
        try {
          exifObj = piexif.load( e.target.result );
        } catch ( err ) {
          return resolve( metadata );
        }
        _.each( exifObj, ( tags, ifd ) => {
          if ( ifd === "thumbnail" ) { return; }
          _.each( tags, ( value, tag ) => {
            exif[piexif.TAGS[ifd][tag].name] = value;
          } );
        } );
        // check that object for metadata we care about
        if ( exif.ImageDescription && !obsCard.description ) {
          metadata.description = exif.ImageDescription;
        }
        if ( !obsCard.latitude ) {
          if ( exif.GPSLatitude && exif.GPSLatitude.length === 3 ) {
            metadata.latitude = util.gpsCoordConvert( exif.GPSLatitude );
            if ( _.lowerCase( exif.GPSLatitudeRef ) === "s" ) {
              metadata.latitude *= -1;
            }
          }
          if ( exif.GPSLongitude && exif.GPSLongitude.length === 3 ) {
            metadata.longitude = util.gpsCoordConvert( exif.GPSLongitude );
            if ( _.lowerCase( exif.GPSLongitudeRef ) === "w" ) {
              metadata.longitude *= -1;
            }
          }
        }
        if ( !obsCard.date ) {
          if ( exif.DateTimeOriginal || exif.DateTimeDigitized ) {
            // reformat YYYY:MM:DD into YYYY/MM/DD for moment
            const dt = ( exif.DateTimeOriginal || exif.DateTimeDigitized ).
              replace( /(\d{4}):(\d{2}):(\d{2})/, "$1/$2/$3" );
            /* global TIMEZONE */
            // assume the date is in the timezone of their user account
            metadata.date = moment.tz( dt, "YYYY/MM/DD HH:mm:ss", TIMEZONE ).
              format( "YYYY/MM/DD h:mm A z" );
            metadata.selected_date = metadata.date;
          }
        }
        // reverse geocode lat/lngs to get place name
        if ( metadata.latitude && metadata.longitude ) {
          util.reverseGeocode( metadata.latitude, metadata.longitude ).then( location => {
            if ( location ) { metadata.locality_notes = location; }
            resolve( metadata );
          } );
        } else {
          resolve( metadata );
        }
      };
      reader.readAsDataURL( this.file );
    } );
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
