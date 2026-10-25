# ARCMAN for iOS

[arcman](https://github.com/kobago/arcman) のサーバーに接続する iPhone アプリ。Web の画面と同じ見た目と機能を SwiftUI で作っている。共有メニューから URL をそのまま保存できる。

## 動かす

Xcode 26 以降で `Arcman.xcodeproj` を開き、`Arcman` スキームを実行する。

実機に入れる手順は [iPhone に入れる](docs/install.md) にある。

初回はログイン画面でサーバーの URL（例: `http://100.64.0.1:3000`）とパスワードを入力する。

## テスト

```sh
xcodebuild -project Arcman.xcodeproj -scheme Arcman -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## ドキュメント

- [要件・設計](docs/design.md)
- [iPhone に入れる](docs/install.md)

フォントは IBM Plex Sans JP と IBM Plex Mono（SIL Open Font License、`Shared/Fonts/OFL.txt`）。
