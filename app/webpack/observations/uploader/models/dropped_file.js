import _ from "lodash";
import piexif from "piexifjs";
import moment from "moment-timezone";
import util, { parsableDatetimeFormat } from "./util";

const BRANDED_DESCRIPTIONS = [
  "OLYMPUS DIGITAL CAMERA",
  "SONY DSC",
  "MOULTRIE DIGITAL GAME CAMERA",
  "<KENOX S1050 / Samsung S1050>",
  "KODAK Digital Still Camera",
  "DIGITAL CAMERA",
  "SAMSUNG CAMERA PICTURES",
  "MINOLTA DIGITAL CAMERA"
];

const DroppedFile = class DroppedFile {
  constructor( attrs ) {
    Object.assign( this, attrs );
  }

  additionalPhotoMetadata( p ) {
    const photo = p || this.photo;
    if ( !photo || !photo.to_observation ) { return { }; }
    const updates = { };
    const obs = photo.to_observation;
    if ( obs.time_observed_at ) {
      // to_observation should come back with a time zone set based on
      // coordinates, and we need to use that here to tell moment that we
      // want to use that timezone when formatting an output date, otherwise
      // moment will parse the date with the offset in time_observed at
      // correctly, but then *output* a datetime in the local time zone when
      // we call format()
      updates.date = moment
        .tz( obs.time_observed_at, obs.zic_time_zone )
        .format( parsableDatetimeFormat( ) );
      updates.selected_date = updates.date;
    }
    if ( obs.latitude && obs.longitude ) {
      updates.latitude = parseFloat( obs.latitude );
      updates.longitude = parseFloat( obs.longitude );
    }
    updates.locality_notes = obs.place_guess;
    updates.taxon_id = obs.taxon_id;
    updates.observation_field_values = obs.observation_field_values;
    updates.tags = obs.tag_list;
    updates.description = obs.description;
    return updates;
  }

  // returns a Promise
  readExif( ) {
    const reader = new FileReader();
    const metadata = { };
    return new Promise( resolve => {
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
        if ( exif.ImageDescription ) {
          const desc = _.trim( exif.ImageDescription.replace( /\u0000/g, "" ) );
          if ( BRANDED_DESCRIPTIONS.indexOf( desc ) < 0 ) {
            metadata.description = desc;
          }
        }
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
        if ( exif.GPSHPositioningError && exif.GPSHPositioningError.length === 2 ) {
          metadata.accuracy = exif.GPSHPositioningError[0] / exif.GPSHPositioningError[1];
        }
        if ( exif.DateTimeOriginal || exif.DateTimeDigitized ) {
          // reformat YYYY:MM:DD into YYYY/MM/DD for moment
          const dt = ( exif.DateTimeOriginal || exif.DateTimeDigitized )
            .replace( /(\d{4}):(\d{2}):(\d{2})/, "$1/$2/$3" );
          const momentDate = moment( dt );
          if ( momentDate.isValid( ) ) {
            metadata.date = momentDate.format( parsableDatetimeFormat( ) );
            metadata.selected_date = metadata.date;
          }
        }
        if ( Math.abs( metadata.latitude ) > 90 || Math.abs( metadata.longitude ) > 180 ) {
          metadata.latitude = null;
          metadata.longitude = null;
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

  static fromFile( file, attrs = { } ) {
    return new DroppedFile( Object.assign( {
      name: file.name,
      lastModified: file.lastModified,
      lastModifiedDate: file.lastModifiedDate,
      size: file.size,
      type: file.type,
      preview: file.preview,
      uploadState: "pending",
      file
    }, attrs ) );
  }
};

export default DroppedFile;
