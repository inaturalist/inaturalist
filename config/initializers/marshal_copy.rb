# Make a truely new copy of an Array or Hash using Marshal

class Hash
  def marshal_copy
    Marshal.load(Marshal.dump(self))
  end
end

class Array
  def marshal_copy
    Marshal.load(Marshal.dump(self))
  end
end