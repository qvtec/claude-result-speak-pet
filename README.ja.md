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
- **macOS 対応** — Python 3 + tkinter で動作、追加パッケージ不要

## 必要環境

| プラットフォーム | 必要なもの |
|----------------|-----------|
| WSL2 | `powershell.exe`（標準搭載） |
| macOS | Python 3（標準搭載）; フル画像表示には Homebrew / python.org 版 Python 推奨 |

### macOS のフォールバック動作

| Python / Tk のバージョン | 動作 |
|--------------------------|------|
| Tk 8.6+（Homebrew / python.org 版） | 猫画像 + アニメーション表示 |
| Tk 8.5（Xcode CLT 標準） | 🐱 絵文字で代替 |
| `python3` がない | `osascript` でシステム通知 |

いずれの場合も `pip install` は不要です。

## インストール

```bash
claude plugin marketplace add https://github.com/qvtec/claude-result-speak-cat.git
claude plugin install claude-result-speak-cat@claude-result-speak-cat
```

次に有効化します：

```bash
# 全プロジェクトで使う場合（推奨）
claude plugin enable --scope user claude-result-speak-cat@claude-result-speak-cat

# 現在のプロジェクトのみ
claude plugin enable --scope project claude-result-speak-cat@claude-result-speak-cat
```

## カスタマイズ

`~/.claude/settings.json` に `env` ブロックを追加して設定します

設定例（日本語 + 表示時間カスタマイズ + claude-result-speak 併用）：

```json
{
  "env": {
    "CLAUDE_RESULT_SPEAK_CAT_LANGUAGE": "ja",
    "CLAUDE_RESULT_SPEAK_CAT_DISPLAY_SECONDS": "8",
    "CLAUDE_RESULT_SPEAK_NOTIFY_ENABLED": "false"
  }
}
```

| 環境変数 | 型 | デフォルト | 説明 |
|------|----|-----------|------|
| `CLAUDE_RESULT_SPEAK_CAT_LANGUAGE` | string | `en` | 通知メッセージの言語 (`ja` / `en` / `cat`) |
| `CLAUDE_RESULT_SPEAK_CAT_DISPLAY_SECONDS` | number | `5` | ペットの表示秒数 (2〜30) |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_COMPLETE` | string | _(言語デフォルト)_ | 完了メッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_PERMISSION` | string | _(言語デフォルト)_ | 権限確認メッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_CAT_MESSAGE_IDLE` | string | _(言語デフォルト)_ | 入力待ちメッセージのカスタマイズ |
| `CLAUDE_RESULT_SPEAK_NOTIFY_ENABLED` | boolean | `true` | [claude-result-speak](https://github.com/qvtec/claude-result-speak) 併用時はバルーン通知の重複を避けるため `false` に |

`LANGUAGE: cat` にすると日本語の猫語になります。

## セキュリティ・プライバシー

- **ネットワークアクセスなし** — 通知内容が外部に送信されることはありません
- **外部パッケージなし** — サードパーティライブラリへの依存がないため、サプライチェーンリスクがありません
- **ローカル完結** — 実行されるのはプラグイン内のスクリプトと OS 標準機能のみです

## ライセンス

MIT
