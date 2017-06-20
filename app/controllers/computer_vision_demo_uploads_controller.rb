class ComputerVisionDemoUploadsController < ApplicationController

  before_filter :lookup_upload, only: [ :score ]

  def create
    @upload = ComputerVisionDemoUpload.new(photo: params[:file],
      mobile: is_mobile_app?, user_agent: request.user_agent)
    if @upload.save
      @upload.reload
      json = @upload.as_json( include: :to_observation )
      render json: json
    else
      render json: @upload.errors, status: :unprocessable_entity
    end
  end

  def score
    begin
      response = RestClient.post( CONFIG.node_api_url + "/computervision/score_image",
        params.merge( image: File.new( @upload.photo.path( :thumbnail ) ) ),
        authorization: JsonWebToken.applicationToken)
    rescue
    end
    if response && response.code == 200
      render json: JSON.parse( response )
    else
      render json: @upload.errors, status: :unprocessable_entity
    end
  end

  def lookup_upload
    @upload = ComputerVisionDemoUpload.where( uuid: params[:id] ).first
    render_404 unless @upload
  end

end
