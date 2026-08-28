# helloVapor IM

一个即时聊天（IM）系统：Vapor（Swift）服务端 + iOS 客户端 + Web 客户端，用户之间进行一对一单聊。

## Language（语言）

**用户（User）**：
注册后可登录系统的账号，拥有昵称、头像和登录凭证。
_Avoid（避免）_: 账号、客户、account

**会话（Session）**：
两个用户之间的单聊对话，由双方收发的全部消息构成。
_Avoid（避免）_: 聊天室、对话框、channel

**消息（Message）**：
会话中从一方发送到另一方的一条内容，带有消息类型（msgType）。
_Avoid（避免）_: 事件、通知、push

**消息类型（msgType）**：
消息内容的形态分类：text（文本，含 Unicode emoji）、image、audio、video。
_Avoid（避免）_: kind、category

**媒体消息**：
消息类型为 image、audio 或 video 的消息；内容字段存的是服务端文件的 URL，而非文件本身。
_Avoid（避免）_: 附件、文件消息

**联系人**：
会话列表中出现的对方用户，由历史消息推导而来，无需显式的好友关系。
_Avoid（避免）_: 好友、friend

**token**：
登录成功后签发的访问凭证，后续请求用于标识用户身份。
_Avoid（避免）_: session、cookie
