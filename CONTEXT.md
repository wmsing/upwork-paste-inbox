# Job Inbox

个人用职位收件箱：把从平台复制的职位原文存下来，跟踪处理状态，并生成可读摘要与「是否适合 Flutter 维护类工作」的判断依据。

## Language

**Posting**:
从外部平台（如 Upwork）复制进来的职位原文快照；创建后内容原则上不变，除非用户显式编辑。
_Avoid_: Job, listing, gig（对外沟通可用，域内统一用 Posting）

**Source URL**:
用户可选填的原文链接，用于回到平台查看；系统不抓取页面内容。
_Avoid_: permalink, job link

**Display Title**:
收件箱列表上显示的短标题；默认取自粘贴正文的首个非空行，用户可随时修改。
_Avoid_: subject, headline

**Posting Fingerprint**:
由 Posting 正文派生的身份标记；指纹相同视为同一条职位原文，不得重复新建 Inbox Item，应打开已有项。
_Avoid_: content hash, dedupe key

**Inbox Item**:
收件箱里的一条记录，绑定一份 Posting、Display Title、当前处理状态、跳过时的预设与备注，以及（若已生成）摘要与匹配评估。
_Avoid_: Job record, lead

**Readiness Status**:
用户对一条 Inbox Item 的处理进度：未读、已读、已投、跳过。
_Avoid_: stage, pipeline state

**Skip Preset**:
将状态设为「跳过」时选择的分类（如非 Flutter、预算、时区、已关闭、其他）。
_Avoid_: skip category, dismissal type

**Skip Note**:
跳过时可附带的自由备注，补充 Skip Preset 未覆盖的细节。
_Avoid_: Skip Reason（旧称，域内拆成 Preset + Note）

**Summary**:
对 Posting 的压缩说明，含英文与中文两份正文，用于快速回忆「这条在招什么」；由用户一键触发生成，可重新生成并记录生成时间。
_Avoid_: TL;DR, abstract

**Match Assessment**:
针对「Flutter 维护 / 长期维护型移动端」的三档结论（强匹配、可考虑、不建议）及简短理由；评判标准由产品固定，首版用户不可编辑规则。
_Avoid_: fit score, 0–100, recommendation
