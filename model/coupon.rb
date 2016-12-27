# -*- coding: utf-8 -*-

module Plugin::IIJ_COUPON_CHECKER
  class Coupon < Retriever::Model

    field.int     :volume
    field.string  :expire
    field.string  :type


    def inspect
      "#{self.class.to_s}(type = #{type}, volume = #{volume})"
    end

  end
end