import Vapor
import Fluent
import FluentSQLiteDriver

// configures your application
public func configure(_ app: Application) throws {
    
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // CORS 中间件：允许浏览器跨域访问（开发期前端走代理，此处作为兜底）
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // 上传媒体访问的 Content-Type 修正（issue 04）：必须在 FileMiddleware 之前注册，
    // 对 /uploads/ 下的音视频文件按扩展名显式给出正确 MIME（aac/m4a 等内置映射缺失或不当），
    // 保证浏览器 <audio>/<video> 在聊天窗口内直接播放；流式输出支持 Range（播放器拖动进度）
    app.middleware.use(UploadsTypeMiddleware())

    // 静态文件服务（issue 03）：托管 Public 目录，
    // 上传的媒体文件存于 Public/uploads/，通过 /uploads/<文件名> 访问
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Increases the streaming body collection limit to 500kb
    // Vapor 将会限制 streaming body collection 的大小为16KB，你可以使用 app.routes 来配置它
//    app.routes.defaultMaxBodySize = "500kb"
    
    // 配置sqlite
    app.databases.use(.sqlite(.file(app.directory.workingDirectory + "chatMessage.db")), as: .sqlite)
    
    // 用户表
    app.migrations.add(User.Migration())

    // 用户token表
    app.migrations.add(UserToken.Migration())
    
    // 消息表
    app.migrations.add(CreateMessage())
    
    // 消息表新增 msgType 字段
    app.migrations.add(AddMessageMsgType())
    
    // register routes
    try routes(app)
    
    try app.autoMigrate().wait()
//    // or
//    try await app.autoMigrate()

    
    
}
