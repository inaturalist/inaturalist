class Array
  def to_csv(options = {}, csv_options = {})
    return '' if self.empty?

    klass      = self.first.class
    attributes = self.first.attributes.keys.sort.map(&:to_sym)

    if options[:only]
      columns = Array(options[:only]).select{|c| self.first.respond_to?(c)}
    else
      columns = attributes - Array(options[:except])
    end

    columns += Array(options[:methods])

    return '' if columns.empty?

    writer = RUBY_VERSION >= "1.9.0" ? CSV : FasterCSV

    output = writer.generate(csv_options) do |csv|
      csv << columns.map { |column| klass.human_attribute_name(column) } unless options[:headers] == false
      self.each do |item|
        csv << columns.collect { |column| item.send(column) }
      end
    end

    output
  end
end
