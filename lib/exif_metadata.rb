# frozen_string_literal: true

# Extracts exif tags from files and returns a hash with metadata formated for iNaturalist serialization
class ExifMetadata
  REJECTED_TAGS = %i[
    accessory_serial_number
    back_serial
    body_serial_number
    camera_serial_number
    capture_serial
    device_serial_number
    drive_serial_number
    extender_serial_number
    filter_serial_number
    flash_serial_number
    input_device_serial_number
    internal_lens_serial_number
    internal_serial_number
    lens_serial_number
    other_serial_number
    platform_serial_number
    rec_device_serial_number
    scanner_serial_number
    sensor_serial_number
    serial_number
    serial_number_format
    serial_number_hash
    source_serial_number
    storage_serial_number
  ].freeze

  EXIFTOOL_XMP_TAGS = %i[
    description
    subject
    title
  ].freeze

  XMP_SEGMENT_HEADER = "http://ns.adobe.com/xap/1.0/"
  XMP_NAMESPACES = {
    "dc" => "http://purl.org/dc/elements/1.1/",
    "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  }.freeze

  attr_accessor :path, :type
  attr_reader :metadata

  class ExtractionError < StandardError; end

  # Initializes a new ExifMetada instance
  # @param [String] path Path to file to extract exif tags from
  # @param [String] type Filetype (mime) with which to treat the file
  def initialize( path: nil, type: nil )
    @path = path
    @type = type
    @metadata = {}
  end

  # Extracts metadata from file and returns key/value pairs
  # @return [Hash] metadata Hash of metadata extracted, can be empty
  def extract
    case type
    when /jpe?g/i
      extract_jpg
    when /png/i
      extract_png
    when /hei[cf]/i
      extract_other
    end
    metadata.except( *REJECTED_TAGS )
  rescue Errno::ENOENT, Exiftool::ExiftoolNotInstalled, Exiftool::NoSuchFile, Exiftool::NotAFile => e
    raise ExtractionError, "#{e.class.name}: #{e.message}"
  end

  private

  attr_writer :metadata

  def extract_jpg
    exif = EXIFR::JPEG.new( path )
    return unless exif

    metadata.merge!( exif.to_hash )
    extract_xmp( exif )
  end

  def extract_png
    exif = Exiftool.new( path )
    return unless exif

    self.metadata = exif.to_hash

    map_png_dates
    map_png_chunks
    metadata.slice!( *EXIFR::TIFF::TAGS ) # Only tags in existing implementation
  end

  def extract_other
    exif = Exiftool.new( path )
    return unless exif

    self.metadata = exif.to_hash.slice( *EXIFR::TIFF::TAGS )
    return unless exif.to_hash.keys.detect {| k | EXIFTOOL_XMP_TAGS.include?( k ) }

    # If you use exiftool to add XMP:Subject to a photo, it gets read as
    # `subject`, so we're putting that and similar attributes in the dc block
    # similar to extract_xmp
    metadata[:dc] ||= {}
    EXIFTOOL_XMP_TAGS.each do | dc_attr |
      if dc_attr == :subject
        metadata[:dc][dc_attr] ||= []
        metadata[:dc][dc_attr] += [exif[dc_attr]].flatten
      else
        metadata[:dc][dc_attr] = exif[dc_attr]
      end
    end
  end

  def extract_xmp( jpeg )
    xmp = xmp_document( jpeg )
    return unless xmp

    dublin_core = dublin_core_fields( xmp )
    metadata[:dc] = dublin_core if dublin_core.present?
  end

  def xmp_document( jpeg )
    segment = jpeg.app1s.find {| app1 | app1.start_with?( XMP_SEGMENT_HEADER ) }
    return unless segment

    _header, xml = segment.split( "\0", 2 )
    Nokogiri::XML( xml )
  end

  def dublin_core_fields( xmp )
    elements_and_attributes = xmp.xpath( "//dc:* | //@dc:*", XMP_NAMESPACES )
    fields = elements_and_attributes.map {| node | [node.name.to_sym, dublin_core_value( node )] }
    fields.to_h.compact_blank
  end

  def dublin_core_value( node )
    list_items = node.xpath( "rdf:Bag/rdf:li | rdf:Seq/rdf:li | rdf:Alt/rdf:li", XMP_NAMESPACES )
    return node.text.strip if list_items.empty?

    list_items.map( &:text )
  end

  PNG_CHUNK_MAP = {
    description: :image_description,
    comment: :user_comment,
    copyright: :copyright,
    software: :software
  }.freeze

  # Map some common PNG text chunk metadata that may not be present in exif
  def map_png_chunks
    PNG_CHUNK_MAP.each {| k, v | metadata[v] ||= metadata[k] if metadata[k] }
  end

  def map_png_dates
    # ExifTool refers to 0x0132 as 'ModifyDate' https://exiftool.org/TagNames/EXIF.html
    # whereas EXIFR maps 0x0132 to "date_time"
    # Note this differs from "0x9003 DateTimeOriginal"
    metadata[:date_time] = serialize_date_time( metadata[:modify_date] )

    %i[date_time_digitized date_time_original modify_date].each do | k |
      next unless metadata[k]

      metadata[k] = serialize_date_time( metadata[k] )
    end
  end

  def serialize_date_time( datetime )
    # Parsed using EXIFR::TIFF's time proc by R.W. van 't Veer for consistency with existing serialization
    if datetime =~ /^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)(?:\.(\d{3}))?$/
      EXIFR::TIFF.mktime_proc.call( Regexp.last_match( 1 ).to_i, Regexp.last_match( 2 ).to_i,
        Regexp.last_match( 3 ).to_i, Regexp.last_match( 4 ).to_i, Regexp.last_match( 5 ).to_i,
        Regexp.last_match( 6 ).to_i, Regexp.last_match( 7 ).to_i * 1000 )
    end
  rescue StandardError
    datetime
  end
end
