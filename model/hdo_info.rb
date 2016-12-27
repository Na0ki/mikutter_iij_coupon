# -*- coding: utf-8 -*-
require_relative 'coupon'

module Plugin::IIJ_COUPON_CHECKER
  class HDOInfo < Retriever::Model

    field.bool    :regulation
    field.bool    :couponUse
    field.string  :iccid
    field.has     :coupon, Plugin::IIJ_COUPON_CHECKER::Coupon
    field.string  :hdoServiceCode
    field.bool    :voice
    field.bool    :sms
    field.string  :number

  end
end