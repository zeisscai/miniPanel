<template>
  <div class="realtime-container">
    <div class="page-header">
      <h2>实时监控</h2>
      <div class="header-actions">
        <el-select
          v-model="selectedNodeId"
          placeholder="选择节点"
          @change="handleNodeChange"
          style="width: 200px"
        >
          <el-option
            v-for="node in nodes"
            :key="node.id"
            :label="`${node.name} (${node.ip})`"
            :value="node.id"
          >
            <span>{{ node.name }}</span>
            <span style="float: right; color: #8492a6; font-size: 13px">
              <el-tag
                :type="node.status === 'online' ? 'success' : 'danger'"
                size="small"
              >
                {{ node.status }}
              </el-tag>
            </span>
          </el-option>
        </el-select>
        <el-button
          type="primary"
          :icon="Refresh"
          @click="refreshData"
          :loading="loading"
        >
          刷新
        </el-button>
      </div>
    </div>

    <div v-if="selectedNodeId && currentMetrics" class="metrics-grid">
      <!-- CPU使用率卡片 -->
      <el-card class="metric-card cpu-card">
        <template #header>
          <div class="card-header">
            <el-icon class="card-icon"><Cpu /></el-icon>
            <span>CPU使用率</span>
          </div>
        </template>
        <div class="metric-content">
          <div class="metric-value">
            {{ currentMetrics.cpu_percent.toFixed(1) }}%
          </div>
          <div class="metric-progress">
            <el-progress
              :percentage="currentMetrics.cpu_percent"
              :color="getProgressColor(currentMetrics.cpu_percent)"
              :show-text="false"
            />
          </div>
        </div>
      </el-card>

      <!-- 内存使用率卡片 -->
      <el-card class="metric-card memory-card">
        <template #header>
          <div class="card-header">
            <el-icon class="card-icon"><MemoryCard /></el-icon>
            <span>内存使用率</span>
          </div>
        </template>
        <div class="metric-content">
          <div class="metric-value">
            {{ currentMetrics.memory_percent.toFixed(1) }}%
          </div>
          <div class="metric-detail">
            {{ formatBytes(currentMetrics.memory_used) }} / {{ formatBytes(currentMetrics.memory_total) }}
          </div>
          <div class="metric-progress">
            <el-progress
              :percentage="currentMetrics.memory_percent"
              :color="getProgressColor(currentMetrics.memory_percent)"
              :show-text="false"
            />
          </div>
        </div>
      </el-card>

      <!-- CPU温度卡片 -->
      <el-card class="metric-card temp-card">
        <template #header>
          <div class="card-header">
            <el-icon class="card-icon"><Thermometer /></el-icon>
            <span>CPU温度</span>
          </div>
        </template>
        <div class="metric-content">
          <div class="metric-value">
            {{ currentMetrics.cpu_temp > 0 ? currentMetrics.cpu_temp.toFixed(1) + '°C' : 'N/A' }}
          </div>
          <div class="metric-progress" v-if="currentMetrics.cpu_temp > 0">
            <el-progress
              :percentage="Math.min(currentMetrics.cpu_temp, 100)"
              :color="getTempColor(currentMetrics.cpu_temp)"
              :show-text="false"
            />
          </div>
        </div>
      </el-card>
    </div>

    <!-- 无数据提示 -->
    <el-empty
      v-else-if="selectedNodeId && !loading"
      description="暂无监控数据"
      :image-size="100"
    />

    <!-- 未选择节点提示 -->
    <el-empty
      v-else-if="!selectedNodeId && !loading"
      description="请选择要监控的节点"
      :image-size="100"
    />

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <el-skeleton :rows="3" animated />
    </div>

    <!-- 最后更新时间 -->
    <div v-if="currentMetrics" class="update-time">
      <el-text type="info" size="small">
        最后更新：{{ formatTime(currentMetrics.timestamp) }}
      </el-text>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { apiMethods } from '@/api'
import { ElMessage } from 'element-plus'
import { Refresh, Cpu, MemoryCard, Thermometer } from '@element-plus/icons-vue'

const nodes = ref([])
const selectedNodeId = ref(null)
const currentMetrics = ref(null)
const loading = ref(false)
let refreshTimer = null

// 获取节点列表
const fetchNodes = async () => {
  try {
    const response = await apiMethods.getNodes()
    if (response.data.success) {
      nodes.value = response.data.data
      // 自动选择第一个在线节点
      if (nodes.value.length > 0 && !selectedNodeId.value) {
        const onlineNode = nodes.value.find(node => node.status === 'online')
        selectedNodeId.value = onlineNode ? onlineNode.id : nodes.value[0].id
        fetchMetrics()
      }
    }
  } catch (error) {
    ElMessage.error('获取节点列表失败')
  }
}

// 获取监控数据
const fetchMetrics = async () => {
  if (!selectedNodeId.value) return
  
  try {
    loading.value = true
    const response = await apiMethods.getRealTimeMetrics(selectedNodeId.value)
    if (response.data.success) {
      currentMetrics.value = response.data.data
    } else {
      currentMetrics.value = null
      ElMessage.warning('该节点暂无监控数据')
    }
  } catch (error) {
    ElMessage.error('获取监控数据失败')
    currentMetrics.value = null
  } finally {
    loading.value = false
  }
}

// 节点切换处理
const handleNodeChange = () => {
  currentMetrics.value = null
  fetchMetrics()
}

// 刷新数据
const refreshData = () => {
  fetchNodes()
  fetchMetrics()
}

// 自动刷新
const startAutoRefresh = () => {
  refreshTimer = setInterval(() => {
    fetchMetrics()
  }, 30000) // 30秒刷新一次
}

const stopAutoRefresh = () => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
    refreshTimer = null
  }
}

// 格式化字节数
const formatBytes = (bytes) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

// 格式化时间
const formatTime = (timestamp) => {
  return new Date(timestamp).toLocaleString('zh-CN')
}

// 获取进度条颜色
const getProgressColor = (percentage) => {
  if (percentage < 50) return '#67c23a'
  if (percentage < 80) return '#e6a23c'
  return '#f56c6c'
}

// 获取温度颜色
const getTempColor = (temp) => {
  if (temp < 50) return '#67c23a'
  if (temp < 70) return '#e6a23c'
  return '#f56c6c'
}

onMounted(() => {
  fetchNodes()
  startAutoRefresh()
})

onUnmounted(() => {
  stopAutoRefresh()
})
</script>

<style scoped>
.realtime-container {
  padding: 0;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding: 0 4px;
}

.page-header h2 {
  margin: 0;
  color: #303133;
  font-size: 24px;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 12px;
  align-items: center;
}

.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 20px;
  margin-bottom: 24px;
}

.metric-card {
  border-radius: 12px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
  transition: transform 0.2s, box-shadow 0.2s;
}

.metric-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}

.card-header {
  display: flex;
  align-items: center;
  font-weight: 600;
  color: #303133;
}

.card-icon {
  margin-right: 8px;
  font-size: 18px;
}

.cpu-card .card-icon {
  color: #409eff;
}

.memory-card .card-icon {
  color: #67c23a;
}

.temp-card .card-icon {
  color: #e6a23c;
}

.metric-content {
  padding: 16px 0;
}

.metric-value {
  font-size: 36px;
  font-weight: 700;
  color: #303133;
  margin-bottom: 8px;
}

.metric-detail {
  font-size: 14px;
  color: #909399;
  margin-bottom: 12px;
}

.metric-progress {
  margin-top: 12px;
}

.loading-container {
  padding: 20px;
}

.update-time {
  text-align: center;
  padding: 16px;
  border-top: 1px solid #ebeef5;
  background-color: #fafafa;
  border-radius: 8px;
}
</style>