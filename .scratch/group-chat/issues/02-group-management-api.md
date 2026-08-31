# 02 — 建群与成员管理接口

**要构建的内容：** 让群与成员关系可以被创建和查询。在此之前没有接口能造出一个群，`01` 建的表是空的，后续的消息流转无从验证。

**被阻塞于（Blocked by）：** 01 — 群聊数据模型与迁移

**状态（Status）：** resolved

- [x] `POST /chat/groups`：建群。入参 `name`、`memberIds`（不含创建者）。创建者自动成为成员且为 `owner_id`
- [x] 成员数上限 200：超过返回明确错误（建群与加人都要校验）
- [x] 成员存在性校验：传入不存在的用户 id 返回明确错误，不静默丢弃
- [x] `GET /chat/groups`：返回我加入的群（id、名称、头像、成员数、创建者）
- [x] `GET /chat/groups/:id/members`：群成员列表（非成员访问被拒）
- [x] `POST /chat/groups/:id/members`：拉人入群（任何成员都可以）
- [x] `DELETE /chat/groups/:id/members/:userId`：退群（只能退自己，不能踢人）
- [x] `PATCH /chat/groups/:id`：改群名/头像，**仅创建者**
- [x] 全部接口走 `UserToken` 鉴权；未携带 token 返回 401
- [x] 现有 77 项联调全绿（不碰消息路径，单聊零影响）

## 实施要点

- 权限规则已定死，**不要自作主张加管理员或群主转让**：任何成员可拉人；只有创建者可改群名；只能退自己不能踢人。见 `../spec.md` 决策记录第 1、3 条。
- 被拉入群不需要本人同意（决策记录第 1 条），不要加邀请确认状态机。
- 错误返回沿用现有风格：`Abort(.badRequest, reason: "...")`，文案要说明「为什么」（例如「群成员数不能超过 200 人」）。
- 新建控制器放 `hello/Sources/App/Controllers/`，路由注册到 `routes.swift` 的 `tokenProtected` 分组里，与 `/chat/sessions`、`/chat/users` 并列。
- 联调用例补进 `web/e2e-check.mjs`（脚本里有现成的注册/登录/断言范式可参考）。

## Comments

**2026-08-31 拆分（Agent）：** 本 ticket 不触及消息路径，是纯粹的 CRUD，可以独立验证。

**2026-08-31 实施（Agent）：** 六个接口全部落地，验证方式与证据：

- 编译：`swift build` 通过，无新增错误（仅既有 Swift 6 `Sendable` 警告）。
- 回归：`web/e2e-check.mjs` **110 PASS / 0 FAIL**（既有 77 项全绿 + 新增 33 项群管理用例）。
- 用例覆盖：建群（创建者自动入群且为 owner、成员数 3、默认头像）/ 不存在的用户 id（400「以下用户不存在：…」）/ 非法 UUID（400「用户 ID 格式不正确」）/ 空群名（400）/ 200 人上限（400「群成员数不能超过 200 人」）/ 群列表只含我加入的群 / 成员列表身份取自 users 表 / 非成员查成员、拉人、退群后访问均 403 / 任何成员可拉人且被拉入者群列表立即出现 / 重复拉入 409 / 退自己成功且成员数减少、退群后从群列表消失 / 创建者也移不动别人 403 / 非创建者改群名 403 / 创建者改名改头像同步到他人群列表 / 不带字段的 PATCH 400 / 群不存在 404 / 三个接口未带 token 均 401。

实现落点与给后续 issue 的约定：

- 新增 `hello/Sources/App/Controllers/GroupController.swift`（DTO + 六个 static 方法 + 私有校验），路由注册在 `routes.swift` 的 `tokenProtected` 分组内，位于 `/chat/users` 与 `/chat/upload` 之间。
- **成员数上限的校验在建群时先于存在性校验执行**（`guardMemberCount` 在 `validateUserIds` 之前）：先判上限可以省掉为一个注定失败的请求查 200 条用户记录。拉人路径共用同一个 `guardMemberCount`。
- **`POST /chat/groups/:id/members` 一次只拉一人**（请求体 `{ "userId": "..." }`），与 `DELETE .../members/:userId` 对称；建群的 `memberIds` 才是数组。后续若要批量拉人，先把请求体改成 `userIds` 数组并复用 `validateUserIds`（它已去重）。
- 群 id 一律按 UUID 校验：路径上的非法 UUID 返回 400「群 ID 格式不正确」，合法但不存在的返回 404「群不存在」。
- 退群后该群对自己的可见性全部消失（群列表、成员列表），符合决策记录第 4 条；**owner 退群未做特殊处理**（不转让、不解散，超出本期范围），群会变成无主状态——03（消息流转）扇出时按成员表走，不受影响。
