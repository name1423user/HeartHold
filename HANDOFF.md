# HANDOFF — Hearthold

最終更新: 2026-10-26 18:48 JST(毎ターン更新して push する)

## 現在のタスク
- M1〜M6 の全43タスクを、このコンテナでできるところまで実装した(ユーザー指示「全部できるところまで」)
- 残りは **ユーザーの手元でしかできない確認**(最低環境での性能、手での操作、Windows/macOS での起動)

## 終わったこと
### M1(PoC)
- Voxel Tools 1.7 の Linux エディタビルドを取得し、headless で動くことを確認(VoxelTerrain / VoxelBlockSerializer / VoxelAStarGrid3D)
- `TerrainGenerator` / `WorldData` / `WorldView`、`TerrainEditor`(4段まで)、`Pathing`(AStar2D)、`bench_30.tscn`、`SavePrototype`

### M2(中核)
- `CameraRig`、`Village`(村全体のシミュレーション。村人は plan=手順の列をこなす)、`Villager`、`Needs`、`GameClock`
- `Designation`、`Job`、`DirectOrder`、`Crafting`、建設、`Wildlife`(ウサギ)、`Equipment`、`Proficiency`、`Stockpile`、`BuildingFixture`

### M3(審査・襲撃と村長・霧)
- `Inspection` / `Applicant` / `ScoreCard`、`RaidDirector` / `Monster` / `Combat`、`HealthState`、`Chief`、`Fog`、`Watchtower`、`Ruins`

### M4(画面)
- プレイ画面 `scenes/game.tscn`(`Game`)、タイトル `scenes/ui/title.tscn`(起動時)、一時停止メニュー `scenes/ui/pause_menu.tscn`
- `Hud`(上部バー・警告マーク・サイドバー4パネル・審査結果・ヒント・建物の説明)、`AlertLog`、`VillageLevel`、`Hints`、`SpeechBubble`、`FoodStock`
- 入力: スペース=一時停止、1〜4=パネル、Esc=メニュー、左ドラッグ=範囲指示、右クリック=解除

### M5(セーブ・ロード)
- `SaveGame`(user://saves、形式バージョン1、一時ファイル経由、地形は SHA-256 で検査、壊れていたら読まずに「このセーブは読み込めません」)
- `Autosave`(実時間5分、auto_1〜3、失敗したら警告して前のセーブを残す)、タイトルでセーブ削除(確認あり)

### M6(仕上げ)
- M6-T01 自作ボクセル素材 `assets/voxel/*.vox`(`tools/make_vox.py` で生成、Voxel Tools の取り込みで縮尺0.1)。木は幹と葉の形。`CREDITS.md`
- M6-T05 音 `assets/audio/*.wav`(`tools/make_audio.py` で合成した自作)。警告の種類ごとの音、伐採・採掘・建設完了、昼夜の BGM、全体・BGM・効果音の音量
- M6-T02 計測シーン `scenes/bench/bench_game.tscn`(本番の画面で村人30人+魔物10体)。**最低環境での実測は未実施**
- M6-T03 通し確認: `tests/test_e2e.gd`(完成条件1〜3)と `E2E_CHECKLIST.md`。手での確認は未
- M6-T04 `export_presets.cfg`(Windows / Linux / macOS)、README(遊び方・動作環境・リリース手順)、CONTRIBUTING.md、SECURITY.md、`tools/release_checksums.sh`

## 自分で判断したこと(確認してほしい)
- 料理は作業台で作る(焚き火は BUILDINGS.md で「推奨」=未承認のため)
- 木は地形ブロックにせず列の印(world.trees)で持つ。建物も地形ブロックにせず、足元の列をふさぐ
- 狩りの仕事は、狩人の人数ぶんだけ近いウサギに自動で予約する(プレイヤーの「狩る」指示は SPEC にない)
- 建物の素材・作業時間、採点の出し方(data/scoring.json)、村の境界(建物の範囲+6、最低20)、衛兵の視界16 は仮の値
- 村レベルは0から。最初の課題(家1軒・倉庫1つ)で Lv1 になり見張り台が解放。AC-025 の課題は Lv2
- 最初の食料は料理40(4人で約5日分)。20だと狩人なしで5日目に全員倒れた
- フォントは BIZ UDPゴシック(OFL)。音とボクセル素材は自作で、作るスクリプトを `tools/` に置いた(SPEC 11章のディレクトリにない `tools/` を足した)
- 審査の「住居」は、新しい人の寝床が空いていないと0点。最初の4人(村長+3人)と新しい1人で寝床5つ=家3軒が要る

## 次にやること(ユーザーの手元で)
1. **POC-001 / M6-T02**: 最低環境(第7世代Intel・内蔵GPU・Windows 11)で `scenes/bench/bench_30.tscn` と `scenes/bench/bench_game.tscn` を実行し、`user://logs/*.log` の平均/最低fps を見る。Forward+ と Compatibility の両方(UD-005 を決める)
2. **M6-T03**: `E2E_CHECKLIST.md` の「手での確認」を通す(マウス操作・ダイアログ・セーブ→タイトル→続きから)
3. **M6-T04**: Windows 版と macOS 版を起動して確かめる。macOS 用の Voxel Tools テンプレートはリリースに見当たらなかった
4. 気になった数値やバランスの調整、BUILDINGS.md の「推奨」の建物の承認

## 検証結果
- テスト: **118/118 passed**(`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`、Voxel Tools 1.7 ビルド、約159秒)
- POC-002: 1000ブロック変更+30人で一致、ロード 0.5〜0.7秒(コンテナ)
- 性能(コンテナ、参考): headless(描画なし)で bench_30 が 145fps、bench_game が 108fps。Xvfb+ソフトウェア描画ではどちらも 7.5fps。**最低環境では未計測**
- 書き出し: Linux 版を Xvfb で起動し、タイトル画面と日本語フォントを確認。Windows 版は書き出しのみ(起動は未確認)
- 画面: Xvfb のスクリーンショットで、地形・霧・ボクセル素材・HUD・サイドバーを目で確認

## 未解決・ユーザーへの質問
- 上の「次にやること」1〜3 はこのコンテナではできない(GPU・マウス・Windows/macOS がない)
- 欲求の値を JSON に保存すると最下位の桁がずれる(1e-9 未満)。テストは 1e-9 の許容で比較
- FIRST_PROMPT.md は当時の指示として 4.6/1.6 表記のまま
- BUILDINGS.md の「推奨」ラベルの建物(焚き火・狩猟小屋など)の承認

## 触ったファイル
- data/*.json(33ファイル)、scripts/ 以下すべて、scenes/(game, world, bench, ui)、tests/*.gd
- assets/(fonts, voxel, audio)、tools/(make_vox.py, make_audio.py, release_checksums.sh)
- project.godot, export_presets.cfg, .gitignore, README.md, CONTRIBUTING.md, SECURITY.md, CREDITS.md, E2E_CHECKLIST.md, HANDOFF.md

## サブエージェントの利用
- なし
