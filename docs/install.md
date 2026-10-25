# iPhone に入れる

Xcode から自分の iPhone にビルドして入れる手順。

## 用意するもの

- iOS 26 以上の iPhone（デプロイメントターゲットが 26.0）
- Xcode 26 以降
- Xcode にサインインした Apple ID（Xcode → Settings → Apple Accounts）
  - 無料の Apple ID でも入れられるが、7 日でアプリが起動しなくなり、入れ直しが必要になる
  - Apple Developer Program（有料）なら 1 年もつ

## 手順

1. iPhone を USB で Mac につなぎ、iPhone に出る「このコンピュータを信頼しますか」で「信頼」を選ぶ。
2. `Arcman.xcodeproj` を開く。

   ```sh
   open Arcman.xcodeproj
   ```

3. 左のナビゲータで一番上の `Arcman` を選び、TARGETS の **`Arcman`** → Signing & Capabilities → Team で自分の Team を選ぶ。
4. TARGETS の **`ArcmanShare`** でも同じ Team を選ぶ。片方だけだと、共有メニューの拡張の署名で失敗する。
5. 画面上部の実行先でつないだ iPhone を選び、⌘R でビルドして実行する。
6. 初回だけ iPhone 側で次の 2 つが必要になる。
   - **デベロッパモード**: 設定 → プライバシーとセキュリティ → デベロッパモード をオンにすると、iPhone が再起動する。再起動後にもう一度 ⌘R を押す。
   - **デベロッパの信頼**: 「信頼されていないデベロッパ」と出たら、設定 → 一般 → VPN とデバイス管理 で自分の Apple ID を選び「信頼」を押す。
7. アプリが起動したら、サーバーの URL（例: `http://100.64.0.1:3000`）とパスワードを入力してログインする。

## 共有メニューから保存する

アプリで一度ログインしておけば、Safari や X などの共有ボタンで「ARCMAN」を選ぶと URL を保存できる。共有シートに出ないときは、アイコン列の右端の「その他」から追加する。

## うまくいかないとき

- **バンドル ID が使えないと言われる**: `io.github.kobago.arcman` が他のアカウントで登録済みの場合に起きる。両ターゲットの Bundle Identifier を自分用の値に変える。`ArcmanShare` の ID は `<アプリの ID>.share` にする。
- **App Group が作れないと言われる**: `group.io.github.kobago.arcman` を次の 3 か所で同じ値に変える。
  - `Arcman` の Signing & Capabilities → App Groups
  - `ArcmanShare` の Signing & Capabilities → App Groups
  - `Shared/API.swift` の `Server.appGroup`
- **無料の Apple ID で App Group が使えないかもしれない**: まだ確かめていない。使えない場合は Developer Program に登録する必要がある。
