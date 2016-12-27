# -*- coding: utf-8 -*-

require_relative 'coupon'
require_relative 'hdo_info'

module Plugin::IIJ_COUPON_CHECKER
  class CouponInfo < Retriever::Model

    field.string  :hddServiceCode
    field.has     :hdoInfo, Plugin::IIJ_COUPON_CHECKER::HDOInfo
    field.has     :coupon, Plugin::IIJ_COUPON_CHECKER::Coupon
    field.string  :plan


    def initialize(token)
      @token = token
      @client_id = UserConfig['iij_developer_id']
      @coupon_url = 'https://api.iijmio.jp/mobile/d/v1/coupon/'
    end


    # クーポンの情報を返す
    # 一度でもクーポンの取得に成功すると、二度目以降はその内容を返す
    # FIXME: あとで修正する（毎回新しい情報が必要？）
    def info
      cache = @coupon_info
      if cache
        Delayer::Deferred.new.next { |info| @coupon_info = info.freeze }
      else
        get_coupon_info(@token).next { |info| @coupon_info = info.freeze }
      end
    end


    #
    def info!
      @coupon_info
    end


    # クーポンの利用状態の切り替え（On/Off）
    # @param
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
            'X-IIJmio-Authorization': @token
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


    def inspect
      "#{self.class.to_s}(hdd = #{hddServiceCode}, plan = #{plan})"
    end


    private

    # クーポン情報の取得
    # @return [Delayer::Deferred::Deferredable] クーポンのモデルを引数にcallbackするDeferred
    def get_coupon_info
      Thread.new {
        client = HTTPClient.new
        client.default_header = {
            'Content-Type': 'application/json',
            'X-IIJmio-Developer': @client_id,
            'X-IIJmio-Authorization': @token
        }
        client.get_content(@coupon_url)
      }.next { |response|
        data = JSON.parse(response)
        return coupon_data(data)
      }.trap { |err|
        activity :iij_coupon_checker, "クーポン情報の取得に失敗しました: #{err}"
        error err
        # TODO: トークン切れの場合はauthを実行する
      }
    end


    # クーポンのJSONをモデルに落とし込む
    # @param [JSON] クーポンのJSON
    # @return [Array] SIMごとのクーポン情報のモデルを配列に格納して返す
    def coupon_data(data)
      info = []
      data['couponInfo'].each { |d|
        # SIM内クーポン
        sim_coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: d.dig('hdoInfo', 0, 'coupon', 0, 'volume'),
                                                            expire: d.dig('hdoInfo', 0, 'coupon', 0, 'expire'),
                                                            type: d.dig('hdoInfo', 0, 'coupon', 0, 'type'))
        hdo_info = Plugin::IIJ_COUPON_CHECKER::HDOInfo.new(regulation: d.dig('hdoInfo', 0, 'regulation'),
                                                           couponUse: d.dig('hdoInfo', 0, 'couponUse'),
                                                           iccid: d.dig('hdoInfo', 0, 'iccid'),
                                                           coupon: sim_coupon,
                                                           hdoServiceCode: d.dig('hdoInfo', 0, 'hdoServiceCode'),
                                                           voice: d.dig('hdoInfo', 0, 'voice'),
                                                           sms: d.dig('hdoInfo', 0, 'sms'),
                                                           number: d.dig('hdoInfo', 0, 'number'))
        # バンドルクーポンや課金クーポン
        # FIXME: 複数のクーポン情報を適切にモデルに落とし込めるようにする
        coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: 0,
                                                        expire: '201701',
                                                        type: 'bundle')
        coupon_info = Plugin::IIJ_COUPON_CHECKER::CouponInfo.new(hddServiceCode: d.dig('hddServiceCode'),
                                                                 hdoInfo: hdo_info,
                                                                 coupon: coupon,
                                                                 plan: d.dig('plan'))
        info.push(coupon_info)
      }
      info
    end

  end
end