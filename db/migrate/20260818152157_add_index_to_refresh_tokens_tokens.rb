class AddIndexToRefreshTokensTokens < ActiveRecord::Migration[7.0]
  def change
    add_index :refresh_tokens, :token, unique: true, if_not_exists: true
  end
end
