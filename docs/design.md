# arcman iOS クライアント 要件・設計（MVP）

arcman のサーバー（[arcman](https://github.com/kobago/arcman)）に接続する iPhone アプリ。Web のフロントエンドと同じ見た目と機能を SwiftUI で作る。

- 作成日: 2026-10-24
- 元にした文書: arcman の `docs/requirements.md`、`docs/frontend-design.md`、`docs/backend-design.md`、`frontend/src/index.css`
- 「仮決定」は、レビューで変えてよい既定の判断

## 1. 前提

| 項目 | 内容 |
|---|---|
| 利用者 | 自分ひとり。App Store には出さない（Xcode から自分の端末に入れる） |
| 端末 | iPhone のみ。iPad は後で検討 |
| 対応 OS | iOS 26 以上（仮決定。手元の Xcode 26.4 で、自分の端末だけに入れるため） |
| サーバー | 既存の arcman の API をそのまま使う。サーバー側の変更はしない |
| 技術 | Swift 6、SwiftUI、Observation（`@Observable`）。外部ライブラリは使わない |

## 2. 機能要件

Web の要件定義（2.1〜2.9）と同じ機能を持つ。違うところだけを書く。

### 2.1 接続とログイン

- ログイン画面でサーバーの URL（例: `http://100.x.y.z:3000`）とパスワードを入力する
- サーバーの URL は端末に保存する。パスワードは保存しない
- セッションの Cookie は `HTTPCookieStorage` に保存し、30日間ログインしたままにする
- API が 401 を返したらログイン画面に戻る
- Tailscale 越しの `http` に接続できるよう、ATS の制限を外す（`NSAllowsArbitraryLoads`）

### 2.2 画面ごとの対応

| Web | iOS |
|---|---|
| ギャラリー（行の高さを揃えたタイル、無限スクロール、取得中は3秒ごとに更新） | 同じ。行詰めは `layout.ts` の `justify` を移植する。大きさの5段階はピンチで変え、端末に保存する |
| サイドバー（スマホはドロワー） | 左から引き出すドロワー。カテゴリとフォルダの作成、名前の変更、削除。並べ替えと別のカテゴリへの移動は各項目のメニュー（「上へ移動」「下へ移動」「カテゴリを移す」）で行う |
| 保存（スマホは「＋」のシート） | 「＋」のシート。改行区切りで複数件。結果はトーストで出す |
| 絞り込み（キーワード、タグ、期間、メディア、投稿者、並び順） | 同じ。条件はアプリの状態として持ち、URL には入れない |
| 詳細（写真アプリ風、下からのシート） | 全画面で横にページ送り。下のつまみをドラッグして投稿の内容を出す。画像をタップするとボタンとシートを隠す |
| 動画、GIF | 動画は `AVPlayer` で音あり再生。GIF（mp4）はギャラリーで音なしのループ再生 |
| YouTube | `WKWebView` で youtube-nocookie.com の埋め込みプレーヤー |
| メディアの保存ボタン | 写真ライブラリに保存する（追加のみの権限） |
| タグの管理、設定 | 同じ。設定にはログアウト、全端末からのログアウト、テーマを置く |

### 2.3 Web と変える点

- 表示言語は OS の設定（設定アプリの言語）に従い、アプリ内の切り替えは作らない（仮決定）
- テーマは OS に合わせつつ、設定画面でライトとダークを選べる（Web と同じ）
- 詳細画面の「戻る」は、下へのスワイプと閉じるボタンで行う

### 2.4 共有メニューからの保存

- x.com のアプリや Safari の共有メニューに「arcman」を出し、共有された URL をその場で保存する（Share Extension）
- 受け取るのは URL と、URL を含むテキスト。テキストの場合は最初の `http`・`https` の URL を使う
- 保存先は未分類（仮決定。フォルダは後で詳細画面から移す）
- 結果（保存した、保存済み、保存できない理由）を小さなシートに出す。保存したときは1秒ほどで自動で閉じる
- ログインしていなければ「アプリでログインしてください」と出す
- サーバーの URL と Cookie は App Group で本体と共有する

### 2.5 MVP の対象外

- iPad 向けのレイアウト、オフラインでの閲覧、ウィジェット、通知
- Web の要件で対象外のもの（画像のズーム、複数選択など）

## 3. 設計

### 3.1 デザイン

`index.css` の値をそのまま使う。

- 色: CSS 変数（`--bg`、`--panel`、`--raised`、`--line`、`--text`、`--muted`、`--selected`、`--accent` など）を、ライトとダークの値を持つ `Color` の定数にする。ダークが既定
- フォント: IBM Plex Sans JP（400、500、600）と IBM Plex Mono（400、500）をアプリに同梱する（SIL OFL）。本文は 14pt、入力欄は 16pt
- 角丸 8pt、詳細画面の背景は `--stage`
- ロゴ: `Logo.tsx` のモノグラムとワードマークの SVG パスを SwiftUI の `Path` に移す。アプリアイコンもモノグラムから作る
- アイコン: Web の `Icon.tsx` に近い SF Symbols を使う（仮決定。同じ形を移植するより手間が少なく、iOS で自然に見える）

### 3.2 構成

| ファイル | 役割 |
|---|---|
| `API.swift` | `URLSession` の async/await で API を呼ぶ。型は `api.ts` に合わせた `Codable`（snake_case を変換） |
| `Session.swift` | サーバーの URL、ログイン状態、401 の扱い |
| `Theme.swift` | 色、フォント |
| `Layout.swift` | タイルの行詰め（`justify`、`aspectRatio`） |
| `Filters.swift` | 絞り込み条件と `/api/tiles` のクエリ |
| `TagKey.swift` | タグキーの正規化（サーバーと同じ規則） |
| `ShareViewController.swift` | Share Extension。共有された URL を取り出して `POST /api/posts` を呼ぶ |
| `Views/` | `LoginView`、`GalleryView`、`SidebarView`、`SaveSheet`、`FilterBar`、`DetailView`、`TagsView`、`SettingsView` |

- Cookie は App Group の `HTTPCookieStorage` に置き、本体と Share Extension で同じ `URLSession` の設定を使う。サーバーの URL は App Group の `UserDefaults` に置く
- `/media/` も Cookie で認証されるので、画像は `AsyncImage`（`URLSession.shared` しか使えない）ではなく、同じ `URLSession` で読む自前のビューで表示する。ギャラリーでは表示する大きさに縮小してからメモリに持つ。ディスクのキャッシュは `URLCache`
- 動画は `AVURLAsset` に `AVURLAssetHTTPCookiesKey` で Cookie を渡す
- 状態は画面ごとの `@Observable` のモデルに持つ。ログイン状態、サイドバー、タグの一覧、ギャラリーのタイルは複数の画面で使うので、アプリ全体のモデル（`AppModel`）に持つ

### 3.3 プロジェクト

- ターゲットは本体（`Arcman`）、Share Extension（`ArcmanShare`）、テスト（`ArcmanTests`）。API と型は `Shared/` に置いて本体と Share Extension の両方で使う
- Xcode プロジェクト（`Arcman.xcodeproj`）。フォルダ同期（Xcode 16 以降の形式）にして、ファイルを足してもプロジェクトファイルを編集しなくて済むようにする
- XcodeGen などの生成ツールは使わない（仮決定）
- テスト: Swift Testing で行詰め、タグキー、クエリの組み立てを確かめる。画面のテストは作らない
- 署名は自分の Apple ID（Personal Team か Developer Program）で行う

### 3.4 作る順番

1. ログイン、ギャラリー（行詰め、無限スクロール）、詳細（画像と投稿の内容）
2. 保存、取得中の更新、動画と GIF、YouTube、Web ページ
3. サイドバー、フォルダの移動、タグ、削除
4. 絞り込み、タグの管理、設定
5. 共有メニューからの保存
