class AddIndexesToCasinoTables < ActiveRecord::Migration[7.1]
  def change
    add_index :casino_tables, :game_type unless index_exists?(:casino_tables, :game_type)
    add_index :casino_tables, :state unless index_exists?(:casino_tables, :state)
    add_index :casino_tables, [:game_type, :state] unless index_exists?(:casino_tables, [:game_type, :state])
  end
end

