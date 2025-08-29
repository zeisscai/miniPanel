package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"miniPanel/internal/database"
	"miniPanel/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type Handler struct {
	db        *database.DB
	jwtSecret string
}

func NewHandler(db *database.DB, jwtSecret string) *Handler {
	return &Handler{
		db:        db,
		jwtSecret: jwtSecret,
	}
}

// JWT Claims
type Claims struct {
	UserID   int    `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

// 生成JWT Token
func (h *Handler) generateToken(user *models.User) (string, error) {
	claims := &Claims{
		UserID:   user.ID,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.jwtSecret))
}

// JWT中间件
func (h *Handler) JWTMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Success: false,
				Message: "Authorization header required",
			})
			c.Abort()
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Success: false,
				Message: "Invalid authorization format",
			})
			c.Abort()
			return
		}

		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			return []byte(h.jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, models.APIResponse{
				Success: false,
				Message: "Invalid token",
			})
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Next()
	}
}

// 登录处理
func (h *Handler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "Invalid request format",
		})
		return
	}

	user, err := h.db.GetUserByUsername(req.Username)
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Success: false,
			Message: "Invalid username or password",
		})
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password))
	if err != nil {
		c.JSON(http.StatusUnauthorized, models.APIResponse{
			Success: false,
			Message: "Invalid username or password",
		})
		return
	}

	token, err := h.generateToken(user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to generate token",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: models.LoginResponse{
			Token: token,
			User:  *user,
		},
	})
}

// 获取节点列表
func (h *Handler) GetNodes(c *gin.Context) {
	nodes, err := h.db.GetAllNodes()
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to get nodes",
		})
		return
	}

	c.JSON(http.StatusOK, models.NodesResponse{
		Success: true,
		Data:    nodes,
	})
}

// 获取实时监控数据
func (h *Handler) GetRealTimeMetrics(c *gin.Context) {
	nodeIDStr := c.Query("node_id")
	if nodeIDStr == "" {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "node_id parameter required",
		})
		return
	}

	nodeID, err := strconv.Atoi(nodeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "Invalid node_id",
		})
		return
	}

	metrics, err := h.db.GetLatestMetrics(nodeID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Message: "No metrics found for this node",
		})
		return
	}

	c.JSON(http.StatusOK, models.MetricsResponse{
		Success: true,
		Data:    *metrics,
	})
}

// 获取历史监控数据
func (h *Handler) GetHistoryMetrics(c *gin.Context) {
	nodeIDStr := c.Query("node_id")
	daysStr := c.DefaultQuery("days", "1")

	if nodeIDStr == "" {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "node_id parameter required",
		})
		return
	}

	nodeID, err := strconv.Atoi(nodeIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "Invalid node_id",
		})
		return
	}

	days, err := strconv.Atoi(daysStr)
	if err != nil || days <= 0 {
		days = 1
	}

	metrics, err := h.db.GetHistoryMetrics(nodeID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to get history metrics",
		})
		return
	}

	c.JSON(http.StatusOK, models.MetricsResponse{
		Success: true,
		List:    metrics,
	})
}

// Agent上报数据接口
func (h *Handler) ReceiveMetrics(c *gin.Context) {
	var agentMetrics models.AgentMetrics
	if err := c.ShouldBindJSON(&agentMetrics); err != nil {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Message: "Invalid request format",
		})
		return
	}

	// 设置时间戳
	if agentMetrics.Timestamp.IsZero() {
		agentMetrics.Timestamp = time.Now()
	}

	// 获取客户端IP作为节点标识
	clientIP := c.ClientIP()
	if c.GetHeader("X-Real-IP") != "" {
		clientIP = c.GetHeader("X-Real-IP")
	} else if c.GetHeader("X-Forwarded-For") != "" {
		clientIP = strings.Split(c.GetHeader("X-Forwarded-For"), ",")[0]
	}

	// 创建或更新节点信息
	nodeName := c.GetHeader("Node-Name")
	if nodeName == "" {
		nodeName = clientIP
	}

	err := h.db.CreateOrUpdateNode(nodeName, clientIP)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to update node info",
		})
		return
	}

	// 获取节点ID
	node, err := h.db.GetNodeByIP(clientIP)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to get node info",
		})
		return
	}

	agentMetrics.NodeID = node.ID

	// 插入监控数据
	err = h.db.InsertMetrics(&agentMetrics)
	if err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Message: "Failed to save metrics",
		})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Metrics received successfully",
	})
}