ActiveRecord::Schema.define(:version => 0) do
  
  create_table :games, :force => true do |t|
    t.string :name
  end
  
  create_table :moves, :force => true do |t|
    t.integer :game_id
  end
  
  create_table :rules, :force => true do |t|
    t.string :ruler_type
    t.integer :ruler_id
    t.string :operand_type
    t.integer :operand_id
    t.string :operator
  end
  
  create_table :countries, :force => true do |t|
    t.string :name
  end
end
