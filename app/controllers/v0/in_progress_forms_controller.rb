# frozen_string_literal: true
module V0
  class InProgressFormsController < ApplicationController
    def index
      render json: InProgressForm.where(user_uuid: @current_user.uuid)
    end

    def show
      form_id = params[:id]
      form = InProgressForm.form_for_user(form_id, @current_user)
      if form
        render json: form.data_and_metadata
      elsif FeatureFlipper.enable_prefill?(@current_user)
        render json: FormProfile.for(form_id).prefill(@current_user)
      else
        head 404
      end
    end

    def update
      form = InProgressForm.where(form_id: params[:id], user_uuid: @current_user.uuid).first_or_initialize
      result = form.update(form_data: params[:form_data], metadata: params[:metadata])
      raise Common::Exceptions::InternalServerError unless result
      render json: form
    end

    def destroy
      form = InProgressForm.form_for_user(params[:id], @current_user)
      form.destroy
      render json: form
    end
  end
end
