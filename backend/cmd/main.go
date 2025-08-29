package main

import (
	"log"
	"miniPanel/internal/config"
	"miniPanel/internal/database"
	"miniPanel/internal/handlers"

	"github.com/gin-gonic/gin"
)

func main() {
	// 加载配置
	cfg := config.DefaultConfig()

	// 初始化数据库
	db, err := database.NewDB(cfg.Database.Path)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	// 初始化处理器
	h := handlers.NewHandler(db, cfg.Auth.JWTSecret)

	// 设置Gin模式
	gin.SetMode(gin.ReleaseMode)

	// 创建路由
	r := gin.Default()

	// CORS中间件
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization, Node-Name")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// 公开路由
	public := r.Group("/api")
	{
		public.POST("/login", h.Login)
		public.POST("/metrics", h.ReceiveMetrics) // Agent上报数据接口
	}

	// 需要认证的路由
	auth := r.Group("/api")
	auth.Use(h.JWTMiddleware())
	{
		auth.GET("/nodes", h.GetNodes)
		auth.GET("/metrics/realtime", h.GetRealTimeMetrics)
		auth.GET("/metrics/history", h.GetHistoryMetrics)
	}

	// 静态文件服务（用于前端）
	r.Static("/static", "./static")
	r.StaticFile("/", "./static/index.html")
	r.StaticFile("/favicon.ico", "./static/favicon.ico")

	// 启动服务器
	addr := cfg.Server.Host + ":" + cfg.Server.Port
	log.Printf("MiniPanel server starting on %s", addr)
	log.Printf("Default admin credentials: admin/admin123")

	if err := r.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}