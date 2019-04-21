---
title: "雑なオレオレOAuth Serverを書いた"
date: 2019-04-21T23:21:17+09:00
draft: false
toc: true
type: post
images:
tags:
  - jwt
  - oauth
  - ldap
---

<style>
img {
  max-width: 50% !important;
  display: block;
  margin: 0 auto;
}
</style>

タイトルの通り．
[authserver](https://github.com/mas9612/authserver)というそのまんまな名前でGitHubにおいている．

自分で使う用としてとりあえず書いただけなので，お粗末 かつ セキュリティ的にやばい部分もたくさん残っているはず．

## 構成
構成は次の図の通り．
ユーザの認証はLDAP（Lightweight Directory Access Protocol）で行っている．

![authserver-architecture](/images/authserver-architecture.png)

認証〜トークンの返却は次のような流れで進む．

1. クライアントがauthserverへ認証情報を送る
1. 受け取った認証情報を使って，authserverがLDAPサーバに対してユーザ認証を試行する
1. LDAPによる認証が成功したら，authserverがJWTトークンを発行する
1. 発行されたトークンをクライアントへ返却する

トークンが発行されたら，あとはそれを各サービス側で検証することでログインを行うことができる．
JWTトークンには認証されたクライアントのユーザ名が含まれているので，各サービス側ではそれを使ってユーザを識別することができる．

## 実装
### ユーザ認証部分
LDAPサーバとのやり取りは，[ldapパッケージ](https://godoc.org/gopkg.in/ldap.v3)を使っている（ `go ldap` で調べると，同名のパッケージがたくさん出てきて少し困る）．
とりあえずクライアントから渡された認証情報が正しいかどうかを確かめられればそれでよかったので，クライアントから渡された情報を使ってLDAPサーバにバインドできるかどうかを確かめるだけという感じで雑に処理した．

https://github.com/mas9612/authserver/blob/42242050bbee2edd2a07f747adf03ba574f541fe/pkg/server/authserver.go#L114-L126
```go
conn, err := ldap.Dial("tcp", fmt.Sprintf("%s:%d", s.ldapaddr, s.ldapport))
if err != nil {
    errMsg := "failed to connect to LDAP server"
    s.logger.Error(errMsg, zap.Error(err))
    return nil, status.Error(codes.Internal, errMsg)
}
defer conn.Close()

if err := conn.Bind(fmt.Sprintf(s.userFormat, req.User), req.Password); err != nil {
    errMsg := "bind failed"
    s.logger.Error(errMsg, zap.Error(err))
    return nil, status.Error(codes.Unauthenticated, errMsg)
}
```

ユーザ認証に成功したら，次のJWTトークン生成に移る．
ここでユーザ認証に失敗した場合は， `Unauthenticated` エラーを返却して処理は終了となる．

### JWTトークン生成
JWT関連の実装は[dgrijalva/jwt-go](https://github.com/dgrijalva/jwt-go)を使っている．
肝心の発行部分はライブラリが面倒を見てくれるので，必要な情報を用意して渡してあげるだけですむ．

Claimには，RFC7519で定義されている[Registered Claim Names](https://tools.ietf.org/html/rfc7519#section-4.1)と，ユーザを識別するためのユーザ名を含めている．
トークンの署名はRS256（RSA + SHA-256）を使っている．

https://github.com/mas9612/authserver/blob/42242050bbee2edd2a07f747adf03ba574f541fe/pkg/server/authserver.go#L139-L158
```go
nowUnix := time.Now().Unix()
v4 := uuid.NewV4()
claims := AuthClaim{
    req.User,
    jwt.StandardClaims{
        Audience:  req.OrigHost,
        ExpiresAt: nowUnix + 3600, // valid 1h
        Id:        v4.String(),
        IssuedAt:  nowUnix,
        Issuer:    s.issuer,
        NotBefore: nowUnix - 5,
        Subject:   "access_token",
    },
}
token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
ss, err := token.SignedString(signKey)
if err != nil {
    s.logger.Error("failed to generate JWT token", zap.Error(err))
    return nil, status.Error(codes.Internal, internalServerErrMsg)
}
```

## アプリケーション側でのトークン検証
今回作ったauthserverを使った認証をアプリケーションに組み込んでみた．
とりあえず，自分用に作っている[wrapups](https://github.com/mas9612/wrapups)というアプリケーションを対象とした．

wrapupsアプリケーションはgRPCサーバとして実装されている．
GoのgRPCサーバにはInterceptorという機能があり，これを使うことで各リクエストが処理される前に様々な処理を入れ込むことができる．
このInterceptorを使った便利なライブラリが[grpc-ecosystem/go-grpc-middleware](https://github.com/grpc-ecosystem/go-grpc-middleware)にまとまっている．

今回はリクエスト処理前に認証をはさみたいので，grpc-ecosystem/go-grpc-middlewareの中からgrpc_authと呼ばれるmiddlewareを利用していく．

使い方は割と簡単．まず，gRPCサーバのインスタンスを作成するときに，grpc_auth middlewareを利用するというオプションを渡してあげる．
```go
grpcServer := grpc.NewServer(
    grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(
        grpc_auth.UnaryServerInterceptor(authFunc),
    )),
)
```

このコード例では `grpc_auth.UnaryServerInterceptor()` を `grpc_middleware.ChainUnaryServer()` でラップしているが，今回のようにInterceptorを一つしか利用しない場合は直接 `grpc.UnaryInterceptor()` に渡してあげても動作する．

これで，各リクエストの処理が始まる前に， `grpc_auth.UnaryServerInterceptor()` の引数として渡した `authFunc` が実行されるようになる．
このメソッドの中で，JWTトークンの検証処理を書いていくことになる．

まず，リクエストからトークン部分を取り出す．
https://github.com/mas9612/wrapups/blob/c9f83cd372236f154b34b8dd369f9ffd16d1972d/cmd/wuserver/main.go#L91-L94
```go
token, err := grpc_auth.AuthFromMD(ctx, "bearer")
if err != nil {
    return nil, err
}
```

これで，Authorizationヘッダに入っているbearerトークンが `token` に格納される．

その後，トークンのパース・検証に移る．
トークンのパースと検証は， `jwt.ParseWithClaims()` で行うことができる．
1つ目の引数にはトークン，2つ目にはパースしたClaimが格納される先のアドレスを渡す．
3つ目には，トークンを検証するための鍵を得るためのメソッドを渡す．

jwt.ParseWithClaimsは，内部で3つ目の引数に渡されたメソッドを実行し，その返り値を検証用の鍵としてトークンの検証を行う．
今回は簡単にするため，authserverと同じディレクトリに検証用のRSA公開鍵をおいておき，それを読み込んで返り値として返すという形にしている．

https://github.com/mas9612/wrapups/blob/c9f83cd372236f154b34b8dd369f9ffd16d1972d/cmd/wuserver/main.go#L96-L114
```go
claim := server.AuthClaim{}
_, err = jwt.ParseWithClaims(token, &claim, func(token *jwt.Token) (interface{}, error) {
    if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
        return nil, fmt.Errorf("requested signing method is not supported")
    }

    b, err := ioutil.ReadFile("./authserver.pub")
    if err != nil {
        return nil, err
    }
    verifyKey, err := jwt.ParseRSAPublicKeyFromPEM(b)
    if err != nil {
        return nil, err
    }
    return verifyKey, nil
})
if err != nil {
    return nil, status.Error(codes.Unauthenticated, fmt.Sprintf("failed to verify token: %s", err.Error()))
}
```

authFuncの全体は次の通り．

https://github.com/mas9612/wrapups/blob/c9f83cd372236f154b34b8dd369f9ffd16d1972d/cmd/wuserver/main.go#L90-L117
```go
func authFunc(ctx context.Context) (context.Context, error) {
	token, err := grpc_auth.AuthFromMD(ctx, "bearer")
	if err != nil {
		return nil, err
	}

	claim := server.AuthClaim{}
	_, err = jwt.ParseWithClaims(token, &claim, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("requested signing method is not supported")
		}

		b, err := ioutil.ReadFile("./authserver.pub")
		if err != nil {
			return nil, err
		}
		verifyKey, err := jwt.ParseRSAPublicKeyFromPEM(b)
		if err != nil {
			return nil, err
		}
		return verifyKey, nil
	})
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, fmt.Sprintf("failed to verify token: %s", err.Error()))
	}

	return context.WithValue(ctx, "user", claim.User), nil
}
```

これで必要な実装は完了したので，適当なクライアントを使って認証が求められること，また正しい認証情報を使って認証が成功することを確認する．

## まとめ
とりあえず最低限の機能が使えるOAuth serverを実装してみた．
まだまだいろいろ足りていない部分があるので，引き続き開発を続けていく．
