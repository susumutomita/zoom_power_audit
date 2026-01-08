# Zoom Power Audit

macOS用のバッテリー消費診断ツール。Zoom会議中の電力消費、CPU、メモリ使用率を計測し、異常なバッテリー消耗の原因を特定します。

**特に M4 MacBook Air + 外部ディスプレイ + Zoom の組み合わせで発生するバッテリー問題の調査に最適です。**

## Quick Start

```bash
# リポジトリをクローン
git clone https://github.com/stomita/zoom-power-audit.git
cd zoom-power-audit

# 実行権限を付与
chmod +x zoom-power-audit.sh

# 会議開始直前に実行（60分間、10秒間隔）
./zoom-power-audit.sh --duration-min 60 --interval-sec 10

# または短いテスト
./zoom-power-audit.sh --duration-min 5 --interval-sec 5
```

会議終了後、`~/zoom_power_audit_YYYYmmdd_HHMMSS/` フォルダが生成されます。

## 何が計測できるか

| 項目 | 説明 |
|------|------|
| バッテリー残量推移 | 時系列での消耗率を可視化 |
| Zoom CPU/メモリ | zoom.us, CptHost プロセスの合計 |
| WindowServer CPU/メモリ | ディスプレイ描画負荷の指標 |
| 電源ソース | AC/バッテリー切り替え検知 |
| トップCPUプロセス | 各サンプル時点の上位プロセス |
| 外部ディスプレイ情報 | 解像度、リフレッシュレート、接続方式 |
| 省エネ設定 | pmset の現在値 |

## 出力ファイル

```
~/zoom_power_audit_20250108_143000/
├── baseline.txt   # 開始時点のシステム情報
├── samples.csv    # 時系列データ（Excelで開ける）
└── after.txt      # 終了時点の情報 + pmset ログ
```

### samples.csv の列

| 列名 | 説明 |
|------|------|
| timestamp | サンプル取得時刻 |
| power_source | AC または Battery |
| battery_percent | バッテリー残量 (%) |
| zoom_cpu_percent | Zoom関連プロセス合計CPU (%) |
| zoom_mem_mb | Zoom関連プロセス合計メモリ (MB) |
| windowserver_cpu_percent | WindowServer CPU (%) |
| windowserver_mem_mb | WindowServer メモリ (MB) |
| top_processes | その時点のCPU上位3プロセス |

## 推奨ワークフロー

1. **会議開始直前**にスクリプトを起動
2. **会議終了**まで放置（Ctrl+C でも安全に終了可）
3. 生成された**フォルダをzip**して共有
4. samples.csv を**Numbers/Excel**で開いてグラフ化

```bash
# フォルダをzipにまとめる
cd ~
zip -r zoom_audit_report.zip zoom_power_audit_20250108_143000/
```

## 典型的な原因パターンと対処法

### WindowServer CPU が高い（15%超）

**原因**: ディスプレイ描画負荷が高い
- 外部ディスプレイのリフレッシュレートが高い（120Hz等）
- 高解像度スケーリング
- Dockのアニメーション
- Thunderbolt/USB-Cアダプターの問題

**対処法**:
```
システム設定 > ディスプレイ > リフレッシュレート → 60Hz に固定
システム設定 > ディスプレイ > 解像度 → デフォルトを使用
システム設定 > デスクトップとDock > ウインドウをしまうエフェクト → スケールエフェクト
```

### Zoom CPU が高い（30%超）

**原因**: Zoom の映像処理負荷
- 仮想背景/ぼかし有効
- HD ビデオ有効
- 低照度補正有効
- 画面共有中

**対処法**:
```
Zoom 設定 > 背景とエフェクト > 仮想背景なし
Zoom 設定 > ビデオ > HDを無効にする
Zoom 設定 > ビデオ > 低照度に対して調整 → オフ
可能なら画面共有の代わりにリンク共有
```

### Chrome/Safari が上位にいる

**原因**: 画面共有でブラウザを表示している
- ハードウェアアクセラレーション無効
- 重いWebページを共有

**対処法**:
```
Chrome: 設定 > システム > ハードウェアアクセラレーション → オン
不要なタブを閉じてから共有
```

### バッテリー消耗が特に激しい（1時間で20%以上）

複合要因の可能性が高い。以下を順番に確認：

1. [ ] 外部ディスプレイを60Hzに固定
2. [ ] Zoom仮想背景をオフ
3. [ ] ZoomのHDビデオをオフ
4. [ ] 低電力モードをオン
5. [ ] ケーブル/アダプターを別のものに交換
6. [ ] ディスプレイを1台に減らしてテスト

## 追加ツール

### quick_triage.sh - ワンショット診断

今の状態だけを素早く取得してSlackやIssueに貼りたい時に使用：

```bash
./scripts/quick_triage.sh
```

出力をそのままコピペできます。

### collect_powermetrics.sh - 詳細電力データ（要sudo）

より詳細なプロセス別電力消費を取得：

```bash
sudo ./scripts/collect_powermetrics.sh 30  # 30分間
```

`powermetrics` コマンドによる Energy Impact、Package Power、GPU Power などを取得します。

## インストール（任意）

PATH に入れて `zoom-power-audit` コマンドとして使いたい場合：

```bash
./install.sh                    # ~/.local/bin にインストール
./install.sh /usr/local/bin     # 別の場所にインストール（sudo必要）
```

## プライバシーに関する注意

生成されるログには以下の情報が含まれます：

- USB機器の名前（例: "Logitech HD Pro Webcam"）
- 外部ディスプレイの名前（例: "LG UltraFine 4K"）
- Thunderbolt機器の情報
- ユーザー名を含むプロセスリスト
- pmset ログの電源イベント履歴

**共有前に内容を確認し、必要に応じて編集してください。**

## トラブルシューティング

### "permission denied" エラー

```bash
chmod +x zoom-power-audit.sh
```

### Zoomプロセスが検出されない

Zoomのプロセス名がバージョンによって異なる場合があります。以下で確認：

```bash
ps aux | grep -i zoom
```

`zoom.us` や `CptHost` 以外の名前が出てきた場合は Issue で報告ください。

### topのenergy列が取得できない

macOSバージョンによっては `top` コマンドの出力形式が異なります。
このツールでは `ps` コマンドを使用しているため、通常は問題ありません。

詳細な電力情報が必要な場合は `collect_powermetrics.sh`（要sudo）を使用してください。

### 日本語macOSで動かない

スクリプトはローカライズに対応していますが、問題が発生した場合は Issue で報告ください。

### 外部ディスプレイ情報が取得できない

`system_profiler SPDisplaysDataType` が失敗する環境があります。
baseline.txt の該当部分が空でも、CPU/メモリ計測は正常に動作します。

## CSV からの簡易解析

Numbers または Excel で開いて以下を確認：

1. **グラフを作成**: timestamp を X軸、zoom_cpu_percent と windowserver_cpu_percent を Y軸
2. **平均値を計算**: `=AVERAGE(D:D)` で Zoom CPU 平均
3. **最大値を確認**: `=MAX(D:D)` で Zoom CPU ピーク
4. **バッテリー消耗率**: 最初と最後の battery_percent の差を時間で割る

## 互換性

| 項目 | 対応状況 |
|------|----------|
| macOS 14 (Sonoma) | ✅ 対応 |
| macOS 15 (Sequoia) | ✅ 対応 |
| Apple Silicon (M1/M2/M3/M4) | ✅ 対応 |
| Intel Mac | ⚠️ 限定テスト（動作報告歓迎） |
| bash 3.x (macOS標準) | ✅ 対応 |

## よくある質問

**Q: sudoは必要ですか？**
A: メインスクリプト (`zoom-power-audit.sh`) は sudo 不要です。詳細な電力データが必要な場合のみ `collect_powermetrics.sh` で sudo を使います。

**Q: バッテリー駆動中でないと計測できませんか？**
A: AC電源接続中でも計測可能です。ただしバッテリー消耗の検証には、意図的にACを外して計測することを推奨します。

**Q: 計測中にMacがスリープしたらどうなりますか？**
A: スリープ中はサンプリングが停止します。会議中は通常スリープしませんが、Energy Saver 設定を確認してください。

**Q: Zoom以外のビデオ会議アプリにも使えますか？**
A: CPU/メモリ/WindowServer の計測は汎用的に使えます。アプリ固有のプロセス検出をカスタマイズしたい場合は Issue で相談ください。

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## 貢献

Issue や Pull Request を歓迎します。

- バグ報告: 環境情報と再現手順を含めてください
- 機能要望: ユースケースを説明してください
- PR: 小さな変更でも歓迎します

## 関連リンク

- [Apple: Mac でのエネルギー消費を抑える](https://support.apple.com/ja-jp/HT208544)
- [Zoom: CPU使用率を下げるヒント](https://support.zoom.us/hc/ja/articles/201362023)
