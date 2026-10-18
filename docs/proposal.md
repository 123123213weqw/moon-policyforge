# Moon PolicyForge 项目申报参考书

## 可解释多规则决策与具名版本回放

账号：123123213weqw；主要语言：MoonBit；许可：Apache-2.0；更新日期：2026-10-18。  
GitHub：[https://github.com/123123213weqw/moon-policyforge](https://github.com/123123213weqw/moon-policyforge)  
仓库发行：1.1.0；公共模块：[123123213weqw/moon_policyforge@0.10.0](https://mooncakes.io/docs/123123213weqw/moon_policyforge@0.10.0)

本文供个人参考，按本次实际代码及边界编写。公开提交、CI、发布和独立安装结果另附交付核对表，不以材料修订代替主办方重新审核。

## 一、项目职责与本次改进

保留公开最新版已有的决策表、冲突分析、静态检查、快照及验证能力，新增 replay_versions：同一组有唯一 ID 的事实分别执行旧、新规则，逐条报告决定、冲突、错误和命中集合的变化。区分样本等价与全局证明，报告漂移可供 CLI 门控。拒绝空规则 ID、diff 中重复身份、非整数执行预算及决策表列名注入；纠正编译决策表即证明互斥的说明。

已有核心能力继续保留，具体入口及完整使用方式见仓库 README 与 API 清单。本次对旧仓库先做版本同步，保留公开历史，不将此前已完成的功能重写为本轮新成果。

## 二、可复现输入及预期结果

以下为新增固定夹具之一，输入与字段断言同时纳入测试。更多场景见 tests/cases.json 和 examples/；所有样本均为合成数据，不作为真实用户证据。

```json
{
  "operation": "replay_versions",
  "old": {
    "rules": [
      {
        "id": "pass",
        "when": "score >= 50",
        "output": "pass"
      }
    ],
    "default": "review"
  },
  "new": {
    "rules": [
      {
        "id": "pass",
        "when": "score >= 60",
        "output": "pass"
      }
    ],
    "default": "review"
  },
  "cases": [
    {
      "id": "edge",
      "facts": {
        "score": 55
      }
    },
    {
      "id": "stable",
      "facts": {
        "score": 70
      }
    }
  ]
}
```

预期结果字段：

```json
{
  "sample_count": 2,
  "changed_count": 1,
  "cases/0/decision_changed": true,
  "cases/1/decision_changed": false,
  "global_equivalence_proven": false
}
```

## 三、实现和验证结构

领域计算由 MoonBit 完成，宿主侧负责文件、HTTP、进程或独立参考算法。可复用接口保持 execute(Json)→Json 与语义值 run 入口；实际公开接口以 pkg.generated.mbti 为准。当前根目录包含 316 项 MoonBit 测试声明，CLI 固定夹具 107 组；其中自动生成的夹具测试按生成测试统计，不算额外生产实现。

复核路径为四后端核心测试、真实 CLI 夹具、独立参考检查、宿主场景（适用时）、公开 CI 和公共包独立安装。新增检查运行：

```sh
moon update
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon test --target native
moon build --target js
node scripts/check.mjs
python -B scripts/followup_reference.py
moon run cmd/main --target js -- examples/followup-20261018.json
```

native 需要 C 编译器；标为带变化/问题的有效报告可能使用退出码 2。实际通过记录和对应源码版本见交付核对表，命令列表本身不作为通过证明。

## 四、开发记录与来源

本次提交按错误修正、针对性测试、领域实现、独立参考和版本文档记录，均使用真实日期并保留原有历史。2026-09-01 后的数量与哈希由 GitHub API 核查；达到数量条件不意味着所有提交已获主办方认定。

共同 JSON/CLI 脚手架按基础设施说明，不当作各项目独有创新。实际依赖、参考与许可见 THIRD_PARTY.md；第三方代码、生成夹具和文档不计为独立生产实现。功能有重叠时，不以“纯 MoonBit”“带测试”或“无 I/O”主张唯一性，项目差异应落到可执行机制与案例。

## 五、当前边界

新回放入口接收 decide 定义，不递归执行任意操作。样本回放不证明全输入空间等价；决策表编译本身不证明行互斥，同类项目也具备求值、解释或测试能力，不能把通用能力作为独有性证明。

完整原方案的代码量、性能目标与用户效果不自动沿用为当前成果；统计以源码实际值及本机/CI 的测量记录为准。比赛准入、团队/项目数解释和最终审核仍由主办方决定，本轮不代提交报名。
