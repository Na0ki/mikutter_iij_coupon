# -*- coding: utf-8 -*-

require 'httpclient'
require 'uri'
require 'json'

require_relative 'model'

Plugin.create(:iij_coupon_checker) do

  @coupon_url = 'https://api.iijmio.jp/mobile/d/v1/coupon/'

  class IDNotFoundError < StandardError;
  end

  begin
    id = UserConfig['iij_developer_id']
    if id.nil? || id == ''
      raise IDNotFoundError
    else
      @client_id = id
    end
  rescue IDNotFoundError => err
    activity :iij_coupon_checker, "デベロッパーIDが存在しません\nIDを設定してください\n: #{err}"
    error err
  end


  # 認証
  def auth
    uri = 'https://api.iijmio.jp/mobile/d/v1/authorization/' +
        "?response_type=token&client_id=#{@client_id}&state=mikutter_iij_coupon_checker&redirect_uri=#{UserConfig['iij_redirect_uri'] || 'localhost'}"

    Thread.new {
      Plugin.call(:open, uri)
      # FIXME: 認証部分を扱いやすいように改良する
    }.next { |response|
      # Delayer::Deferred.fail(response) unless (response.nil? or response&.status == 200)
      p response
    }.trap { |err|
      activity :iij_coupon_checker, "認証に失敗しました: #{err.to_s}"
      error err
    }
  end


  # クーポンの取得
  # @param [String] token トークン
  def check_coupon(token)
    Thread.new {
      client = HTTPClient.new
      client.default_header = {
          'Content-Type': 'application/json',
          'X-IIJmio-Developer': @client_id,
          'X-IIJmio-Authorization': token
      }
      client.get_content(@coupon_url)
    }.next { |response|
      result = JSON.parse(response)
      coupon_data(result)
      #     .each { |msg|
      #   user = Mikutter::System::User.new(idname: 'iijmio_coupon',
      #                                     name: 'Coupon Checker',
      #                                     icon: Skin['icon.png'])
      #   timeline(:home_timeline) << Mikutter::System::Message.new(user: user,
      #                                                             description: msg)
      # }
    }.trap { |err|
      activity :iij_coupon_checker, "クーポン情報の取得に失敗しました: #{err}"
      error err

      # TODO: トークン切れの場合はauthを実行する
    }
  end


  # クーポンのオン・オフの切り替え
  # @param [String] hdo hdoServiceInfo
  # @param [boolean] switch オン/オフ
  def switch_coupon(token, hdo, switch)
    Thread.new {
      client = HTTPClient.new
      data = {
          :couponInfo => [{:hdoInfo => [{:hdoServiceCode => hdo, :couponUse => switch}]}]
      }.to_hash
      client.default_header = {
          'Content-Type': 'application/json',
          'X-IIJmio-Developer': @client_id,
          'X-IIJmio-Authorization': token
      }
      client.put(@coupon_url, JSON.generate(data))
    }.next { |response|
      user = Mikutter::System::User.new(idname: 'iijmio_coupon',
                                        name: 'Coupon Checker',
                                        icon: Skin['icon.png'])
      if response.status_code == 200
        msg = "クーポンのステータスが変更されました\n" +
            "hdoServiceCode: #{hdo}\n" +
            "現在の状態: #{switch ? '使用中' : '未使用'}"
      else
        p response
        msg = "ステータスコード: #{response.status} (#{response.reason})\n" +
            "詳細: #{JSON.parse(response.content).dig('returnCode')}"
      end
      timeline(:home_timeline) << Mikutter::System::Message.new(user: user,
                                                                description: msg)
    }.trap { |err|
      activity :iij_coupon_checker, "クーポンの切り替えに失敗しました: #{err}"
      error err
    }
  end


  # クーポンの情報を整形してポストする
  # @param [JSON] data
  # @return [Array] 整形済みの文字列を格納した配列
  def coupon_data(data)

    c = Plugin::IIJ_COUPON_CHECKER::CouponInfo.new(@token)
    c.get_coupon_info.next { |d|
      p "d: #{d}"
      p "d: #{d}"
    }
    # messages = []
    # data['couponInfo'].each { |d|
    #   # SIM内クーポン
    #   sim_coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: d.dig('hdoInfo', 0, 'coupon', 0, 'volume'),
    #                                                       expire: d.dig('hdoInfo', 0, 'coupon', 0, 'expire'),
    #                                                       type: d.dig('hdoInfo', 0, 'coupon', 0, 'type'))
    #   hdo_info = Plugin::IIJ_COUPON_CHECKER::HDOInfo.new(regulation: d.dig('hdoInfo', 0, 'regulation'),
    #                                                      couponUse: d.dig('hdoInfo', 0, 'couponUse'),
    #                                                      iccid: d.dig('hdoInfo', 0, 'iccid'),
    #                                                      coupon: sim_coupon,
    #                                                      hdoServiceCode: d.dig('hdoInfo', 0, 'hdoServiceCode'),
    #                                                      voice: d.dig('hdoInfo', 0, 'voice'),
    #                                                      sms: d.dig('hdoInfo', 0, 'sms'),
    #                                                      number: d.dig('hdoInfo', 0, 'number'))
    #   # バンドルクーポンや課金クーポン
    #   # FIXME: 複数のクーポン情報を適切にモデルに落とし込めるようにする
    #   coupon = Plugin::IIJ_COUPON_CHECKER::Coupon.new(volume: 0,
    #                                                   expire: '201701',
    #                                                   type: 'bundle')
    #   coupon_info = Plugin::IIJ_COUPON_CHECKER::CouponInfo.new(hddServiceCode: d.dig('hddServiceCode'),
    #                                                            hdoInfo: hdo_info,
    #                                                            coupon: coupon,
    #                                                            plan: d.dig('plan'))
    #   c = Plugin::IIJ_COUPON_CHECKER::CouponInfo.new(@token)
    #   p "CouponInfo: #{c}"
    #
    #   msg = "hdoServiceCode: #{hdo_info[:hdoServiceCode]}\n" +
    #       "電話番号: #{hdo_info[:number]}\n" +
    #       "クーポン利用状況: #{hdo_info[:couponUse] ? '使用中' : '未使用'}\n" +
    #       "規制状態: #{hdo_info[:regulation] ? '規制中' : '規制なし'}\n" +
    #       "SIM内クーポン残量: #{sim_coupon[:expire]} [MB]"
    #   messages.push(msg)
    # }
    # messages
  end


  # クーポン確認コマンド
  command(:check_iij_coupon,
          name: 'クーポンの確認をする',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline
  ) do |_|
    @token = UserConfig['iij_access_token']
    # トークンがなければ認証
    auth unless @token
    # クーポンの取得
    check_coupon(@token)
  end


  # クーポンの利用オン・オフ切り替え
  command(:switch_iij_coupon,
          name: 'クーポンの使用を変更',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline
  ) do |_|
    @token = UserConfig['iij_access_token']
    # トークンがなければ認証
    auth unless @token

    # TODO: オンオフを実行する

  end

  defactivity :iij_coupon_checker, 'IIJクーポンチェッカ'

  # mikutter設定画面
  # @see http://mikutter.blogspot.jp/2012/12/blog-post.html
  settings('iijクーポン') do
    settings('デベロッパID') do
      input 'デベロッパID', :iij_developer_id
    end

    settings('トークン') do
      input 'アクセストークン', :iij_access_token
    end

    settings('リダイレクトURI') do
      input 'URI', :iij_redirect_uri
    end
  end


  def inspect
    "#{self.class.to_s} #{Time.now}: "
  end

end
