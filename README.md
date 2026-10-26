# Hearthold

ボクセルの土地で村を育てるコロニーシム。村人に役職と仕事を割り振り、魔物の襲撃をしのぎ、移住希望者の審査に通る村をつくります。
仕様は SPEC.md、実装の順序は PLAN.md。

## 遊び方
- タイトルで「新しく始める」(シードを入れると同じ土地になります)
- 左のアクティビティバー(村 / 指 / 建 / 状)でサイドバーを開閉。キーボードの 1〜4 でも切り替え
- 「指」→「伐る」「掘る」を選んで、地面をドラッグで囲むと予約。右クリックで解除
- 「建」から建物を選んで地面をクリック。加工(木材・道具・武器・料理)もここから
- 村人をクリックして「移動命令」→ 行き先をクリック
- スペースで一時停止(止めている間も指示は出せます)。Esc でメニュー(セーブ・ロード・文字サイズ・音量)
- カメラ: 右ドラッグか Q/E で回転、ホイールでズーム、WASD か中ドラッグで移動
- 移住希望者はゲーム内5〜7日ごとに来ます。食料・住居・安全・施設・満足度で採点され、60点以上で合格
- 最初の5日間は襲撃が来ません。衛兵に槍か投石紐を持たせ、救護室を建てておきましょう

## 動作環境
- Windows 11 / macOS のデスクトップ。マウスとキーボード
- 目標: 第7世代 Intel・内蔵GPU・メモリ16GB で、村人30人+魔物10体の場面が平均30fps(未計測。HANDOFF.md 参照)

## 使っているバージョン(2026-10-26 確認)

| 名前 | バージョン | 出典 |
|---|---|---|
| Godot | 4.7.2-stable | https://github.com/godotengine/godot/releases/tag/4.7.2-stable |
| Voxel Tools | 1.7(Godot 4.7.2 向け。カスタムビルドのエディタを使う) | https://github.com/Zylann/godot_voxel/releases/tag/v1.7 |
| GUT | 9.7.1(Godot 4.7 向け、`addons/gut/`、MIT) | https://github.com/bitwes/Gut/releases/tag/v9.7.1 |

## 開発
- エディタ: Voxel Tools 1.7 入りの Godot(リリースの `godot.<OS>.editor.*.zip`)。通常の Godot では開けません
- テスト: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- 性能ベンチ: `scenes/bench/bench_30.tscn`(POC-001)、`scenes/bench/bench_game.tscn`(本番の画面で村人30人+魔物10体)。結果は `user://logs/` に追記
- ゲームデータは `data/*.json`、表示文言は `data/texts.json`
- 素材の作り直し: `python3 tools/make_vox.py`(ボクセル)、`python3 tools/make_audio.py`(音)

## リリースの作り方
1. Voxel Tools 1.7 のリリースから書き出しテンプレートを取得し、`export_templates/` に置く
   - Windows: `godot.windows.template_release.x86_64.exe.zip` を展開
   - macOS: Voxel Tools の macOS テンプレート(`macos.zip`)を置く(リリースにない場合は GitHub Actions の成果物から)
2. `godot --headless --export-release "Windows Desktop" build/windows/Hearthold.exe`(macOS は `"macOS"`)
3. `tools/release_checksums.sh` で `build/SHA256SUMS.txt` を作り、GitHub Releases のノートに貼る
4. 両 OS で起動を確かめてから公開する

## ライセンス
本体は MIT(LICENSE)。使っているもののライセンスは CREDITS.md。
