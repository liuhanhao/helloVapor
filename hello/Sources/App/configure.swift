import Vapor
import Fluent
import FluentSQLiteDriver

// configures your application
public func configure(_ app: Application) throws {
    
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

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
    
    // register routes
    try routes(app)
    
    try app.autoMigrate().wait()
//    // or
//    try await app.autoMigrate()

    
    
}
