class AddColorAndEmojiToTags < ActiveRecord::Migration[7.0]
  def change
    add_column :tags, :color, :string, null: true
    add_column :tags, :emoji, :string, null: true
  end
end