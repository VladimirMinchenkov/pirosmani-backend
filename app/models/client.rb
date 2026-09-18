class Client < ApplicationRecord
  has_many :client_addresses, dependent: :destroy
  has_many :orders, dependent: :nullify
  has_many :refresh_tokens, dependent: :destroy
end
