class CustomUglifier < Uglifier

  # if the JS source file contains `// skip_uglifier`
  # then do just that, otherwise compress normally
  def compress(string)
    if string =~ /\/\/ skip_uglifier/
      string
    else
      super(string)
    end
  end

end
