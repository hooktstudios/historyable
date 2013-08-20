class CreateChanges < ActiveRecord::Migration
  def up
    create_table :changes do |t|
      t.references :item, polymorphic: true
      t.string     :object_attribute
      t.text       :object_attribute_value
      t.datetime   :created_at
    end

    add_index :changes, [:item_type, :item_id]
  end

  def down
    drop_table :changes
  end
end
