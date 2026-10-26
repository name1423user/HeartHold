# HANDOFF — Hearthold

最終更新: 2026-10-26 18:17 JST(毎ターン更新して push する)

## 現在のタスク
- M3(審査・襲撃と村長・霧)のロジック完了。次は M4-T01 から(ユーザー指示「全部できるところまで」)

## 終わったこと
### M1(PoC)
- Voxel Tools 1.7 の Linux エディタビルド(`godot.linuxbsd.editor.x86_64.zip`、SHA-256 35c92e9f…dea)を取得し、headless で VoxelTerrain / VoxelBlockSerializer / VoxelAStarGrid3D が使えることを確認
- M1-T02 `TerrainGenerator` / `WorldData` / `WorldView`(VoxelTerrain + 木の MultiMesh)/ `scenes/world/world.tscn`。数値は `data/terrain.json`
  - 並びは VoxelBuffer と同じ(y→x→z)。VoxelTerrain は 16bit なので Image の R8→RG8 変換で広げて写す
- M1-T03 `TerrainEditor`(4段まで掘れる)。文言は `data/texts.json` + `Texts.t()`
- M1-T04 `Pathing`(AStar2D、段差1まで)と `scenes/bench/bench_30.tscn`(結果は `user://logs/bench_30.log` に追記)
- M1-T05 `SavePrototype`(変わったチャンクだけ VoxelBlockSerializer の ZSTD、他は JSON)

### M2(中核)
- M2-T01 `CameraRig`(回転・ズーム・平行移動、ズームと俯角の制限、地表より下に入らない)
- M2-T02 `Village`(村全体のシミュレーション。村人は plan=手順の列をこなす)、`Villager`、`Needs`、`GameClock`
- M2-T03 `Designation`(伐る・掘る・建てる予約。深すぎる掘削は「これ以上は掘れません」、行けない仕事は「行けません」で保留)
- M2-T04 `Job`(data/jobs.json の順で拾う)/ M2-T05 `DirectOrder`(行けない所は「そこへは行けません」)
- M2-T06 `Crafting`(data/recipes.json、原木1→木材4、3段の連鎖をデータだけで確認)
- M2-T07 建設(予約→建設中→完成、素材不足で保留と不足アイコン、倉庫満杯で地面に置いて警告)
- M2-T08 `Wildlife`(ウサギ、狩人が肉と毛皮を倉庫へ運ぶ、肉→料理)
- M2-T09 `Equipment`(data/equipment.json、石のみ使える、耐久0で壊れて警告、倉庫から自分で取りに行く)
- M2-T10 `Proficiency` / M2-T11 `Stockpile`(区分けと優先度)/ M2-T12 `BuildingFixture`(data/fixtures.json)

### M3(差別化の3本柱)
- M3-T01/T02 `Inspection` / `Applicant` / `ScoreCard`(data/applicants.json, scoring.json, specialties.json)。5〜7日ごとに来訪、家→倉庫→救護室の順に見回り、加重平均60点以上で合格。不合格者は再来訪なし。重みは採点表まで出さない
- M3-T03 `RaidDirector`(5日目終了まで来ない、3日のクールタイム、豊かさで数が増える)/ M3-T04 `Monster` と `Combat`(衛兵は迎撃、他は家か救護室へ避難)
- M3-T05 `HealthState`(気絶→救護室へ運ぶ、半日で死亡、村人0人でも続く)/ M3-T06 `Chief`(方針は1日1回、治療中はバフなし、実時間3分で復帰)
- M3-T07 `Fog` / M3-T08 `Watchtower`(早めの警告、台の上の投石紐は射程1.5倍)/ M3-T09 救護室の設備(寝台で+1人、医療器具で-25%)/ M3-T10 `Ruins`
- 確認手順のテスト `tests/test_simulation.gd`: シード12345で7日進めて審査1回・襲撃1回

### 自分で判断したこと(確認してほしい)
- 料理は作業台で作る(焚き火は BUILDINGS.md で「推奨」=未承認のため)
- 木は地形ブロックにせず、列の印(world.trees)で持つ。建物も地形ブロックにせず、足元の列をふさぐ
- 狩りの仕事は、狩人の人数ぶんだけ近いウサギに自動で予約する(プレイヤーの「狩る」指示は SPEC にないため)
- 家の数値(素材・作業時間)は仮の値。BUILDINGS.md に数値がないので `data/buildings.json` に置いた
- 採点の各項目の出し方(data/scoring.json)は仮: 食料=あと何日分×10点、住居=空き寝床、安全=衛兵・柵・見張り台、施設=建物の種類、満足度=気分の平均
- 襲撃の「村の境界」= 開始地点から、建物のある範囲+6ブロック(最低20)の円
- 「視界内の衛兵」= 衛兵の視界16ブロック以内の魔物を迎え撃つ。見えなければ村の中心へ寄る
- 最初の食料を料理20→40にした(4人で約5日分)。20だと狩人なしで5日目に全員倒れた
- 村レベルの初期値と見張り台の解放(村レベル1)は M4-T04 で扱う

## 次にやること
- M4-T01 サイドバー → … M4 画面、M5 セーブ、M6 仕上げ

## 検証結果
- テスト: 90/90 passed(`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`、Voxel Tools 1.7 ビルド、約103秒)
- POC-002: 1000ブロック変更+30人で一致、ロード 0.5〜0.7秒(コンテナ)
- POC-001: **最低環境では未計測**。コンテナ(CPU 4コア、GPUなし)では headless で 145fps(処理だけ)、Xvfb+ソフトウェア描画で 7.5fps
- M2 の「確認手順」(新規ゲームで伐る→木材→家)は、画面(M4)ができてから手で確認する。ロジックはテストで確認済み

## 未解決・ユーザーへの質問
- POC-001 を最低環境(第7世代Intel・内蔵GPU)で `bench_30.tscn` を実行して fps を測ってほしい。Forward+ と Compatibility の両方
- 欲求の値をJSONに保存すると最下位の桁がずれる(1e-9 未満)。テストは 1e-9 の許容で比較している
- FIRST_PROMPT.md は当時の指示として 4.6/1.6 表記のまま
- BUILDINGS.md の「推奨」ラベルの建物の承認(前回から継続)

## 触ったファイル
- data/*.json(terrain, texts, time, needs, villagers, items, jobs, resources, buildings, recipes, wildlife, equipment, proficiency, stockpile, fixtures, camera)
- scripts/(game_data, texts, game_clock, village)、scripts/world/、scripts/villagers/、scripts/jobs/、scripts/needs/、scripts/save/、scripts/bench/、scripts/ui/camera_rig.gd
- scenes/world/world.tscn, scenes/bench/bench_30.tscn, tests/*.gd

## サブエージェントの利用
- なし
