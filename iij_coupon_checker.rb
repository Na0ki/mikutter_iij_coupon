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
          role: :timeline) do |_|
    # クーポンの取得
    Plugin::IIJ_COUPON_CHECKER::CouponInfo.get_info.next { |data|
      data.each do |d|
        d[:hdo_info].each do |info|
          # 投稿
          post(_("hdoServiceCode: %{hdo}\n電話番号: %{number}\nクーポン利用状況: %{couponUse}\n規制状態: %{regulation}\nSIM内クーポン残量: %{couponRemaining} [MB]") \
          % {
              hdo: d[:hddServiceCode],
              number: info[:number],
              couponUse: info[:couponUse] ? '使用中' : '未使用',
              regulation: info[:regulation] ? '規制中' : '規制なし',
              couponRemaining: info[:coupon].first.volume
          })
        end
      end
    }.trap { |e|
      activity :iij_coupon_checker, "クーポン情報の取得に失敗しました: #{e}"
      error e
    }
  end


  # クーポンの利用オン・オフ切り替え
  command(:switch_iij_coupon,
          name: 'クーポンの使用を変更',
          condition: lambda { |_| true },
          visible: true,
          role: :timeline) do |_opt|
    Plugin::IIJ_COUPON_CHECKER::CouponInfo.get_info.next { |data|
      list = Hash.new
      data.each do |info|
        info[:hdo_info].each do |hdo|
          key = hdo[:number] ? hdo[:number] : hdo[:hdoServiceCode]
          list[key] = hdo[:hdoServiceCode]
        end
      end

      Delayer.new {
        # クーポンのステータス
        status_list = %w(オン オフ)
        # ダイアログ
        dialog = Gtk::Dialog.new('クーポンを切り替える',
                                 $main_application_window,
                                 Gtk::Dialog::DESTROY_WITH_PARENT,
                                 [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK],
                                 [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
        # 切り替えるIDの選択肢の生成
        dialog.vbox.add(Gtk::Label.new('回線の種類'))
        service = Gtk::ComboBox.new(true)
        dialog.vbox.add(service)
        list.each_key { |key| service.append_text(key) }

        # オン/オフ切り替えボタン
        dialog.vbox.add(Gtk::Label.new('切り替え'))
        switch = Gtk::ComboBox.new(true)
        dialog.vbox.add(switch)
        status_list.each { |s| switch.append_text(s) }

        service.set_active(0)
        switch.set_active(0)
        dialog.show_all
        result = dialog.run

        # ダイアログの結果に応じて処理を分ける
        case result
          when Gtk::Dialog::RESPONSE_OK
            hdo = list.values[service.active]
            status = !!(switch.active == 0)
            # ダイアログを削除
            dialog.destroy
            Thread.new do
              Plugin::IIJ_COUPON_CHECKER::CouponInfo.switch(hdo, status).next { |_|
                notice 'coupon status successfully changed to %{status}' % {status: status ? 'オン' : 'オフ'}
                post("クーポンのステータスが更新されました\nhdoServiceCode: %{hdo}\nクーポンのステータス: %{status}" % {hdo: hdo, status: status ? 'オン' : 'オフ'})
              }.trap { |e|
                activity :iij_coupon_checker, 'クーポンの切り替えに失敗しました: %{error}' % {error: e.reason}
                post("ステータスコード: %{status}\n%{reason}" % {status: e.status, reason: e.reason})
                error e
              }
            end
          when Gtk::Dialog::RESPONSE_CANCEL
            # ダイアログを削除
            dialog.destroy
          else
            # ダイアログを削除
            dialog.destroy
            Delayer::Deferred.fail(result)
        end
      }
    }.trap { |e|
      activity :iij_coupon_checker, 'クーポン情報の取得に失敗しました: %{error}' % {error: e.reason}
      error 'status: %{status}, reason: %{reason}' % {status: e.status, reason: e.reason}
    }
  end


  on_iij_auth_success do
    # TODO: implement
  end


  on_iij_auth_failure do
    # TODO: implement
  end

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
  end

end
