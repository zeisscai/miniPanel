-- MiniPanel 数据库初始化脚本
-- SQLite 数据库表结构定义

-- 开始事务
BEGIN TRANSACTION;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email TEXT,
    role TEXT DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 节点表
CREATE TABLE IF NOT EXISTS nodes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    ip_address TEXT,
    os_info TEXT,
    status TEXT DEFAULT 'offline',
    last_seen DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 系统监控数据表
CREATE TABLE IF NOT EXISTS system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id TEXT NOT NULL,
    cpu_usage REAL NOT NULL,
    memory_usage REAL NOT NULL,
    cpu_temperature REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES nodes(id) ON DELETE CASCADE
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_system_metrics_node_id ON system_metrics(node_id);
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_system_metrics_node_timestamp ON system_metrics(node_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status);
CREATE INDEX IF NOT EXISTS idx_nodes_last_seen ON nodes(last_seen);

-- 插入默认管理员用户
-- 密码: admin123 (bcrypt hash)
INSERT OR IGNORE INTO users (username, password, email, role) 
VALUES ('admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@example.com', 'admin');

-- 插入示例节点数据（可选）
INSERT OR IGNORE INTO nodes (id, name, ip_address, os_info, status) 
VALUES 
    ('node-001', '主服务器', '192.168.1.100', 'Ubuntu 20.04 LTS', 'online'),
    ('node-002', '备份服务器', '192.168.1.101', 'CentOS 8', 'offline');

-- 插入示例监控数据（可选）
INSERT OR IGNORE INTO system_metrics (node_id, cpu_usage, memory_usage, cpu_temperature, timestamp) 
VALUES 
    ('node-001', 25.5, 60.2, 45.0, datetime('now', '-1 hour')),
    ('node-001', 30.1, 65.8, 47.5, datetime('now', '-30 minutes')),
    ('node-001', 22.8, 58.9, 43.2, datetime('now'));

-- 创建视图以便于查询最新的监控数据
CREATE VIEW IF NOT EXISTS latest_metrics AS
SELECT 
    n.id as node_id,
    n.name as node_name,
    n.status,
    sm.cpu_usage,
    sm.memory_usage,
    sm.cpu_temperature,
    sm.timestamp
FROM nodes n
LEFT JOIN (
    SELECT 
        node_id,
        cpu_usage,
        memory_usage,
        cpu_temperature,
        timestamp,
        ROW_NUMBER() OVER (PARTITION BY node_id ORDER BY timestamp DESC) as rn
    FROM system_metrics
) sm ON n.id = sm.node_id AND sm.rn = 1;

-- 创建触发器以自动更新 updated_at 字段
CREATE TRIGGER IF NOT EXISTS update_users_timestamp 
    AFTER UPDATE ON users
    FOR EACH ROW
    BEGIN
        UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
    END;

CREATE TRIGGER IF NOT EXISTS update_nodes_timestamp 
    AFTER UPDATE ON nodes
    FOR EACH ROW
    BEGIN
        UPDATE nodes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
    END;

-- 数据清理：删除30天前的监控数据（可选，用于定期清理）
-- DELETE FROM system_metrics WHERE timestamp < datetime('now', '-30 days');

-- 提交事务
COMMIT;