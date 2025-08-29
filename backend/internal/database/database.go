package database

import (
	"database/sql"
	"miniPanel/internal/models"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

type DB struct {
	conn *sql.DB
}

func NewDB(dbPath string) (*DB, error) {
	conn, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, err
	}

	db := &DB{conn: conn}
	err = db.createTables()
	if err != nil {
		return nil, err
	}

	// 创建默认管理员用户
	err = db.createDefaultAdmin()
	if err != nil {
		return nil, err
	}

	return db, nil
}

func (db *DB) createTables() error {
	// 创建用户表
	userTable := `
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password TEXT NOT NULL
	);`

	// 创建节点表
	nodeTable := `
	CREATE TABLE IF NOT EXISTS nodes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		ip TEXT UNIQUE NOT NULL,
		status TEXT DEFAULT 'offline',
		last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
	);`

	// 创建系统监控数据表
	metricsTable := `
	CREATE TABLE IF NOT EXISTS system_metrics (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		node_id INTEGER NOT NULL,
		cpu_percent REAL NOT NULL,
		memory_total INTEGER NOT NULL,
		memory_used INTEGER NOT NULL,
		memory_percent REAL NOT NULL,
		cpu_temp REAL NOT NULL,
		timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (node_id) REFERENCES nodes(id)
	);`

	tables := []string{userTable, nodeTable, metricsTable}
	for _, table := range tables {
		_, err := db.conn.Exec(table)
		if err != nil {
			return err
		}
	}

	return nil
}

func (db *DB) createDefaultAdmin() error {
	// 检查是否已存在管理员用户
	var count int
	err := db.conn.QueryRow("SELECT COUNT(*) FROM users WHERE username = ?", "admin").Scan(&count)
	if err != nil {
		return err
	}

	if count > 0 {
		return nil // 管理员已存在
	}

	// 创建默认管理员用户
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	_, err = db.conn.Exec("INSERT INTO users (username, password) VALUES (?, ?)", "admin", string(hashedPassword))
	return err
}

// 用户相关操作
func (db *DB) GetUserByUsername(username string) (*models.User, error) {
	user := &models.User{}
	err := db.conn.QueryRow("SELECT id, username, password FROM users WHERE username = ?", username).Scan(
		&user.ID, &user.Username, &user.Password)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// 节点相关操作
func (db *DB) GetAllNodes() ([]models.Node, error) {
	rows, err := db.conn.Query("SELECT id, name, ip, status, last_seen FROM nodes")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var nodes []models.Node
	for rows.Next() {
		var node models.Node
		err := rows.Scan(&node.ID, &node.Name, &node.IP, &node.Status, &node.LastSeen)
		if err != nil {
			return nil, err
		}
		nodes = append(nodes, node)
	}

	return nodes, nil
}

func (db *DB) GetNodeByIP(ip string) (*models.Node, error) {
	node := &models.Node{}
	err := db.conn.QueryRow("SELECT id, name, ip, status, last_seen FROM nodes WHERE ip = ?", ip).Scan(
		&node.ID, &node.Name, &node.IP, &node.Status, &node.LastSeen)
	if err != nil {
		return nil, err
	}
	return node, nil
}

func (db *DB) CreateOrUpdateNode(name, ip string) error {
	// 尝试更新现有节点
	result, err := db.conn.Exec("UPDATE nodes SET name = ?, status = 'online', last_seen = CURRENT_TIMESTAMP WHERE ip = ?", name, ip)
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}

	// 如果没有更新任何行，则创建新节点
	if rowsAffected == 0 {
		_, err = db.conn.Exec("INSERT INTO nodes (name, ip, status) VALUES (?, ?, 'online')", name, ip)
		return err
	}

	return nil
}

// 监控数据相关操作
func (db *DB) InsertMetrics(metrics *models.AgentMetrics) error {
	_, err := db.conn.Exec(`
		INSERT INTO system_metrics (node_id, cpu_percent, memory_total, memory_used, memory_percent, cpu_temp, timestamp)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		metrics.NodeID, metrics.CPUPercent, metrics.MemoryTotal, metrics.MemoryUsed,
		metrics.MemoryPercent, metrics.CPUTemp, metrics.Timestamp.Format("2006-01-02 15:04:05"))
	return err
}

func (db *DB) GetLatestMetrics(nodeID int) (*models.SystemMetrics, error) {
	metrics := &models.SystemMetrics{}
	err := db.conn.QueryRow(`
		SELECT id, node_id, cpu_percent, memory_total, memory_used, memory_percent, cpu_temp, timestamp
		FROM system_metrics WHERE node_id = ? ORDER BY timestamp DESC LIMIT 1`,
		nodeID).Scan(&metrics.ID, &metrics.NodeID, &metrics.CPUPercent, &metrics.MemoryTotal,
		&metrics.MemoryUsed, &metrics.MemoryPercent, &metrics.CPUTemp, &metrics.Timestamp)
	if err != nil {
		return nil, err
	}
	return metrics, nil
}

func (db *DB) GetHistoryMetrics(nodeID int, days int) ([]models.SystemMetrics, error) {
	rows, err := db.conn.Query(`
		SELECT id, node_id, cpu_percent, memory_total, memory_used, memory_percent, cpu_temp, timestamp
		FROM system_metrics WHERE node_id = ? AND timestamp >= datetime('now', '-' || ? || ' days')
		ORDER BY timestamp DESC`,
		nodeID, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var metrics []models.SystemMetrics
	for rows.Next() {
		var metric models.SystemMetrics
		err := rows.Scan(&metric.ID, &metric.NodeID, &metric.CPUPercent, &metric.MemoryTotal,
			&metric.MemoryUsed, &metric.MemoryPercent, &metric.CPUTemp, &metric.Timestamp)
		if err != nil {
			return nil, err
		}
		metrics = append(metrics, metric)
	}

	return metrics, nil
}

func (db *DB) Close() error {
	return db.conn.Close()
}