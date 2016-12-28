# -*- coding: utf-8 -*-

require_relative 'coupon'
require_relative 'hdo_info'

module Plugin::IIJ_COUPON_CHECKER
  class CouponInfo < Retriever::Model
    attr_reader :hddServiceCode, :hdo_info, :coupon, :plan

    @client_id = UserConfig['iij_developer_id']
    @coupon_url = 'https://api.iijmio.jp/mobile/d/v1/coupon/'

    # モデル
    field.string :hddServiceCode
    field.has :hdoInfo, Plugin::IIJ_COUPON_CHECKER::HDOInfo
    field.has :coupon, [Plugin::IIJ_COUPON_CHECKER::Coupon]
    field.string :plan


    # 認証
    # @return [Delayer::Deferred::Deferredable] 認証結果を引数にcallbackするDeferred
    def auth
      Delayer::Deferred.fail('Developer ID not defined') unless UserConfig['iij_developer_id']
      uri = 'https://api.iijmio.jp/mobile/d/v1/authorization/' +
          "?response_type=token&client_id=#{UserConfig['iij_developer_id']}" +
          '&state=mikutter_iij_coupon_checker' +
          "&redirect_uri=#{UserConfig['iij_redirect_uri'] || 'localhost'}"

      Thread.new {
        Plugin.call(:open, uri)
        # FIXME: 認証部分を扱いやすいように改良する（webrickでサーバを建てる）
      }.next { |response|
        # Delayer::Deferred.fail(response) unless (response.nil? or response&.status_code == 200)
        p response
      }
    end


    # クーポン情報の取得
    # @return [Delayer::Deferred::Deferredable] クーポンのモデルを引数にcallbackするDeferred
    def self.get_info
      Thread.new {
        client = HTTPClient.new
        client.default_header = {'Content-Type': 'application/json',
                                 'X-IIJmio-Developer': @client_id,
                                 'X-IIJmio-Authorization': token}
        client.get_content(@coupon_url)
      }.next { |response|
        data = JSON.parse(response)
        info = []
        data['couponInfo'].each { |d|
          # SIM内クーポン
          sim_coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: d.dig('hdoInfo', 0, 'coupon', 0, 'volume'),
                                                              expire: d.dig('hdoInfo', 0, 'coupon', 0, 'expire'),
                                                              type: d.dig('hdoInfo', 0, 'coupon', 0, 'type'))
          @hdo_info = Plugin::IIJ_COUPON_CHECKER::HDOInfo.new(regulation: d.dig('hdoInfo', 0, 'regulation'),
                                                              couponUse: d.dig('hdoInfo', 0, 'couponUse'),
                                                              iccid: d.dig('hdoInfo', 0, 'iccid'),
                                                              coupon: sim_coupon,
                                                              hdoServiceCode: d.dig('hdoInfo', 0, 'hdoServiceCode'),
                                                              voice: d.dig('hdoInfo', 0, 'voice'),
                                                              sms: d.dig('hdoInfo', 0, 'sms'),
                                                              number: d.dig('hdoInfo', 0, 'number'))

          coupons = []
          d.dig('coupon').each { |c|
            coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: c.dig('volume'),
                                                            expire: c.dig('expire'),
                                                            type: c.dig('typo'))
            coupons.push(coupon)
          }
          # バンドルクーポンや課金クーポン
          @coupon_info = Plugin::IIJ_COUPON_CHECKER::CouponInfo.new(hddServiceCode: d.dig('hddServiceCode'),
                                                                    hdo_info: @hdo_info,
                                                                    coupon: coupons,
                                                                    plan: d.dig('plan'))
          info.push(@coupon_info)
        }
        info
      }
    end


    # クーポンの利用状態の切り替え（On/Off）
    # @param [Bool] is_valid クーポンのオン・オフのフラグ
    def switch(is_valid)
      Thread.new {
        client = HTTPClient.new
        # FIXME: hdoの取得方法を考える
        data = {
            :couponInfo => [{:hdoInfo => [{:hdoServiceCode => hdo, :couponUse => is_valid}]}]
        }.to_hash
        client.default_header = {
            'Content-Type': 'application/json',
            'X-IIJmio-Developer': @client_id,
            'X-IIJmio-Authorization': token
        }
        client.put(@coupon_url, JSON.generate(data))
      }.next { |response|
        Delayer::Deferred.fail(response) unless (response.nil? or response&.status_code == 200)
        # TODO: 正常に変更された場合の処理を書く
      }.trap { |err|
        activity :iij_coupon_checker, "クーポンの切り替えに失敗しました: #{err}"
        error err
      }
    end


    private


    def self.token
      UserConfig['iij_access_token']
    end

  end
end