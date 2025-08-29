import axios from 'axios'
import { useAuthStore } from '@/stores/auth'
import { ElMessage } from 'element-plus'

// 创建axios实例
const api = axios.create({
  baseURL: '',
  timeout: 10000
})

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    const authStore = useAuthStore()
    if (authStore.token) {
      config.headers.Authorization = `Bearer ${authStore.token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response
  },
  (error) => {
    if (error.response?.status === 401) {
      const authStore = useAuthStore()
      authStore.logout()
      window.location.href = '/login'
      ElMessage.error('登录已过期，请重新登录')
    } else {
      ElMessage.error(error.response?.data?.message || '请求失败')
    }
    return Promise.reject(error)
  }
)

// API方法
// 获取节点列表
export const getNodes = () => api.get('/api/nodes')

// 获取实时监控数据
export const getRealTimeMetrics = (nodeId) => api.get(`/api/metrics/realtime?node_id=${nodeId}`)

// 获取历史监控数据
export const getHistoryMetrics = (nodeId, startTime, endTime) => {
  const params = new URLSearchParams({
    node_id: nodeId,
    start_time: startTime,
    end_time: endTime
  })
  return api.get(`/api/metrics/history?${params}`)
}

export default api