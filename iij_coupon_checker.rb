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


  # クーポンの取得
  # @param [String] token トークン
  def check_coupon
    Plugin::IIJ_COUPON_CHECKER::CouponInfo.get_info.next { |data|
      data.each { |d|
        info = d.instance_variable_get(:@value)
        msg = "hdoServiceCode: #{info[:hdo_info].hdoServiceCode}\n" +
            "電話番号: #{info[:hdo_info].number}\n" +
            "クーポン利用状況: #{info[:hdo_info].couponUse ? '使用中' : '未使用'}\n" +
            "規制状態: #{info[:hdo_info].regulation ? '規制中' : '規制なし'}\n" +
            "SIM内クーポン残量: #{info[:hdo_info].coupon.volume} [MB]"
        # 投稿
        post(msg)
      }
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



  def post(msg)
    user = Mikutter::System::User.new(idname: 'iijmio_coupon',
                                      name: 'Coupon Checker',
                                      icon: Skin['icon.png'])
    timeline(:home_timeline) << Mikutter::System::Message.new(user: user,
                                                              description: msg)
  end


  # クーポン確認コマンド
  command(:check_iij_coupon,
          name: 'クーポンの確認をする',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline
  ) do |_|
    # クーポンの取得
    check_coupon
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

end
