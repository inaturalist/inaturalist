class Color < ApplicationRecord
  has_and_belongs_to_many :taxa

  BLACK   = Color.where(value: 'black').first_or_create
  WHITE   = Color.where(value: 'white').first_or_create
  RED     = Color.where(value: 'red').first_or_create
  PINK    = Color.where(value: 'pink').first_or_create
  GREEN   = Color.where(value: 'green').first_or_create
  BLUE    = Color.where(value: 'blue').first_or_create
  PURPLE  = Color.where(value: 'purple').first_or_create
  YELLOW  = Color.where(value: 'yellow').first_or_create
  GREY    = Color.where(value: 'grey').first_or_create
  ORANGE  = Color.where(value: 'orange').first_or_create
  BROWN   = Color.where(value: 'brown').first_or_create

  def as_indexed_json(options={})
    {
      id: id,
      value: value
    }
  end
end
