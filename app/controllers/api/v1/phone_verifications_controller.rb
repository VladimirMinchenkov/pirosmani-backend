# app/controllers/api/v1/phone_verifications_controller.rb
module Api
  module V1
    class PhoneVerificationsController < BaseController
      def create
        phone = params[:phone]
        return render json: { error: "phone is required" }, status: :bad_request if phone.blank?

        otp_code = OtpCode.generate_for(phone)

        # TODO: Replace with real SMS provider (e.g. Twilio, Smsc)
        Rails.logger.info "[DEV OTP] Phone #{phone} → code #{otp_code.code}"

        render json: { message: "Verification code sent" }, status: :ok
      end
    end
  end
end
