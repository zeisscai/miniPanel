<template>
  <div class="history-container">
    <el-card class="header-card">
      <div class="header-content">
        <h2>历史监控数据</h2>
        <div class="controls">
          <el-select v-model="selectedNode" placeholder="选择节点" style="width: 200px; margin-right: 10px;">
            <el-option
              v-for="node in nodes"
              :key="node.id"
              :label="node.name"
              :value="node.id"
            />
          </el-select>
          <el-date-picker
            v-model="dateRange"
            type="datetimerange"
            range-separator="至"
            start-placeholder="开始时间"
            end-placeholder="结束时间"
            format="YYYY-MM-DD HH:mm:ss"
            value-format="YYYY-MM-DD HH:mm:ss"
            style="margin-right: 10px;"
          />
          <el-button type="primary" @click="loadHistoryData" :loading="loading">
            <el-icon><Search /></el-icon>
            查询
          </el-button>
        </div>
      </div>
    </el-card>

    <div v-if="historyData.length > 0" class="charts-container">
      <el-row :gutter="20">
        <el-col :span="24">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <span>CPU 使用率趋势</span>
              </div>
            </template>
            <div class="chart-wrapper">
              <Line :data="cpuChartData" :options="chartOptions" />
            </div>
          </el-card>
        </el-col>
      </el-row>

      <el-row :gutter="20" style="margin-top: 20px;">
        <el-col :span="24">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <span>内存使用率趋势</span>
              </div>
            </template>
            <div class="chart-wrapper">
              <Line :data="memoryChartData" :options="chartOptions" />
            </div>
          </el-card>
        </el-col>
      </el-row>

      <el-row :gutter="20" style="margin-top: 20px;">
        <el-col :span="24">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <span>CPU 温度趋势</span>
              </div>
            </template>
            <div class="chart-wrapper">
              <Line :data="temperatureChartData" :options="temperatureChartOptions" />
            </div>
          </el-card>
        </el-col>
      </el-row>
    </div>

    <div v-else-if="!loading" class="no-data">
      <el-empty description="暂无数据" />
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ElMessage } from 'element-plus'
import { Search } from '@element-plus/icons-vue'
import { Line } from 'vue-chartjs'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
} from 'chart.js'
import { getNodes, getHistoryMetrics } from '@/api'

// 注册 Chart.js 组件
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
)

// 响应式数据
const nodes = ref([])
const selectedNode = ref('')
const dateRange = ref([])
const historyData = ref([])
const loading = ref(false)

// 图表配置
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'top'
    },
    title: {
      display: false
    }
  },
  scales: {
    y: {
      beginAtZero: true,
      max: 100,
      ticks: {
        callback: function(value) {
          return value + '%'
        }
      }
    }
  }
}

const temperatureChartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'top'
    },
    title: {
      display: false
    }
  },
  scales: {
    y: {
      beginAtZero: false,
      ticks: {
        callback: function(value) {
          return value + '°C'
        }
      }
    }
  }
}

// 计算属性 - CPU 图表数据
const cpuChartData = computed(() => {
  if (historyData.value.length === 0) return { labels: [], datasets: [] }
  
  return {
    labels: historyData.value.map(item => formatTime(item.timestamp)),
    datasets: [
      {
        label: 'CPU 使用率',
        data: historyData.value.map(item => item.cpu_usage),
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.2)',
        tension: 0.1
      }
    ]
  }
})

// 计算属性 - 内存图表数据
const memoryChartData = computed(() => {
  if (historyData.value.length === 0) return { labels: [], datasets: [] }
  
  return {
    labels: historyData.value.map(item => formatTime(item.timestamp)),
    datasets: [
      {
        label: '内存使用率',
        data: historyData.value.map(item => item.memory_usage),
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.2)',
        tension: 0.1
      }
    ]
  }
})

// 计算属性 - 温度图表数据
const temperatureChartData = computed(() => {
  if (historyData.value.length === 0) return { labels: [], datasets: [] }
  
  return {
    labels: historyData.value.map(item => formatTime(item.timestamp)),
    datasets: [
      {
        label: 'CPU 温度',
        data: historyData.value.map(item => item.cpu_temperature),
        borderColor: 'rgb(255, 205, 86)',
        backgroundColor: 'rgba(255, 205, 86, 0.2)',
        tension: 0.1
      }
    ]
  }
})

// 格式化时间
const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  return date.toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// 加载节点列表
const loadNodes = async () => {
  try {
    const response = await getNodes()
    nodes.value = response.data.nodes || []
    if (nodes.value.length > 0) {
      selectedNode.value = nodes.value[0].id
    }
  } catch (error) {
    ElMessage.error('加载节点列表失败')
  }
}

// 加载历史数据
const loadHistoryData = async () => {
  if (!selectedNode.value) {
    ElMessage.warning('请选择节点')
    return
  }
  
  if (!dateRange.value || dateRange.value.length !== 2) {
    ElMessage.warning('请选择时间范围')
    return
  }
  
  loading.value = true
  try {
    const response = await getHistoryMetrics({
      node_id: selectedNode.value,
      start_time: dateRange.value[0],
      end_time: dateRange.value[1]
    })
    historyData.value = response.data.metrics || []
    if (historyData.value.length === 0) {
      ElMessage.info('所选时间范围内暂无数据')
    }
  } catch (error) {
    ElMessage.error('加载历史数据失败')
    historyData.value = []
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载节点列表
onMounted(() => {
  loadNodes()
  // 设置默认时间范围为最近24小时
  const now = new Date()
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000)
  dateRange.value = [
    yesterday.toISOString().slice(0, 19).replace('T', ' '),
    now.toISOString().slice(0, 19).replace('T', ' ')
  ]
})
</script>

<style scoped>
.history-container {
  padding: 20px;
}

.header-card {
  margin-bottom: 20px;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 20px;
}

.header-content h2 {
  margin: 0;
  color: #303133;
}

.controls {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.charts-container {
  margin-top: 20px;
}

.chart-card {
  height: 400px;
}

.chart-wrapper {
  height: 320px;
  position: relative;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.no-data {
  margin-top: 100px;
  text-align: center;
}

@media (max-width: 768px) {
  .header-content {
    flex-direction: column;
    align-items: stretch;
  }
  
  .controls {
    justify-content: center;
  }
  
  .chart-card {
    height: 300px;
  }
  
  .chart-wrapper {
    height: 220px;
  }
}
</style>