#encoding: utf-8
class GuidePdfFlowTask < FlowTask
  LAYOUTS = %w(grid book journal)
  LAYOUTS.each do |l|
    const_set l.upcase, l
  end

  def run
    outputs.each(&:destroy)
    guide_input = inputs.detect{|input| input.resource.is_a?(Guide)}
    @guide = guide_input.resource
    raise "Guide does not exist" if @guide.blank?

    @guide_taxa = @guide.guide_taxa.order("guide_taxa.position").
      includes({:taxon => [:taxon_ranges_without_geom]}, :guide_photos, :guide_sections)
    layout = options[:layout] if LAYOUTS.include?(options[:layout])
    layout = GRID if layout.blank?
    if redirect_url.blank?
      update_attribute(:redirect_url, FakeView.guide_pdf_url(@guide, :layout => layout))
    end
    template = "guides/show_#{layout}.pdf.haml"
    fv = FakeView.new
    fv.instance_variable_set :@guide, @guide
    fv.instance_variable_set :@guide_taxa, @guide_taxa
    pdf = WickedPdf.new.pdf_from_string(fv.render(:file => template, :layout => "layouts/bootstrap.pdf"),
      # :pdf => "#{@guide.title.parameterize}.#{layout}", 
      :orientation => layout == JOURNAL ? 'Landscape' : nil,
      :margin => {
        :left => 0,
        :right => 0
      }
    )

    path = File.join(Dir::tmpdir, "#{@guide.id}.#{layout}.pdf")
    Rails.logger.debug "[DEBUG] path: #{path}"
    File.open(path, 'wb') do |f|
      f << pdf
    end
    output = self.outputs.build
    f = File.open(path)
    output.file = f
    output.save!
    f.close
  end

  def pdf_url
    outputs.first.file.url unless outputs.blank?
  end
end