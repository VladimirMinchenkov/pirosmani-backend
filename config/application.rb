require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PirosmaniBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # КРИТИЧНО: часы работы кафе (cafe_working_hours) и все настройки тайминга
    # (WorkingHoursService, DeliveryTimingService) заданы как локальное время
    # Минска ("11:00"–"22:00"). Без этой настройки Rails по умолчанию считает
    # Time.current в UTC (отстаёт от Минска на 3 часа), из-за чего кафе
    # "продолжает работать" ещё 3 часа после реального закрытия и ASAP-заказы
    # принимаются, когда кафе физически уже закрыто.
    config.time_zone = "Europe/Minsk"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.active_storage.routes_prefix = '/rails/active_storage'

    # GoodJob — персистентный (Postgres) ActiveJob adapter. Нужен для отложенных
    # задач с горизонтом в часы (напоминание кухне начать готовить, вызов курьера
    # для предзаказов) — переживает деплои/рестарты, в отличие от :async
    config.active_job.queue_adapter = :good_job
  end
end
