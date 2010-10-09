class Array
  def to_csv(options = {})
    return '' if self.empty?

    klass      = self.first.class
    attributes = self.first.attributes.keys.sort.map(&:to_sym)

    if options[:only]
      columns = Array(options[:only]) & attributes
    else
      columns = attributes - Array(options[:except])
    end

    columns += Array(options[:methods])

    return '' if columns.empty?

    output = FasterCSV.generate do |csv|
      csv << columns.map { |column| klass.human_attribute_name(column) } unless options[:headers] == false
      self.each do |item|
        csv << columns.collect { |column| item.send(column) }
      end
    end

    output
  end
end
