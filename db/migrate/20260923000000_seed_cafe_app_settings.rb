class SeedCafeAppSettings < ActiveRecord::Migration[7.0]
  def up
    AppSetting.find_or_create_by!(key: "cafe_phone") do |s|
      s.value = "+375 (29) 765-43-22"
    end

    AppSetting.find_or_create_by!(key: "cafe_telegram") do |s|
      s.value = "pirosmani_brest"
    end

    AppSetting.find_or_create_by!(key: "cafe_address") do |s|
      s.value = "Брест, Советская 64"
    end

    AppSetting.find_or_create_by!(key: "cafe_lat") do |s|
      s.value = "52.090279"
    end

    AppSetting.find_or_create_by!(key: "cafe_lng") do |s|
      s.value = "23.694566"
    end
  end

  def down
    AppSetting.where(key: %w[cafe_phone cafe_telegram cafe_address cafe_lat cafe_lng]).delete_all
  end
end