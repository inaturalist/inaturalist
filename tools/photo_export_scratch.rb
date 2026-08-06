
field_ids = [17991]

ObservationFieldValue.where( observation_field_id: field_ids ).
    includes( :observation, :observation_field )


@observation_field = ObservationField.find( field_ids ); nil
scope = ObservationFieldValue.includes( :observation, :observation_field ).
          where( observation_field_id: of )
ofv_scope = scope.order( "observation_field_values.id DESC" )
ofv_scope = ofv_scope.where( "value = ?", @value ) unless @value == "any"
# @observation_field_values = ofv_scope.page( params[:page] )
@observation_field_values = ofv_scope
@observations = @observation_field_values.map( &:observation )
Observation.preload_associations( @observations,
    [
        :user, :sounds,
        { taxon: :taxon_names },
        { identifications: :moderator_actions },
        { photos: [:flags, :file_prefix, :file_extension, :moderator_actions] }
    ] )

    ObservationPhotoUrlExporter.export( [17991], size: "original" )