// ============================================================
// NexaCommerce Frontend — API Client
// Typed HTTP client for all backend services
// ============================================================

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios'

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://api.nexacommerce.com'

// ── Types ─────────────────────────────────────────────────

export interface Product {
  id: string
  name: string
  slug: string
  description: string
  price: number
  currency: string
  images: string[]
  category: Category
  sku: string
  inStock: boolean
  stockCount: number
  rating: number
  reviewCount: number
  createdAt: string
}

export interface Category {
  id: string
  name: string
  slug: string
  parentId?: string
}

export interface CartItem {
  id: string
  productId: string
  product: Product
  quantity: number
  unitPrice: number
  totalPrice: number
}

export interface Cart {
  id: string
  userId: string
  items: CartItem[]
  subtotal: number
  itemCount: number
  updatedAt: string
}

export interface Order {
  id: string
  userId: string
  status: 'pending' | 'confirmed' | 'processing' | 'shipped' | 'delivered' | 'cancelled'
  items: OrderItem[]
  subtotal: number
  shippingCost: number
  tax: number
  total: number
  shippingAddress: Address
  createdAt: string
  updatedAt: string
}

export interface OrderItem {
  id: string
  productId: string
  productName: string
  quantity: number
  unitPrice: number
  totalPrice: number
}

export interface Address {
  street: string
  city: string
  state: string
  zip: string
  country: string
}

export interface User {
  id: string
  email: string
  firstName: string
  lastName: string
  createdAt: string
}

export interface AuthTokens {
  accessToken: string
  expiresIn: number
  tokenType: string
}

export interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  pageSize: number
  totalPages: number
}

export interface SearchResult {
  products: Product[]
  total: number
  query: string
  facets: Record<string, unknown>
}

// ── API Client ────────────────────────────────────────────

class ApiClient {
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: API_URL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    })

    // Request interceptor — attach auth token
    this.client.interceptors.request.use((config) => {
      if (typeof window !== 'undefined') {
        const token = localStorage.getItem('access_token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
      }
      return config
    })

    // Response interceptor — handle token refresh
    this.client.interceptors.response.use(
      (response) => response,
      async (error) => {
        const originalRequest = error.config
        if (error.response?.status === 401 && !originalRequest._retry) {
          originalRequest._retry = true
          try {
            await this.refreshToken()
            return this.client(originalRequest)
          } catch {
            this.clearTokens()
            window.location.href = '/auth/login'
          }
        }
        return Promise.reject(error)
      }
    )
  }

  private clearTokens() {
    localStorage.removeItem('access_token')
  }

  private async refreshToken(): Promise<void> {
    const response = await this.client.post<AuthTokens>('/api/v1/auth/refresh')
    localStorage.setItem('access_token', response.data.accessToken)
  }

  // ── Auth ────────────────────────────────────────────────
  async login(email: string, password: string): Promise<AuthTokens> {
    const res = await this.client.post<AuthTokens>('/api/v1/auth/login', { email, password })
    localStorage.setItem('access_token', res.data.accessToken)
    return res.data
  }

  async logout(): Promise<void> {
    await this.client.post('/api/v1/auth/logout')
    this.clearTokens()
  }

  async register(data: { email: string; password: string; firstName: string; lastName: string }): Promise<User> {
    const res = await this.client.post<User>('/api/v1/auth/register', data)
    return res.data
  }

  async getMe(): Promise<User> {
    const res = await this.client.get<User>('/api/v1/auth/me')
    return res.data
  }

  // ── Products ────────────────────────────────────────────
  async getProducts(params?: {
    page?: number
    pageSize?: number
    category?: string
    sort?: string
    minPrice?: number
    maxPrice?: number
  }): Promise<PaginatedResponse<Product>> {
    const res = await this.client.get<PaginatedResponse<Product>>('/api/v1/products', { params })
    return res.data
  }

  async getProduct(slug: string): Promise<Product> {
    const res = await this.client.get<Product>(`/api/v1/products/${slug}`)
    return res.data
  }

  async searchProducts(query: string, params?: Record<string, unknown>): Promise<SearchResult> {
    const res = await this.client.get<SearchResult>('/api/v1/search', { params: { q: query, ...params } })
    return res.data
  }

  async getCategories(): Promise<Category[]> {
    const res = await this.client.get<Category[]>('/api/v1/categories')
    return res.data
  }

  // ── Cart ────────────────────────────────────────────────
  async getCart(): Promise<Cart> {
    const res = await this.client.get<Cart>('/api/v1/cart')
    return res.data
  }

  async addToCart(productId: string, quantity: number): Promise<Cart> {
    const res = await this.client.post<Cart>('/api/v1/cart/items', { productId, quantity })
    return res.data
  }

  async updateCartItem(itemId: string, quantity: number): Promise<Cart> {
    const res = await this.client.put<Cart>(`/api/v1/cart/items/${itemId}`, { quantity })
    return res.data
  }

  async removeFromCart(itemId: string): Promise<Cart> {
    const res = await this.client.delete<Cart>(`/api/v1/cart/items/${itemId}`)
    return res.data
  }

  async clearCart(): Promise<void> {
    await this.client.delete('/api/v1/cart')
  }

  // ── Orders ──────────────────────────────────────────────
  async checkout(data: {
    shippingAddress: Address
    paymentMethod: { type: string; token: string }
  }): Promise<Order> {
    const res = await this.client.post<Order>('/api/v1/orders/checkout', data)
    return res.data
  }

  async getOrders(params?: { page?: number; pageSize?: number }): Promise<PaginatedResponse<Order>> {
    const res = await this.client.get<PaginatedResponse<Order>>('/api/v1/orders', { params })
    return res.data
  }

  async getOrder(orderId: string): Promise<Order> {
    const res = await this.client.get<Order>(`/api/v1/orders/${orderId}`)
    return res.data
  }

  // ── Health ──────────────────────────────────────────────
  async health(): Promise<{ status: string }> {
    const res = await this.client.get<{ status: string }>('/health')
    return res.data
  }
}

export const apiClient = new ApiClient()
export default apiClient
