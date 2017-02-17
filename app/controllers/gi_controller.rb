# frozen_string_literal: true
require 'gi/client'

class GIController < ApplicationController
  skip_before_action :authenticate

  private

  def client
    @client ||= ::GI::Client.new
  end
end
