# -*- coding: utf-8 -*-

module Plugin::IIJ_COUPON_CHECKER
  class Coupon < Retriever::Model

    field.int     :volume
    field.string  :expire
    field.string  :type

  end
end