# -*- coding: utf-8 -*-
require_relative 'coupon'
require_relative 'hdo_info'

module Plugin::IIJ_COUPON_CHECKER
  class CouponInfo < Retriever::Model

    field.string  :hddServiceCode
    field.has     :hdoInfo, Plugin::IIJ_COUPON_CHECKER::HDOInfo
    field.has     :coupon, Plugin::IIJ_COUPON_CHECKER::Coupon
    field.string  :plan


    def inspect
      "#{self.class.to_s}(id = #{id}, name = #{name})"
    end

  end
end