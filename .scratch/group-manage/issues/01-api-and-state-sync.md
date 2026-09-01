# 01 — 接口封装与群状态同步

**要构建的内容：** 把服务端已就绪的「改群名」与「拉人入群」两个接口接进前端数据层，并保证改名/加人之后界面各处显示一致。在此之前 `api.ts` 里没有这两个封装，`GroupInfoDialog` 也无从调用。

**只做数据层，不做界面**——跑完之后 `GroupInfoDialog.vue` 的外观与行为必须完全不变（`npm run e2e` 的 176 项是回归基线，服务端零改动）。

**被阻塞于（Blocked by）：** 无

**状态（Status）：** resolved

- [x] `api.ts` 新增 `updateGroup(token, groupId, { name })`（`PATCH /chat/groups/:id`）
- [x] `api.ts` 新增 `addGroupMember(token, groupId, userId)`（`POST /chat/groups/:id/members`，body `{ userId }`）
- [x] `stores/chat.ts` 新增 `renameGroup(groupId, name)`，成功后同步三处状态
- [x] `stores/chat.ts` 新增 `addGroupMember(groupId, userId)`，成员数以服务端返回值为准
- [x] 错误按 `ApiError` 原样上抛，不吞掉服务端 `reason`
- [x] 401 按既有惯例 `auth.logout()`，由路由守卫回登录页
- [x] `npm run build` 通过；`npm run e2e` **176 项全绿**（服务端零改动，行为零变化）

## 实施要点

- **状态同步是最容易漏的一步。** 改名成功后如果只更新 `groups[id].name`，会话列表那条目的 `peer.nickname` 仍是旧名——`GET /chat/sessions` 要下次拉取才会更新。三处必须一起改：`groups[id]`、`sessions` 里 `peer.userid === groupId` 的条目（`peer.nickname` 与 `memberCount`）、`recipientNames[id]`。写下这条是因为「列表改名了、气泡标题还是旧的」这类不一致事后极难定位。
- **成员数以服务端返回的 `GroupSummaryDTO.memberCount` 为准**，不要本地 `+1`。两个接口都返回完整的 `GroupSummaryDTO`，本地算一次就是第二处真相。
- **`addMember` 只收单个 `userId`**（`AddMemberPayload` 是单值），与建群的 `memberIds` 数组**形状不同**。不要照着 `createGroup` 的形状写，也不要为了省事把它写成数组——服务端会静默忽略多余字段然后报「缺少要拉入群的用户 userId」。
- **群成员数上限 200 由服务端 `guardMemberCount` 校验**（超限 400）。前端不要自己维护一份上限常量，那是第二处真相。
- 拉人/改名的错误 `reason` 已是可读中文（「该用户已在群内」「群成员数不能超过 200 人」「用户 ID 格式不正确：x」），**直接透传到界面即可**，不要改写成笼统文案。
- 两个 store 动作都返回更新后的 `GroupSummary`，供调用方（02 的弹窗）直接刷新成员数显示。
- 沿用 `stores/chat.ts` 里既有动作的写法：`const token = auth.token; if (!token) throw new Error('尚未登录')`，`catch` 里判 `ApiError.status === 401` 走 `auth.logout()`。

## Comments

**2026-09-01 拆分（Agent）：** 决策依据见 `../spec.md`。本 ticket 是 B7 的数据层，界面承接在 `02`。核心事实：服务端两个接口早已实现且被 e2e 第 17 节完整覆盖，本功能服务端零改动——**因此本 ticket 不需要新增任何服务端用例**，176 项全绿即是验收标准。

## Comments

**2026-09-01 实施（Agent）：** 改动落在 `types.ts`（`GroupSummary` 加 `ownerId`）、`api.ts`（`updateGroup` / `addGroupMember`）、`stores/chat.ts`（`applyGroupSummary` + `renameGroup` / `addGroupMember`，并导出 `groups`）。验证：`npm run build` 通过；`npm run e2e` **176 PASS / 0 FAIL**。服务端零改动，`GroupInfoDialog.vue` 外观与行为完全不变。

实现落点与给后续 issue 的约定：

- **`GroupSummary` 原本只有 `id / name / memberCount`，没有 `ownerId`** —— 服务端 `GroupSummaryDTO` 一直有这个字段，只是 TS 类型没声明。已补上，`02` 的「仅创建者可见」判定直接读 `chat.groups[id].ownerId`。全仓没有构造 `GroupSummary` 字面量的地方（全部来自接口响应），加字段安全。
- **`groups` 原本没有从 store 导出。** `GroupInfoDialog` 现在读群名走的是 `chat.recipientNames[groupId]` 而非 `chat.groups`，根本没有 `ownerId` 可用。已把 `groups` 加进返回块；`02` 直接用 `chat.groups[props.groupId]?.ownerId === auth.user?.id` 判定即可，`groups` 由 `onMounted` 里的 `loadGroups()` 可靠填充。
- **三处状态同步收进 `applyGroupSummary(group)` 一个函数**：`groups[id]`、`recipientNames[id]`、`sessions` 里匹配条目的 `peer.nickname` 与 `memberCount`。两个动作都调它，避免「改名只改一处」的漏同步。
- **`sessions` 条目是直接改的**（`item.peer.nickname = group.name`），不是重建数组——条目是响应式对象，直接赋值即可触发更新，重建反而会打乱列表顺序。
- 未做 `isGroupOwner` 之类的封装：spec 明确「刻意不引入角色概念，创建者判定直接比 `ownerId`」，且只有 `02` 一处使用，提前抽象是过度设计。
