module Api
  module V1    class CombosController < BaseController
      def index
        combos = Combo.active.includes(:combo_items)
        render json: combos.map { |c| ComboSerializer.new(c).as_json }
      end
    end
  end
end