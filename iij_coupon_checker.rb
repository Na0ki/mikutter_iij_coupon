# -*- coding: utf-8 -*-

require 'httpclient'
require 'uri'
require 'json'

require_relative 'model'

Plugin.create(:iij_coupon_checker) do

  @base_url = 'https://api.iijmio.jp/mobile/d/v1/authorization/'

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
    uri = @base_url +
        "?response_type=token&client_id=#{@client_id}&state=mikutter_iij_coupon_checker&redirect_uri=#{UserConfig['iij_redirect_uri'] || 'localhost'}"

    Thread.new {
      Plugin.call(:open, uri)
      # client = HTTPClient.new
      # client.get(uri)
    }.next { |response|
      # Delayer::Deferred.fail(response) unless (response.nil? or response&.status == 200)
      # puts response
      # p response.status
      # p response.contenttype
      # p response.body
      p response
    }.trap { |err|
      activity :iij_coupon_checker, "認証に失敗しました: #{err.to_s}"
      error err
    }
  end


  def check_coupon
    Thread.new {

    }.next { |_|

    }.trap { |err|
      activity :iij_coupon_checker, "クーポン情報の取得に失敗しました: #{err}"
      error err
    }
  end


  command(:check_iij_coupon,
          name: 'クーポンの確認をする',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline
  ) do |_|
    auth
  end


  # mikutter設定画面
  # @see http://mikutter.blogspot.jp/2012/12/blog-post.html
  settings('iijクーポン') do
    settings('デベロッパID') do
      input 'デベロッパID', :iij_developer_id
    end

    settings('リダイレクトURI') do
      input 'URI', :iij_redirect_uri
    end
  end

end
