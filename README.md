# Hearthold

ボクセルの土地で村を育てるコロニーシム。仕様は SPEC.md、実装の順序は PLAN.md。

## 使っているバージョン(2026-10-26 確認)

| 名前 | バージョン | 出典 |
|---|---|---|
| Godot | 4.7.2-stable | https://github.com/godotengine/godot/releases/tag/4.7.2-stable |
| Voxel Tools | 1.7(Godot 4.7.2 向け。カスタムビルドのエディタを使う) | https://github.com/Zylann/godot_voxel/releases/tag/v1.7 |
| GUT | 9.7.1(Godot 4.7 向け、`addons/gut/`、MIT) | https://github.com/bitwes/Gut/releases/tag/v9.7.1 |

## テスト

```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## ライセンス

MIT(LICENSE)。GUT は `addons/gut/LICENSE.md`。
