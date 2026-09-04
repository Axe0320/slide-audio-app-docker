# Slide Audio App

プレゼン原稿テキストを、スライド（見出し）ごとの音声ファイル（MP3/WAV）に一括変換するローカルWebアプリ。iTunes等での再生順を保つためのトラック番号付きID3タグ埋め込みにも対応しています。

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)](https://www.python.org)
[![Flask](https://img.shields.io/badge/Flask-3.0-000000?style=flat-square&logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![edge-tts](https://img.shields.io/badge/edge--tts-Neural_TTS-0078D4?style=flat-square&logo=microsoftedge&logoColor=white)](https://github.com/rany2/edge-tts)
[![FFmpeg](https://img.shields.io/badge/FFmpeg-Audio_Processing-007808?style=flat-square&logo=ffmpeg&logoColor=white)](https://ffmpeg.org)
[![JavaScript](https://img.shields.io/badge/JavaScript-Vanilla-F7DF1E?style=flat-square&logo=javascript&logoColor=black)](https://developer.mozilla.org/docs/Web/JavaScript)
[![Docker](https://img.shields.io/badge/Docker-Desktop-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/products/docker-desktop/)

---

## 必要環境

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- インターネット接続（edge-ttsがMicrosoftの音声サービスへ接続するため）

Docker版では `edge-tts` のみ利用できます。Windows標準のSAPI音声とWindowsのフォルダ選択ダイアログは利用できません。

## 使い方

1. Dockerイメージをビルドして起動します。
    ```powershell
    docker compose build
    docker compose up
    ```
2. ブラウザで `http://localhost:5678/` を開きます。
3. 原稿ファイルをドラッグ＆ドロップ、またはテキストを貼り付け
4. 見出しキーワード（`Slide` / `スライド` / `Chapter` など）を選び、「見出しを検出する」を押す
    - 続けて別の文章を追加したい場合は「既存のリストに追加する」で末尾に追記できます
    - 見出しが1つも見つからない場合は、空行区切りの段落ごとに自動でスライド化されます
5. 検出結果のタイトル・本文・トラック番号を確認・編集（チェックを外すとそのスライドは生成対象から外れます）
6. アルバム名・アーティスト名・言語・音声・速度・ピッチ・音量・文/段落間のポーズ・出力形式を設定
    - 「🔊 この設定で試聴する」で生成前に音声（速度・ピッチ・音量）を確認できます
7. 「音声を生成する」を押すと、スライドごとに音声ファイルが生成されます（「■ 停止」でいつでも中断可能）
8. 個別ダウンロード、または「全てZIPでダウンロード」で一括取得

生成ファイルはホスト側の `output/` に保存されます。画面の保存先選択から既存のサブフォルダを選べます。新しいフォルダを選んだ場合は名前を入力すると自動作成されます。停止する場合は次を実行します。

保存先をプロジェクト外へ変更する場合は、`.env` に次のように記述します。`.env` は個人環境用の設定なのでGitには登録しません。

```dotenv
SLIDE_AUDIO_OUTPUT_DIR=C:/Users/ユーザー名/Desktop/slide-audio
```

設定を変更した場合は、`start.bat` または `docker compose up -d --build` でコンテナを再作成してください。

```powershell
docker compose down
```

## 見出し検出のルール

以下のパターンにマッチする行を新しいスライドの開始として扱います（キーワード部分は画面から変更可能）。

```
<キーワード> <番号>: <タイトル>
```

例: `Slide 3: Introduction` / `スライド3：はじめに` / `Chapter 3: Introduction`

見出しが検出されない場合は、空行区切りの段落ごとに「テキスト01」「テキスト02」…として自動分割されます。

## 音声設定について

| 項目              | 内容                                                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| エンジン          | `edge-tts`（Microsoftのクラウドニューラル音声、高音質・要ネット接続）                                                 |
| 言語・性別        | 日本語/Englishと男性/女性/すべてで音声を絞り込み                                                                      |
| 速度・ピッチ      | スライダーで調整                                                                                                      |
| 音量              | -20dB〜+20dBの範囲でスライダー調整。MP3出力時に適用（試聴でも反映）。iTunesでスマホ再生する場合は +3〜+6dB 程度が目安 |
| 文/段落間のポーズ | 文単位でTTSを分割生成し、指定秒数の無音を挟んで結合（0秒なら従来通り一括生成）                                        |

## トラック番号・アルバム名・アーティスト名について

MP3出力時は `title` / `track`（n/総数） / `album` / `artist` のID3タグを自動で埋め込みます。トラック番号はチェックボックスで一部のスライドだけ生成した場合でも、原稿全体の位置を基準に正しく付与されます（原稿を一部修正して該当ファイルだけ差し替える運用に対応）。トラック番号・総数は各スライドごとに手動上書きも可能です。アーティスト名は省略可能です。

---

## システム構成

```mermaid
flowchart LR
    classDef fe fill:#dbeafe,stroke:#3b82f6,color:#1e3a8a
    classDef be fill:#fef3c7,stroke:#f59e0b,color:#78350f
    classDef ext fill:#f3e8ff,stroke:#a855f7,color:#4c1d95

    subgraph FE["ブラウザ（Vanilla JS）"]
        UI[script.js\n入力・設定・進捗表示]
    end

    subgraph BE["Flaskサーバー（server.py）"]
        PARSE["/api/parse\n見出し検出・段落分割"]
        GEN["/api/generate\nジョブ実行（別スレッド）"]
        PREV["/api/preview\n試聴用の単発生成"]
        STATUS["/api/status /api/cancel"]
    end

    subgraph EXT["外部プロセス"]
        EDGE[edge-tts\nMicrosoftクラウド]
        FFMPEG[ffmpeg\nポーズ結合・MP3変換・ID3タグ]
    end

    class UI fe
    class PARSE,GEN,PREV,STATUS be
    class EDGE,FFMPEG ext

    UI -->|原稿テキスト| PARSE
    PARSE -->|スライド一覧| UI
    UI -->|生成設定| GEN
    UI <-->|ポーリング| STATUS
    UI -->|設定変更時| PREV
    GEN --> EDGE
    EDGE --> FFMPEG
    FFMPEG -->|完成ファイル| UI
```

## 生成フロー

```mermaid
flowchart TD
    classDef step fill:#dcfce7,stroke:#22c55e,color:#14532d
    classDef dec fill:#e0f2fe,stroke:#0ea5e9,color:#0c4a6e

    A([スライド一覧を送信]) --> B{選択済みのみ処理}
    B --> C{ポーズ設定あり？}
    C -->|いいえ| D[本文全体を1回でTTS生成]
    C -->|はい| E[文/段落に分割し\n個別にTTS生成]
    E --> F["無音を挟んでffmpegで結合\n（音量フィルター適用）"]
    D --> G{出力形式}
    F --> G
    G -->|MP3| H["ID3タグ付与\ntitle/track/album/artist\n音量調整（ポーズなし時）"]
    G -->|WAV| I[そのまま保存]
    H --> J([ファイル完成])
    I --> J

    class A,D,E,F,H,I step
    class B,C,G dec
```

## ディレクトリ構成

```
slide_audio_app/
├── start.bat            ← ダブルクリックでDocker Composeを起動
├── Dockerfile            ← Pythonとffmpegを含むイメージ定義
├── compose.yaml          ← ポートと出力先volumeの定義
├── .dockerignore         ← Dockerビルドから除外するファイル
├── server.py            ← Flaskサーバー本体（TTS・ffmpeg・ジョブ管理）
├── requirements.txt     ← Python依存パッケージ
├── .gitignore
├── templates/
│   └── index.html       ← 画面のHTML
├── static/
│   ├── style.css        ← スタイル
│   └── script.js        ← 画面のロジック（fetch・進捗ポーリング等）
└── output/              ← 生成された音声の保存先（デフォルト。Git管理外）
```
