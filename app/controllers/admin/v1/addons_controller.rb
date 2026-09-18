module Admin
  module V1
    class AddonsController < Admin::BaseController
      before_action :set_addon_group
      before_action :set_addon, only: [:update, :destroy]

      def create
        addon = @addon_group.addons.new(addon_params)
        if addon.save
          render json: AddonSerializer.new(addon).as_json, status: :created
        else
          render json: { errors: addon.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @addon.update(addon_params)
          render json: AddonSerializer.new(@addon).as_json
        else
          render json: { errors: @addon.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @addon.destroy
        head :no_content
      end

      private

      def set_addon_group
        @addon_group = AddonGroup.find(params[:addon_group_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Addon group not found" }, status: :not_found
      end

      def set_addon
        @addon = @addon_group.addons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Addon not found" }, status: :not_found
      end

      def addon_params
        params.require(:addon).permit(:name, :price, :position)
      end
    end
  end
end