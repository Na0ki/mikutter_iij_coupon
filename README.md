# mikutter_iij_coupon
iij couponのチェックとかできるやつ（を目指してる）  
認証部分はまだちゃんと手をつけてないので適当です

# インストール方法
```
$ mkdir -p ~/.mikutter/plugin && cd ~/.mikutter/plugin/
$ git clone https://github.com/Na0ki/mikutter_iij_coupon iij_coupon_checker
```

# 使い方（暫定）
1. iijのデベロッパー登録をする  
[デベロッパコンソール](https://api.iijmio.jp/) からログインし, デベロッパIDを取得する.

1. アプリの登録  
デベロッパコンソールでアプリの登録を行う.  
アプリ名及びリダイレクトURLは任意のものを設定する. (後ほどmikutter側に設定する)

1. mikutterの設定  
mikutterの設定を開き, 「iijクーポン」を開く.  
「デベロッパID」, 「リダイレクトURI」の項目に先ほどiijのコンソールで登録したものを設定する.  

1. 認証
mikutterのタイムラインで右クリックをして, クーポンの確認を選択する.  
ブラウザに飛ばされるので, アプリを許可する.  
URLパラメータに `access_token` が現れたら, それをコピーする.  
mikutterの設定で「アクセストークン」を設定する.


# Special Thanks
* ておくれ御本尊（[@toshi_a](https://github.com/toshia)）  
    本プラグインの作成にあたり、色々教えていただきました  
    Premiaumuな感謝を
* あっきぃ（[@Akkiesoft](https://github.com/Akkiesoft)）  
    ダイアログの実装周りは [新幹線プラグイン](https://github.com/Akkiesoft/mikutter_shinkansen_tokaido_sanyo) を参考にしました.  
    ﾚｨﾃﾞｨｽｴﾝﾄﾞｼﾞｪﾝﾄｩﾒﾝ。ｳｪｩｶﾑﾄｩｻﾞｼｨﾝｶｧﾝｾｪﾝ
* トイレ  
    本ソースの一部はトイレで書かれたウンコードになります.  
    お腹事情を支えてくれたトイレに感謝

# ライセンス
* mikutter_iij_coupon  
[MIT LICENSE](/LICENSE)

* Material icons  
[Apache License Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
