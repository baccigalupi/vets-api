# frozen_string_literal: true
FactoryGirl.define do
  factory :preneeds_attachment_type do
    sequence(:attachment_type_id) { |n| n }
    sequence(:description) { |n| "#{n} description" }
  end
end
