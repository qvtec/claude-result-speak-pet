# claude-result-speak-cat

Claude Code の通知を右下に常駐するデスクトップペットが伝えてくれるプラグインです。

![demo](demo.png)

## 機能

- **デスクトップペット** — Claude が応答を完了すると右下にアニメーション猫が出現
- **吹き出し** — しっぽ付き吹き出しで通知メッセージを表示
- **フレームアニメーション** — 複数 PNG によるアニメーション内蔵
- **自動非表示** — 設定した秒数後に自動で消える
- **クリックで閉じる** — クリックするとすぐ消える
- **WSL2 対応** — PowerShell 経由で動作
- **Windows ネイティブ対応** — Git Bash / MSYS2 + PowerShell 経由で動作
- **macOS 対応** — AppKit（PyObjC）による透過フローティングウィンドウ、tkinter またはシステム通知にフォールバック

## インストール

```bash
claude plugin marketplace add https://github.com/qvtec/claude-result-speak-cat.git
claude plugin install claude-result-speak-cat@claude-result-speak-cat
```

必要あれば有効化：

```bash
# 全プロジェクトで使う場合（推奨）
claude plugin enable --scope user claude-result-speak-cat@claude-result-speak-cat

# 現在のプロジェクトのみ
claude plugin enable --scope project claude-result-speak-cat@claude-result-speak-cat
```

## カスタマイズ

`~/.claude/settings.json` に `env` ブロックを追加して設定します

設定例（ねこ語 + 表示時間 + claude-result-speak 併用）：

```json
{
  "env": {
    "CLAUDE_RESULT_SPEAK_CAT_LANGUAGE": "cat",
    "CLAUDE_RESULT_SPEAK_CAT_DISPLAY_SECONDS": "5",
    "CLAUDE_RESULT_SPEAK_NOTIFY_ENABLED": "false"
  }
}
```

| 環境変数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `CLAUDE_RESULT_SPEAK_CAT_LANGUAGE` | string | `en` | 通知メッセージの言語 (`ja` / `en` / `cat`) |
| `CLAUDE_RESULT_SPEAK_CAT_DISPLAY_SECONDS` | number | `5` | ペットの表示秒数 (2〜30) |
| `CLAUDE_RESULT_SPEAK_CAT_PET_SIZE` | number | `100` | 猫のサイズ（ピクセル、40〜200） |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_COMPLETE` | string | _(言語デフォルト)_ | 完了メッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_PERMISSION` | string | _(言語デフォルト)_ | 権限確認メッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_IDLE` | string | _(言語デフォルト)_ | 入力待ちメッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_NOTIFY_ENABLED` | boolean | `true` | [claude-result-speak](https://github.com/qvtec/claude-result-speak) 併用時はバルーン通知の重複を避けるため `false` に |

`LANGUAGE: cat` にすると日本語の猫語になります。

## 必要環境

| プラットフォーム | 必要なもの |
|----------------|-----------|
| WSL2 | `powershell.exe`（標準搭載） |
| Windows（ネイティブ） | Git Bash または MSYS2 + `powershell.exe`（標準搭載） |
| macOS | 下記参照 |

### macOS: PyObjC のインストール（推奨）

透過フローティングウィンドウで表示するには、システム Python に PyObjC を追加します：

```bash
/usr/bin/python3 -m pip install --user pyobjc-framework-Cocoa
```

> macOS 標準の `/usr/bin/python3` に `--user` でインストールするため、sudo 不要・Homebrew 不要です。  
> Homebrew 版 Python は非推奨 — システムライブラリを置き換えるため他のツールに影響が出る場合があります。

### macOS のフォールバック動作

| 環境 | 動作 |
|------|------|
| `/usr/bin/python3` + PyObjC インストール済み | 透過フローティングウィンドウ + アニメーション |
| PyObjC が無い | `osascript` でシステム通知 |

## セキュリティ・プライバシー

- **ネットワークアクセスなし** — 通知内容が外部に送信されることはありません
- **依存最小** — PyObjC（任意）は Apple 純正フレームワーク使用。tkinter フォールバックは追加インストール不要
- **ローカル完結** — 実行されるのはプラグイン内のスクリプトと OS 標準機能のみです

## ライセンス

MIT
