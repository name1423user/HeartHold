# HANDOFF — Hearthold

最終更新: 2026-10-26 17:36 JST(毎ターン更新して push する)

## 現在のタスク
- M1(PoC)完了。次は M2-T01 から順に進める(ユーザー指示「全部できるところまで」)

## このターンで終わったこと
- Voxel Tools 1.7 の Linux エディタビルド(`godot.linuxbsd.editor.x86_64.zip`、SHA-256 35c92e9f…dea)を取得し、headless で VoxelTerrain / VoxelBlockSerializer / VoxelAStarGrid3D が使えることを確認
- M1-T02 シード付き地形生成: `TerrainGenerator` / `WorldData` / `WorldView`(VoxelTerrain + 木の MultiMesh)/ `scenes/world/world.tscn`。数値は `data/terrain.json`
  - 並びは VoxelBuffer と同じ(y→x→z)。VoxelTerrain は 16bit なので Image の R8→RG8 変換で広げて写す
- M1-T03 `TerrainEditor`: 1ブロックの破壊・設置。元の地表から5段目以降は「これ以上は掘れません」。文言は `data/texts.json` + `Texts.t()`
- M1-T04 `Pathing`(AStar2D、段差1まで)と `scenes/bench/bench_30.tscn`(30体+毎秒10ブロック編集、平均/最低fpsを `user://logs/bench_30.log` に追記)
- M1-T05 `SavePrototype`: 元と違うチャンクだけ VoxelBlockSerializer(ZSTD)、他は JSON

## 次にやること
- M2-T01 カメラ → M2-T02 村人と欲求 → … PLAN の順

## 検証結果
- テスト: 12/12 passed(`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`、Voxel Tools 1.7 ビルド)
- AC-001/002: シード12345で2回生成して全ブロック一致、3シードで4地形あり・開始半径16が平ら
- AC-004: 4段まで掘れ、5段目は拒否
- POC-002: 1000ブロック変更+30人で一致、ロード 0.5〜0.7秒(コンテナ)
- POC-001: **最低環境では未計測**。コンテナ(CPU 4コア、GPUなし)では headless で 145fps(処理だけ)、Xvfb+ソフトウェア描画(OpenGL)で 7.5fps。描画方式の比較(Forward+ / Compatibility)も実機でしかできない
- 見た目: Xvfb でスクリーンショットを撮り、岩山・川・森・草原が描かれることを確認

## 未解決・ユーザーへの質問
- POC-001 を最低環境(第7世代Intel・内蔵GPU)で `bench_30.tscn` を実行して fps を測ってほしい。Forward+ と Compatibility の両方(プロジェクト設定 rendering/renderer/rendering_method)
- 欲求の値をJSONに保存すると最下位の桁がずれる(1e-9 未満)。テストは 1e-9 の許容で比較している
- FIRST_PROMPT.md は当時の指示として 4.6/1.6 表記のまま
- BUILDINGS.md の「推奨」ラベルの建物の承認(前回から継続)

## 触ったファイル
- data/terrain.json, data/texts.json, scripts/game_data.gd, scripts/texts.gd, scripts/world/*.gd, scripts/villagers/pathing.gd, scripts/bench/bench_30.gd, scripts/save/save_prototype.gd, scenes/world/world.tscn, scenes/bench/bench_30.tscn, tests/test_terrain_generator.gd, tests/test_terrain_editor.gd, tests/test_pathing.gd, tests/test_save_prototype.gd

## サブエージェントの利用
- なし
