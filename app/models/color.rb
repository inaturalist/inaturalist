class Color < ActiveRecord::Base
  has_and_belongs_to_many :taxa

  def as_indexed_json(options={})
    {
      id: id,
      value: value
    }
  end
end
