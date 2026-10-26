# HANDOFF — Hearthold

最終更新: 2026-10-26 20:04 JST(毎ターン更新して push する)

## 現在のタスク
- ユーザー指示「MVPとか関係なく全部実装して」で、SPEC 3章「後回し」の全項目を PLAN M7〜M11 として実装した(全項目完了)
- 残りはユーザーの手元でしかできない確認(最低環境の性能、マウス操作、Windows/macOS での起動)と、仮の値の調整
- 「作らない」(マルチプレイ・Mod・多言語・地下空間・直接操作キャラ・倍速・近世より後の技術)は対象外のまま

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

### M7〜M10(後回しだった機能)
- 仕組みを差し込む共通の形 `VillageSystem` と `SystemRegistry`(Village が毎ステップ・村人ごと・行動選択・手順・仕事・セーブで呼ぶ)
- M7: `Calendar`(季節4つ・天候・気温、冬の雪と雨の表示)、`ExtendedNeeds`(娯楽・人間関係・衛生・体温・安心、服の枠)、`Illness`(風邪・負傷)、`Traits`(個性と一言セリフ)、`Schedule`(日課表)、`FoodSpoilage`(腐る食料・燻製と塩漬け・食事の種類)、`Regrowth`(植林・木の広がり・ウサギの増減)、`Farming`(畑と家畜小屋)、`Festivals`(宴・祭り)、`LifeCycle`(年齢・出生・老衰・技の継承)
- M8: `EraSystem`(data/eras.json の節目で時代が進む)、鉱石(岩山)・`Mining`(炭鉱)・炭焼き・鍛冶、役職の解放(`Job.available`)、BUILDINGS.md の全建物、後回しの設備と職人の腕(熟練度で上位の設備)、`BuildingDamage`(壊れる建物と修理、ゴブリンが柵を壊す)、`BuildingEffects`(建物の効果・隣接ボーナス・村の象徴)、手押し車(運べる数)
- M9: 狼・盗賊・トロルと武器の相性、防具・罠・上位の武器・魔法の杖、`Nests`(魔物の巣)と `Expeditions`(視察隊)、`VillageClues`(他の村の手がかり)、`Magic`(魔素・魔術師・治癒/結界/遠見)
- M10: `Trade`(5つの外の村、定期便・取引所・提案・行商人、銀貨)、`Reputation`(評判)と双方向の審査(合格者を迎える/断る)、`Story`(8章の物語)、5つ目のパネル「交易・探索」

### M11(遊びやすさとマップ)
- `Achievements`(16個、ゲームをまたいで user://achievements.cfg に残る)、`Tutorial`(14手順、タイトルの「チュートリアルで始める」)
- `KeyBindings`(Esc メニュー →「キー割り当て」。カメラの WASD/QE も入力マップへ移した)
- マップの無限生成: `TerrainShape`(列ごとに地形を決める、順番によらない)、`WorldData` のチャンク(32×32列)、`WorldExpansion`(村人・魔物・視察隊のまわりを作る)、経路探索・霧・表示・セーブの対応。タイトルの「無限の地図」
- セーブ形式バージョン2(仕組みの状態 systems を保存、バージョン1も読める)
- 新しい建物・魔物・役職の .vox(tools/make_vox.py)、新しい警告の音の割り当て、README

## 自分で判断したこと(確認してほしい)
- 料理は作業台で作る(焚き火は BUILDINGS.md で「推奨」=未承認のため)
- 木は地形ブロックにせず列の印(world.trees)で持つ。建物も地形ブロックにせず、足元の列をふさぐ
- 狩りの仕事は、狩人の人数ぶんだけ近いウサギに自動で予約する(プレイヤーの「狩る」指示は SPEC にない)
- 建物の素材・作業時間、採点の出し方(data/scoring.json)、村の境界(建物の範囲+6、最低20)、衛兵の視界16 は仮の値
- 村レベルは0から。最初の課題(家1軒・倉庫1つ)で Lv1 になり見張り台が解放。AC-025 の課題は Lv2
- 最初の食料は料理40(4人で約5日分)。20だと狩人なしで5日目に全員倒れた
- フォントは BIZ UDPゴシック(OFL)。音とボクセル素材は自作で、作るスクリプトを `tools/` に置いた(SPEC 11章のディレクトリにない `tools/` を足した)
- 審査の「住居」は、新しい人の寝床が空いていないと0点。最初の4人(村長+3人)と新しい1人で寝床5つ=家3軒が要る
- (後回し機能)数値はすべて仮の値で data/*.json に置いた。主なもの: 1季節7日・1年28日、子どもは6倍の速さで育ち14歳で大人、風邪は48時間、腐るまで 肉3日/料理2日/燻製30日、時代の条件(data/eras.json)、交易の値段は品の値打ち×相手の倍率×評判
- 最初の物資を「料理40」から「燻製肉60」に変えた(料理は2日で傷むため)
- 交易のお金として「銀貨」を足した。塩は交易でだけ手に入る
- 5つ目のパネル「交易・探索」と、キーの5を足した(AC-008 の4パネルはそのまま)
- 無限の地図でも最初は 256×256 ぶんを作り、遠く(開始地点から140ブロック先)ではノイズで岩山と川が出る。座標の上限は ±65536
- 地形の木と鉱石の置き方を、乱数の順番からハッシュに変えた(地形の見た目が以前と少し変わる。同じシードなら毎回同じ)
- 食べ物の釣り合いを調整: 食事の減り 4→3/時、ウサギの肉 2→3、最初の燻製肉 60→80(7日のシミュレーションで、狩人1人で4人が生き残る)

## 次にやること(ユーザーの手元で)
1. **POC-001 / M6-T02**: 最低環境(第7世代Intel・内蔵GPU・Windows 11)で `scenes/bench/bench_30.tscn` と `scenes/bench/bench_game.tscn` を実行し、`user://logs/*.log` の平均/最低fps を見る。Forward+ と Compatibility の両方(UD-005 を決める)
2. **M6-T03**: `E2E_CHECKLIST.md` の「手での確認」を通す(マウス操作・ダイアログ・セーブ→タイトル→続きから)
3. **M6-T04**: Windows 版と macOS 版を起動して確かめる。macOS 用の Voxel Tools テンプレートはリリースに見当たらなかった
4. 気になった数値やバランスの調整、BUILDINGS.md の「推奨」の建物の承認

## 検証結果
- テスト: **189/189 passed**(全体 約385秒)。M6 時点: 118/118
- 性能(参考、コンテナ headless): 全機能入りの bench_game が 105fps(M6 時点 108fps)
- 書き出し: Linux 版を Xvfb で起動しタイトル画面を確認。Windows 版は書き出しのみ(`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`、Voxel Tools 1.7 ビルド、約159秒)
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
