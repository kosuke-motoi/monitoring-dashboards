# Cursor × Google Drive 連携セットアップガイド

CursorのAIチャットから、Google スプレッドシート・Docs・スライド・Driveフォルダを直接読み書きできるようにする手順です。

---

## 所要時間
- JSONファイルをもらえる場合：約15分
- GCPプロジェクトを自分で作る場合：約30分

---

## 自動セットアップ（推奨）

OSに応じたスクリプトをコピペしてターミナルで実行するだけです。

### Windows（PowerShell）
```powershell
irm https://raw.githubusercontent.com/kosuke-motoi/monitoring-dashboards/master/gdrive-setup/setup.ps1 | iex
```

### Mac / Linux（ターミナル）
```bash
curl -sSL https://raw.githubusercontent.com/kosuke-motoi/monitoring-dashboards/master/gdrive-setup/setup.sh | bash
```

スクリプトが以下をすべて自動処理します：
1. Python / Node.js のインストール確認
2. 必要パッケージのインストール
3. フォルダ作成
4. MCPサーバースクリプトの生成
5. Cursor設定ファイル（mcp.json）の生成

**スクリプト実行後、ブラウザが5回開きます。毎回Googleアカウントでログインして「許可」を押してください。**

---

## GCPプロジェクトと gcp-oauth.keys.json の取得

スクリプト実行前に `gcp-oauth.keys.json` が必要です。

### ルートA：チームメンバーからファイルをもらう（最短）

チームに既にセットアップ済みの人がいる場合、`gcp-oauth.keys.json` を受け取り、以下に配置します：

- **Windows**: `C:\Users\あなたのユーザー名\.gdrive-mcp\gcp-oauth.keys.json`
- **Mac**: `~/.gdrive-mcp/gcp-oauth.keys.json`

その後、セットアップスクリプトを実行してください。

---

### ルートB：自分でGCPプロジェクトを作る

#### 1. Google Cloud Console でプロジェクト作成

1. [https://console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate) を開く
2. プロジェクト名：`mcp-drive-server`（任意）
3. **「場所」を「組織なし」に変更**（重要：会社アカウントの場合、デフォルトでは組織配下になり権限エラーになります）
4. 「作成」をクリック

> **会社アカウントで「組織なし」が選べない場合：**
> 個人のGmailアカウントで作成するか、IT管理者にプロジェクト作成権限を申請してください。

#### 2. Google Drive / Sheets / Docs / Slides API を有効化

プロジェクト作成後、以下のAPIをすべて有効化します：

1. [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com) → 「有効にする」
2. [Google Sheets API](https://console.cloud.google.com/apis/library/sheets.googleapis.com) → 「有効にする」
3. [Google Docs API](https://console.cloud.google.com/apis/library/docs.googleapis.com) → 「有効にする」
4. [Google Slides API](https://console.cloud.google.com/apis/library/slides.googleapis.com) → 「有効にする」

#### 3. OAuth同意画面の設定

1. [APIとサービス → OAuth同意画面](https://console.cloud.google.com/apis/credentials/consent) を開く
2. ユーザーの種類：「外部」を選択 → 「作成」
3. アプリ名：`MCP Drive Server`、サポートメール：自分のアドレス → 「保存して次へ」
4. スコープ：何も追加せず「保存して次へ」
5. テストユーザー：自分のGoogleアカウントのメールアドレスを追加 → 「保存して次へ」
6. 「ダッシュボードに戻る」

#### 4. OAuth クライアントID（JSONファイル）を作成

1. [APIとサービス → 認証情報](https://console.cloud.google.com/apis/credentials) を開く
2. 「認証情報を作成」→「OAuth クライアントID」
3. アプリケーションの種類：**「デスクトップアプリ」**
4. 名前：`MCP Drive Server` → 「作成」
5. 表示されたダイアログで「**JSONをダウンロード**」
6. ダウンロードしたファイルを `gcp-oauth.keys.json` にリネームして配置：
   - **Windows**: `C:\Users\あなたのユーザー名\.gdrive-mcp\gcp-oauth.keys.json`
   - **Mac**: `~/.gdrive-mcp/gcp-oauth.keys.json`

その後、セットアップスクリプトを実行してください。

---

## セットアップ後の使い方

Cursorを再起動後、チャットで以下のように話しかけるだけです：

```
このスプレッドシートを読んで分析して：
https://docs.google.com/spreadsheets/d/XXXXXX/edit

このDriveフォルダの中身を見せて：
https://drive.google.com/drive/folders/XXXXXX

このGoogle Docsの内容を要約して：
https://docs.google.com/document/d/XXXXXX/edit
```

---

## できること一覧

| 機能 | 説明 |
|---|---|
| スプレッドシート読み取り | 任意のシート・範囲を読み込んで分析 |
| スプレッドシート書き込み | AIの出力結果をシートに直接書き込み |
| シート追加 | 新しいシートタブを作成 |
| Google Docs読み取り | ドキュメントのテキストを読み込み |
| Google スライド読み取り | プレゼンのテキストを読み込み |
| Driveフォルダ一覧 | フォルダ内のファイル・フォルダ一覧を取得 |

---

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| `gcp-oauth.keys.json が見つかりません` | ファイルの配置パスを確認 |
| ブラウザが開かない | ターミナルに表示されるURLを手動でブラウザに貼り付け |
| `Access denied` | スプシ・DocsがあなたのGoogleアカウントと共有されているか確認 |
| `invalid_scope` | GCPプロジェクトでAPIが有効化されているか確認 |
| Cursorでツールが使えない | Cursorを完全に再起動（タスクトレイから終了して再起動） |
| トークン期限切れ | セットアップスクリプトを再実行（既存トークンはスキップされます） |
