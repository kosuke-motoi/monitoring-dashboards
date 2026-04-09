# =============================================================
# Cursor × Google Drive 連携 セットアップスクリプト（Windows）
# 使い方: PowerShellで以下を実行
#   irm https://raw.githubusercontent.com/kosuke-motoi/monitoring-dashboards/master/gdrive-setup/setup.ps1 | iex
# =============================================================

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

function Write-Step { param($msg) Write-Host "`n[$msg]" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  !! $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  NG: $msg" -ForegroundColor Red; exit 1 }

$GDRIVE_DIR = "$env:USERPROFILE\.gdrive-mcp"
$CURSOR_DIR  = "$env:USERPROFILE\.cursor"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Cursor x Google Drive セットアップ (Windows)" -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta

# ---------------------------------------------------
# STEP 1: Python チェック・インストール
# ---------------------------------------------------
Write-Step "STEP 1: Python の確認"
$refreshedPath = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
$env:PATH = $refreshedPath

$pythonOk = $false
try {
    $pyVer = & python --version 2>&1
    if ($pyVer -match "Python 3\.") {
        Write-OK "Python 検出: $pyVer"
        $pythonOk = $true
    }
} catch {}

if (-not $pythonOk) {
    Write-Warn "Python が見つかりません。winget でインストールします..."
    winget install Python.Python.3.13 --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    $pyVer = & python --version 2>&1
    Write-OK "Python インストール完了: $pyVer"
}

# ---------------------------------------------------
# STEP 2: Node.js チェック・インストール
# ---------------------------------------------------
Write-Step "STEP 2: Node.js の確認"
$nodeOk = $false
try {
    $nodeVer = & node --version 2>&1
    if ($nodeVer -match "v\d+") {
        Write-OK "Node.js 検出: $nodeVer"
        $nodeOk = $true
    }
} catch {}

if (-not $nodeOk) {
    Write-Warn "Node.js が見つかりません。winget でインストールします..."
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    Write-OK "Node.js インストール完了"
}

# ---------------------------------------------------
# STEP 3: フォルダ作成
# ---------------------------------------------------
Write-Step "STEP 3: フォルダ作成"
New-Item -ItemType Directory -Force -Path $GDRIVE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $CURSOR_DIR  | Out-Null
Write-OK "フォルダ作成: $GDRIVE_DIR"

# ---------------------------------------------------
# STEP 4: gcp-oauth.keys.json の確認
# ---------------------------------------------------
Write-Step "STEP 4: gcp-oauth.keys.json の確認"
$keysFile = "$GDRIVE_DIR\gcp-oauth.keys.json"

if (Test-Path $keysFile) {
    Write-OK "gcp-oauth.keys.json を検出しました"
} else {
    Write-Host ""
    Write-Host "  gcp-oauth.keys.json が見つかりません。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  以下のどちらかの方法で取得してください：" -ForegroundColor White
    Write-Host "  [方法A] チームメンバーからファイルをもらい、以下に配置：" -ForegroundColor White
    Write-Host "          $keysFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [方法B] 自分でGCPプロジェクトを作成する：" -ForegroundColor White
    Write-Host "    1. https://console.cloud.google.com/projectcreate を開く" -ForegroundColor Gray
    Write-Host "    2. プロジェクト名を入力、「場所」を「組織なし」に変更して作成" -ForegroundColor Gray
    Write-Host "    3. Drive / Sheets / Docs / Slides API を有効化" -ForegroundColor Gray
    Write-Host "    4. 「認証情報」→「OAuth クライアントID」→「デスクトップアプリ」で作成" -ForegroundColor Gray
    Write-Host "    5. JSONをダウンロードして gcp-oauth.keys.json にリネームし配置" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  詳細手順: https://github.com/kosuke-motoi/monitoring-dashboards/blob/master/gdrive-setup/setup-guide.md" -ForegroundColor Cyan
    Write-Host ""
    $ans = Read-Host "  ファイルを配置したら Enter を押してください（スキップは 's'）"
    if ($ans -eq "s") {
        Write-Warn "gcp-oauth.keys.json の配置をスキップしました。後でスクリプトを再実行してください。"
    } elseif (-not (Test-Path $keysFile)) {
        Write-Fail "gcp-oauth.keys.json が見つかりません。配置後に再実行してください。"
    }
}

# ---------------------------------------------------
# STEP 5: Python パッケージのインストール
# ---------------------------------------------------
Write-Step "STEP 5: Python パッケージのインストール"
& python -m pip install --quiet --user google-auth-oauthlib google-api-python-client mcp
Write-OK "パッケージインストール完了"

# ---------------------------------------------------
# STEP 6: MCP サーバースクリプトの生成
# ---------------------------------------------------
Write-Step "STEP 6: MCPサーバースクリプトの生成"
$serverScript = @'
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

from pathlib import Path
from mcp.server.fastmcp import FastMCP
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

HOME = Path.home()
GDRIVE_DIR = HOME / ".gdrive-mcp"
mcp = FastMCP("Google Workspace MCP")

def _creds(token_file, scopes):
    creds = Credentials.from_authorized_user_file(str(GDRIVE_DIR / token_file), scopes)
    if creds.expired and creds.refresh_token:
        creds.refresh(Request())
    return creds

def sheets(write=False):
    s = ["https://www.googleapis.com/auth/spreadsheets","https://www.googleapis.com/auth/drive.file"] if write else ["https://www.googleapis.com/auth/spreadsheets.readonly"]
    return build("sheets","v4",credentials=_creds("sheets-writer-token.json" if write else "sheets-reader-token.json", s))

def docs():
    return build("docs","v1",credentials=_creds("gdoc-writer-token.json",["https://www.googleapis.com/auth/drive.file","https://www.googleapis.com/auth/documents"]))

def slides(write=False):
    s = ["https://www.googleapis.com/auth/presentations","https://www.googleapis.com/auth/drive.file"] if write else ["https://www.googleapis.com/auth/presentations.readonly","https://www.googleapis.com/auth/drive.readonly"]
    return build("slides","v1",credentials=_creds("gslides-writer-token.json" if write else "gslides-token.json", s))

def drive():
    return build("drive","v3",credentials=_creds("gslides-token.json",["https://www.googleapis.com/auth/presentations.readonly","https://www.googleapis.com/auth/drive.readonly"]))

@mcp.tool()
def get_spreadsheet_info(spreadsheet_id: str) -> str:
    """スプレッドシートのタイトルとシート名一覧を取得する"""
    meta = sheets().spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
    title = meta.get("properties",{}).get("title","不明")
    names = [s["properties"]["title"] for s in meta.get("sheets",[])]
    return f"タイトル: {title}\nシート一覧: {', '.join(names)}"

@mcp.tool()
def read_spreadsheet(spreadsheet_id: str, range: str) -> str:
    """スプレッドシートの指定範囲を読み取る。rangeはシート名!A1:Z100形式"""
    result = sheets().spreadsheets().values().get(spreadsheetId=spreadsheet_id, range=range).execute()
    values = result.get("values",[])
    if not values: return "データが見つかりませんでした。"
    return "\n".join(["\t".join(row) for row in values])

@mcp.tool()
def write_spreadsheet(spreadsheet_id: str, range: str, values: list) -> str:
    """スプレッドシートの指定範囲にデータを書き込む。valuesは二次元配列"""
    result = sheets(write=True).spreadsheets().values().update(
        spreadsheetId=spreadsheet_id, range=range,
        valueInputOption="USER_ENTERED", body={"values": values}
    ).execute()
    return f"{result.get('updatedCells',0)} セルを更新しました。"

@mcp.tool()
def add_sheet(spreadsheet_id: str, sheet_title: str) -> str:
    """スプレッドシートに新しいシートタブを追加する"""
    result = sheets(write=True).spreadsheets().batchUpdate(
        spreadsheetId=spreadsheet_id,
        body={"requests":[{"addSheet":{"properties":{"title":sheet_title}}}]}
    ).execute()
    p = result["replies"][0]["addSheet"]["properties"]
    return f"シート '{p['title']}' を追加しました"

@mcp.tool()
def read_document(document_id: str) -> str:
    """Google Docsのドキュメントを読み取る"""
    doc = docs().documents().get(documentId=document_id).execute()
    title = doc.get("title","無題")
    content = []
    for elem in doc.get("body",{}).get("content",[]):
        para = elem.get("paragraph")
        if para:
            text = "".join(r.get("textRun",{}).get("content","") for r in para.get("elements",[]))
            if text.strip(): content.append(text.rstrip("\n"))
    return f"【{title}】\n\n" + "\n".join(content)

@mcp.tool()
def read_slides(presentation_id: str) -> str:
    """Google スライドのテキスト内容を読み取る"""
    pres = slides().presentations().get(presentationId=presentation_id).execute()
    title = pres.get("title","無題")
    output = [f"【{title}】"]
    for i, slide in enumerate(pres.get("slides",[]), 1):
        texts = []
        for elem in slide.get("pageElements",[]):
            for tr in elem.get("shape",{}).get("text",{}).get("textElements",[]):
                run = tr.get("textRun")
                if run and run.get("content","").strip():
                    texts.append(run["content"].strip())
        if texts: output.append(f"--- スライド {i} ---\n" + "\n".join(texts))
    return "\n\n".join(output)

@mcp.tool()
def list_drive_folder(folder_id: str) -> str:
    """Google Driveフォルダ内のファイル・フォルダ一覧を取得する"""
    query = f"'{folder_id}' in parents and trashed = false"
    results = drive().files().list(
        q=query, fields="files(id,name,mimeType)",
        orderBy="folder,name", pageSize=50,
        includeItemsFromAllDrives=True, supportsAllDrives=True
    ).execute()
    files = results.get("files",[])
    if not files: return "フォルダが空か、アクセス権がありません。"
    lines = []
    for f in files:
        icon = "Folder" if f["mimeType"] == "application/vnd.google-apps.folder" else "File"
        lines.append(f"[{icon}] {f['name']}  (id: {f['id']})")
    return f"合計 {len(files)} 件:\n" + "\n".join(lines)

@mcp.tool()
def get_drive_info(folder_id: str) -> str:
    """Google DriveフォルダまたはShared Driveの名称を取得する"""
    try:
        f = drive().files().get(fileId=folder_id, fields="id,name,mimeType", supportsAllDrives=True).execute()
        return f"名称: {f['name']}\n種類: {f['mimeType']}\nID: {f['id']}"
    except Exception as e:
        return f"取得できませんでした: {e}"

if __name__ == "__main__":
    mcp.run()
'@

$serverScript | Out-File -FilePath "$GDRIVE_DIR\server.py" -Encoding UTF8
Write-OK "MCPサーバースクリプト生成: $GDRIVE_DIR\server.py"

# ---------------------------------------------------
# STEP 7: 認証トークンの生成
# ---------------------------------------------------
Write-Step "STEP 7: Googleアカウント認証（ブラウザが5回開きます）"

if (-not (Test-Path $keysFile)) {
    Write-Warn "gcp-oauth.keys.json がないため認証をスキップします"
} else {
    $authScript = @'
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from google_auth_oauthlib.flow import InstalledAppFlow
from pathlib import Path

HOME = Path.home()
KEYS_PATH = HOME / ".gdrive-mcp/gcp-oauth.keys.json"

tokens = [
    {"name":"スプレッドシート読み取り","path":HOME/".gdrive-mcp/sheets-reader-token.json","scopes":["https://www.googleapis.com/auth/spreadsheets.readonly"]},
    {"name":"スプレッドシート書き込み","path":HOME/".gdrive-mcp/sheets-writer-token.json","scopes":["https://www.googleapis.com/auth/spreadsheets","https://www.googleapis.com/auth/drive.file"]},
    {"name":"Google Docs","path":HOME/".gdrive-mcp/gdoc-writer-token.json","scopes":["https://www.googleapis.com/auth/drive.file","https://www.googleapis.com/auth/documents"]},
    {"name":"Googleスライド読み取り","path":HOME/".gdrive-mcp/gslides-token.json","scopes":["https://www.googleapis.com/auth/presentations.readonly","https://www.googleapis.com/auth/drive.readonly"]},
    {"name":"Googleスライド書き込み","path":HOME/".gdrive-mcp/gslides-writer-token.json","scopes":["https://www.googleapis.com/auth/presentations","https://www.googleapis.com/auth/drive.file"]},
]

for t in tokens:
    if t["path"].exists():
        print(f"SKIP: {t['name']} (既存トークンあり)")
        continue
    print(f"\n--- {t['name']} の認証 ---")
    print("ブラウザで許可してください...")
    flow = InstalledAppFlow.from_client_secrets_file(str(KEYS_PATH), t["scopes"])
    creds = flow.run_local_server(port=0)
    t["path"].write_text(creds.to_json())
    print(f"DONE: {t['name']}")

print("\n=== 認証完了 ===")
for t in tokens:
    status = "OK" if t["path"].exists() else "NG"
    print(f"  [{status}] {t['path'].name}")
'@
    $authScript | Out-File -FilePath "$GDRIVE_DIR\auth.py" -Encoding UTF8
    Write-Host "  ブラウザが5回開きます。毎回「許可」を押してください..." -ForegroundColor Yellow
    & python "$GDRIVE_DIR\auth.py"
    Write-OK "認証完了"
}

# ---------------------------------------------------
# STEP 8: Cursor mcp.json の生成
# ---------------------------------------------------
Write-Step "STEP 8: Cursor mcp.json の設定"
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $pythonPath) {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
    $pythonPath = (Get-Command python).Source
}
$serverPath = "$GDRIVE_DIR\server.py"

$mcpJson = @"
{
  "mcpServers": {
    "google-workspace": {
      "command": "$($pythonPath -replace '\\', '\\\\')",
      "args": ["$($serverPath -replace '\\', '\\\\')"],
      "env": {
        "PYTHONUTF8": "1"
      }
    }
  }
}
"@

$mcpJsonPath = "$CURSOR_DIR\mcp.json"
$mcpJson | Out-File -FilePath $mcpJsonPath -Encoding UTF8
Write-OK "mcp.json 生成: $mcpJsonPath"

# ---------------------------------------------------
# 完了
# ---------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  セットアップ完了！" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  次のステップ：" -ForegroundColor White
Write-Host "  1. Cursor を完全に再起動してください" -ForegroundColor White
Write-Host "  2. チャットで以下のように話しかけてみてください：" -ForegroundColor White
Write-Host "     「このスプレッドシートを読んで：https://docs.google.com/spreadsheets/d/...」" -ForegroundColor Gray
Write-Host ""
