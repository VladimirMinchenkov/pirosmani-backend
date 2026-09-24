class SeedCafeAppSettings < ActiveRecord::Migration[7.0]
  def up
    # Телефон кафе
    AppSetting.find_or_create_by!(key: "cafe_phone") do |s|
      s.value = "+375 (162) 42-50-00"
    end

    # Telegram
    AppSetting.find_or_create_by!(key: "cafe_telegram") do |s|
      s.value = "pirosmani_brest"
    end

    # Адрес — при сохранении after_save автоматически заполнит cafe_lat/cafe_lng через Geoapify
    AppSetting.find_or_create_by!(key: "cafe_address") do |s|
      s.value = "ул. Советская, 64, Брест"
    end
  end

  def down
    AppSetting.where(key: %w[cafe_phone cafe_telegram cafe_address cafe_lat cafe_lng]).delete_all
  end
end