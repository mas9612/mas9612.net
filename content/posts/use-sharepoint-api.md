---
title: "SharePoint REST APIを使ってみた"
date: 2017-03-09T00:00:00+09:00
draft: true
type: post
---

SharePoint OnlineでサイトにアップロードしているExcelファイルを毎日自動でダウンロードしたいという要望をもらったので，
公開されているAPIを使ってやってみた．

## 環境

* OS X El Capitan v10.11.6
* Python 3.5.2
* Office 365 Enterprise E3

## Office 365 APIを使う

### 認証情報を取得する
Office 365 APIを使用するには，まずアクセストークンと呼ばれる認証情報を取得する必要がある．
次の手順でアクセストークンを取得する．

なお，今回はOffice 365 Enterprise E3を使用し，すでにSharePointでサイトを作成していることとする．

1.  [新Azure Portal](https://portal.azure.com/)にOffice 365の管理者アカウントでログインする．
2.  左側のメニューから「Azure Active Direcotory」を選択する．
3.  メニューから「アプリの登録」を選択する．
4.  ページ上部にある「追加」を選択して新規アプリケーションを作成する．

    * 名前: 好きなものを
    * アプリケーションの種類: Webアプリ/API
    * サインオンURL: 作成したアプリケーションを動かすURL

5.  アプリケーションの作成後，作成したアプリケーションを選択して，以下の情報をメモしておく．

    * アプリケーションID
    * ホームページ（サインオンURLで指定したものになっているはず）

6.  右側の設定メニューから「キー」を選択して新しくキーを作成する．
    キーの説明を入力して期間をドロップダウンリストから選択し，保存をクリックするとキーが生成される．
    この時キーを **必ず** メモしておくこと（この画面から移動した後はキーを再確認できない）．
7.  設定メニューから「必要なアクセス許可」を選択してアプリケーションに対して必要な権限を付与する．
    今回は，SharePointの機能を使いたいので，上部にある「追加」をクリック後，表示されるサービス名の中から
    「Office 365 SharePoint Online」を選択し，必要な権限を追加する．
8.  アクセストークンを生成するために必要な `code` を取得する．次のURLにGETでリクエストを送信する．
    * URL: `https://login.windows.net/common/oauth2/authorize?response_type=code&client_id=<client_id>&resource=<resource>&redirect_uri=<redirect_uri>`
    * パラメータ
        * `client_id` : アプリケーションID
        * `resource` : `https://<テナント名>.sharepoint.com/`
            （例: テナント名が `testtenant` → `https://testtenant.sharepoint.com/` ）
        * `redirect_uri` : サインオンURL

9.  正しくリクエストを送れていればログイン画面が表示され，ログインが成功すると `redirect_uri` で指定したURIにリダイレクトされ，パラメータに `code` がセットされる．
10.  取得した `code` を用いてアクセストークンを取得する．次のURLにPOSTでリクエストを送信する．
    * URL: `https://login.windows.net/common/oauth2/token`
    * HTTPヘッダに追加: `Content-Type: application/x-www-form-urlencoded`
    * リクエストボディ: `grant_type=authorization_code&code=<code>&client_id=<client_id>&client_secret=<client_secret>&redirect_uri=<redirect_uri>`
    * パラメータ
        * `code` : 先程取得したもの
        * `client_secret` : アプリケーション作成時に生成したキー

11.  正しくリクエストを送れていれば， `access_token` を含むJSONが返却される．

## APIを叩く
上記の手順で取得したアクセストークンを使用して実際にAPIを使用した．
APIを叩くときには，HTTPヘッダに取得したアクセストークンを以下のようなフォーマットで加える必要がある．

```
Authorization: Bearer <access_token>
```

今回はSharePointのサイト上にアップロードしているExcelファイルをダウンロードするのが目的なので，
それっぽいAPIをリファレンスから探し出して叩いてみた．

[SharePoint 2013 REST API リファレンス](https://msdn.microsoft.com/ja-jp/library/office/dn593591.aspx)によれば，
Fileというリソースがサイト内のファイルを表していて，そのファイルを取得するには次のようなURIを指定すれば良い．

```
http://<site_url>/_api/web/getfilebyserverrelativeurl('/<folder>/<file>')
```

また，ファイル自体をダウンロードするためには， `$value` というODataのクエリオプションを付加する．

というわけで，Pythonで簡単にAPIを叩く．なお，以下のプログラムではRequestsという外部ライブラリを使用しているので注意．

```python
import requests
import urllib.parse

def main():
    # ファイル自体を取得するため，$valueを付加
    uri = "https://<tenant>.sharepoint.com/_api/web/getfilebyserverrelativeurl('<file-path>')/$value"
    access_token = sys.argv[1]
    headers = {
        'accept': 'application/json;odata=verbose',
        'Content-Type': 'application/json;odata=verbose',
        'Authorization': 'Bearer ' + access_token,
    }
    res = requests.get(urllib.parse.quote(uri, safe=':/'), headers=headers, stream=True)
    with open('file.xlsx', 'wb') as f:
        f.write(res.raw.read())


if __name__ == '__main__':
    main()
```

これを実行すると，URIに指定したファイルが `file.xlsx` という名前でダウンロードされる．

## まだ未完成なところ

* 現時点では `code` を取得する際にブラウザを使う必要がある
    * Requestsモジュールの `Session` を使えばできるようなので後で修正する

## 参考にしたところ

* [Office 365 API入門](https://blogs.msdn.microsoft.com/tsmatsuz/2014/06/02/office-365-api/)
* [SharePoint 2013 REST API リファレンス](https://msdn.microsoft.com/ja-jp/library/office/dn593591.aspx)
