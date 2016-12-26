# -*- coding: utf-8 -*-

require 'httpclient'
require 'uri'
require 'json'

require_relative 'model'

Plugin.create(:iij_coupon_checker) do

  @auth_url = 'https://api.iijmio.jp/mobile/d/v1/authorization/'
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


  def auth
    uri = @auth_url +
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
      p response
    }.trap { |err|
      activity :iij_coupon_checker, "クーポン情報の取得に失敗しました: #{err}"
      error err

      # TODO: トークン切れの場合はauthを実行する
    }
  end


  def switch_coupon(hdo, switch)
    Thread.new {
      client = HTTPClient.new
      data = {
        'couponInfo': [{
          'hdoInfo': [
             {
              'hdoServiceCode': hdo,
              'couponUse': switch
             }
          ]
        }]
      }
      client.default_header = {
          'Content-Type': 'application/json',
          'X-IIJmio-Developer': @client_id,
          'X-IIJmio-Authorization': token
      }
      client.put(@coupon_url, data)
    }.next { |response|
      p response
    }.trap { |err|
      activity :iij_coupon_checker, "クーポンの切り替えに失敗しました: #{err}"
      error err
    }
  end


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
    "#{self.class.to_s}(client_id=#{@client_id}, token=#{@token})"
  end

end
