# Google Workspace 認証セットアップガイド

CursorからGoogle スプレッドシート・Docs・スライドにアクセスするための設定手順。
**このファイルをCursorのチャットに貼り付けて「この手順でセットアップして」と伝えてください。**

---

## 前提条件

- Cursorがインストール済み
- Pythonが使える状態（`python3 --version` で確認）
- Google Workspaceのアカウントがある

## Step 1: 必要パッケージのインストール

```bash
pip3 install --user google-auth-oauthlib google-api-python-client markdown
```

## Step 2: OAuthキーファイルの配置

GCPプロジェクトのOAuthクライアントIDのJSONファイルが必要です。
以下のいずれかの方法で取得してください。

### 方法A: 既存のキーファイルをコピー（チーム内に既にある場合）

```bash
mkdir -p ~/.gdrive-mcp
# 既存メンバーから gcp-oauth.keys.json を受け取り、以下に配置
# ~/.gdrive-mcp/gcp-oauth.keys.json
```

### 方法B: 自分で作成する場合

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクトを選択（or 新規作成）
3. 「APIとサービス」→「認証情報」→「認証情報を作成」→「OAuthクライアントID」
4. アプリケーションの種類: 「デスクトップアプリ」
5. 作成後、JSONをダウンロード
6. ダウンロードしたファイルを `~/.gdrive-mcp/gcp-oauth.keys.json` にリネーム・配置

## Step 3: 認証トークンの生成

以下のPythonスクリプトを実行してください。ブラウザが開くので、Googleアカウントでログインして「許可」を押します。
**5つのスコープ分、順番に認証画面が出ます。すべて許可してください。**

```python
import json
from google_auth_oauthlib.flow import InstalledAppFlow
from pathlib import Path

HOME = Path.home()
KEYS_PATH = HOME / ".gdrive-mcp/gcp-oauth.keys.json"

if not KEYS_PATH.exists():
    print(f"エラー: {KEYS_PATH} が見つかりません。Step 2を先に完了してください。")
    exit(1)

tokens = [
    {
        "name": "スプレッドシート読み取り",
        "path": HOME / ".gdrive-mcp/sheets-reader-token.json",
        "scopes": ["https://www.googleapis.com/auth/spreadsheets.readonly"],
    },
    {
        "name": "スプレッドシート書き込み",
        "path": HOME / ".gdrive-mcp/sheets-writer-token.json",
        "scopes": ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive.file"],
    },
    {
        "name": "Google Docs 作成・編集",
        "path": HOME / ".gdrive-mcp/gdoc-writer-token.json",
        "scopes": ["https://www.googleapis.com/auth/drive.file", "https://www.googleapis.com/auth/documents"],
    },
    {
        "name": "Google スライド読み取り",
        "path": HOME / ".gdrive-mcp/gslides-token.json",
        "scopes": ["https://www.googleapis.com/auth/presentations.readonly", "https://www.googleapis.com/auth/drive.readonly"],
    },
    {
        "name": "Google スライド書き込み",
        "path": HOME / ".gdrive-mcp/gslides-writer-token.json",
        "scopes": ["https://www.googleapis.com/auth/presentations", "https://www.googleapis.com/auth/drive.file"],
    },
]

for t in tokens:
    if t["path"].exists():
        print(f"✓ {t['name']}: 既にトークンあり（スキップ）")
        continue
    print(f"\n--- {t['name']} の認証 ---")
    print("ブラウザで許可してください...")
    flow = InstalledAppFlow.from_client_secrets_file(str(KEYS_PATH), t["scopes"])
    creds = flow.run_local_server(port=0)
    with open(t["path"], "w") as f:
        f.write(creds.to_json())
    print(f"✓ {t['name']}: トークン保存完了 → {t['path']}")

print("\n=== 全認証完了 ===")
print("以下のトークンが生成されました:")
for t in tokens:
    exists = "✓" if t["path"].exists() else "✗"
    print(f"  {exists} {t['path'].name} ({t['name']})")
```

## Step 4: 動作確認

```python
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from pathlib import Path

TOKEN_PATH = Path.home() / '.gdrive-mcp/sheets-reader-token.json'
creds = Credentials.from_authorized_user_file(str(TOKEN_PATH), ['https://www.googleapis.com/auth/spreadsheets.readonly'])
if creds.expired:
    creds.refresh(Request())
sheets = build('sheets', 'v4', credentials=creds)

# テスト: 任意のスプシにアクセス
result = sheets.spreadsheets().values().get(
    spreadsheetId='1KnMzyAsAox5AtKVFHOJ6zZWEOeT2RmGnuX3aLDftAG4',
    range="'Monitoringサマリ'!A1:C3"
).execute()
print("接続成功！")
for row in result.get('values', []):
    print(row)
```

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `gcp-oauth.keys.json` が見つからない | Step 2を確認。ファイルパスが `~/.gdrive-mcp/gcp-oauth.keys.json` にあるか |
| ブラウザが開かない | ターミナルに表示されるURLを手動でブラウザに貼り付け |
| `invalid_scope` エラー | GCPプロジェクトでGoogle Sheets API / Docs API / Slides API を有効化する |
| `Access denied` | スプシ/Docsの共有設定を確認。自分のアカウントにアクセス権があるか |
| トークンの期限切れ | `creds.refresh(Request())` で自動更新される。失敗する場合はStep 3を再実行 |

## 生成されるファイル一覧

```
~/.gdrive-mcp/
├── gcp-oauth.keys.json          ← OAuthキー（手動配置）
├── sheets-reader-token.json     ← スプシ読み取り
├── sheets-writer-token.json     ← スプシ書き込み
├── gdoc-writer-token.json       ← Docs作成・編集
├── gslides-token.json           ← スライド読み取り
└── gslides-writer-token.json    ← スライド書き込み
```
