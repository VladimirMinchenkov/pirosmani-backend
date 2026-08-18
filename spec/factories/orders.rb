FactoryBot.define do
  factory :order do
    status { "MyString" }
    address { "MyString" }
    phone { "MyString" }
    total_price { "9.99" }
    delivery_price { "9.99" }
  end
end
