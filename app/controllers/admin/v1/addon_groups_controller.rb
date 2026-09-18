module Admin
  module V1
    class AddonGroupsController < Admin::BaseController
      before_action :set_addon_group, only: [:show, :update, :destroy]

      def index
        addon_groups = AddonGroup.includes(:addons).order(:name)
        render json: addon_groups.map { |ag| AddonGroupSerializer.new(ag).as_json }
      end

      def show
        render json: AddonGroupSerializer.new(@addon_group).as_json
      end

      def create
        addon_group = AddonGroup.new(addon_group_params)
        if addon_group.save
          render json: AddonGroupSerializer.new(addon_group).as_json, status: :created
        else
          render json: { errors: addon_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @addon_group.update(addon_group_params)
          render json: AddonGroupSerializer.new(@addon_group).as_json
        else
          render json: { errors: @addon_group.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @addon_group.destroy
        head :no_content
      end

      private

      def set_addon_group
        @addon_group = AddonGroup.includes(:addons).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Addon group not found" }, status: :not_found
      end

      def addon_group_params
        params.require(:addon_group).permit(:name, :min_selection, :max_selection, :required)
      end
    end
  end
end