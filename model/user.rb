# -*- coding: utf-8 -*-

module Plugin::IIJ_COUPON_CHECKER
  class User < Retriever::Model

    field.string  :id
    field.string  :name

    def idname
      name
    end

    # def profile_image_url
    #
    # end

    def inspect
      "#{self.class.to_s}(id = #{id}, name = #{name})"
    end

  end
end