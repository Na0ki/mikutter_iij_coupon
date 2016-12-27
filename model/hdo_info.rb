# -*- coding: utf-8 -*-
require_relative 'coupon'

module Plugin::IIJ_COUPON_CHECKER
  class HDOInfo < Retriever::Model

    field.boolean :regulation
    field.boolean :couponUse
    field.string  :iccid
    field.has     :coupon, Plugin::IIJ_COUPON_CHECKER::Coupon
    field.string  :hdoServiceCode
    field.boolean :voice
    field.boolean :sms
    field.string  :number


    def inspect
      "#{self.class.to_s}(id = #{id}, name = #{name})"
    end

  end
end