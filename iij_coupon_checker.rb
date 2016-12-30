# -*- coding: utf-8 -*-

require 'json'

require_relative 'model'

Plugin.create(:iij_coupon_checker) do

  # メッセージの投稿
  # @param [String] msg 投稿メッセージ
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
          role: :timeline) { |_|
    # クーポンの取得
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
    }
  }


  # クーポンの利用オン・オフ切り替え
  command(:switch_iij_coupon,
          name: 'クーポンの使用を変更',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline) { |_|
    Plugin::IIJ_COUPON_CHECKER::CouponInfo.get_info.next { |data|
      hdo_list = Hash.new
      data.each { |d|
        info = d.instance_variable_get(:@value)
        code = info[:hdo_info].hdoServiceCode
        status = info[:hdo_info].couponUse
        hdo_list[code] = status
      }
      hdo_list
    }.next { |list|
      status_list = %w(オン オフ)

      Delayer.new {
        dialog = Gtk::Dialog.new('クーポンを切り替える',
                                 $main_application_window,
                                 Gtk::Dialog::DESTROY_WITH_PARENT,
                                 [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK ],
                                 [ Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL ])

        dialog.vbox.add(Gtk::Label.new('回線の種類'))
        service_list = Gtk::ComboBox.new(true)
        dialog.vbox.add(service_list)
        list.each_key { |key| service_list.append_text(key) }

        dialog.vbox.add(Gtk::Label.new('切り替え'))
        switch = Gtk::ComboBox.new(true)
        dialog.vbox.add(switch)
        status_list.each { |s| switch.append_text(s)}

        service_list.set_active(0)
        switch.set_active(0)
        dialog.show_all

        result = dialog.run

        begin
          Delayer::Deferred.fail(result) unless Gtk::Dialog::RESPONSE_OK
          hdo = list.keys[service_list.active]
          status = switch.active == 0 ? true : false

          # SIMのクーポン状態と指定した状態（オン・オフ）が同じ場合はリクエストを行わない
          if list.values[service_list.active] == status
            msg = "サービスコード #{hdo} のクーポンのステータスはすでに#{status ? 'オン' : 'オフ'}です"
            post(msg)
          else
            Thread.new {
              Plugin::IIJ_COUPON_CHECKER::CouponInfo.switch(hdo, status).next { |_response|
                msg = "クーポンのステータスが更新されました\n" +
                    "hdoServiceCode: #{hdo}\n" +
                    "クーポンのステータス: #{status ? 'オン' : 'オフ'}"
                # 投稿
                post(msg)
              }.trap { |err|
                activity :iij_coupon_checker, "クーポンの切り替えに失敗しました: #{err}"
                error err
                msg = "ステータスコード: #{err.status} (#{err.reason})\n" +
                    "詳細: #{JSON.parse(err.content).dig('returnCode')}"
                post(msg)
              }
            }
          end
        ensure
          dialog.destroy
        end
      }
    }
  }


  # アクティビティの設定
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
