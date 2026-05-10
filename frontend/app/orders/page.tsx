// ============================================================
// Orders Page — Order history and tracking
// ============================================================

import type { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'My Orders — NexaCommerce',
  description: 'View your order history and track shipments',
}

const STATUS_STYLES: Record<string, string> = {
  pending:    'badge bg-yellow-100 text-yellow-800',
  confirmed:  'badge bg-blue-100 text-blue-800',
  processing: 'badge bg-purple-100 text-purple-800',
  shipped:    'badge bg-indigo-100 text-indigo-800',
  delivered:  'badge-success',
  cancelled:  'badge bg-red-100 text-red-800',
}

const STATUS_ICONS: Record<string, string> = {
  pending: '⏳', confirmed: '✅', processing: '⚙️',
  shipped: '🚚', delivered: '📦', cancelled: '❌',
}

// Mock orders data
const MOCK_ORDERS = [
  {
    id: 'ORD-2024-001',
    date: '2024-01-15',
    status: 'delivered',
    total: 421.17,
    items: [
      { name: 'Wireless Headphones Pro', qty: 1, price: 89.99 },
      { name: 'Mechanical Keyboard RGB', qty: 2, price: 149.99 },
    ],
  },
  {
    id: 'ORD-2024-002',
    date: '2024-01-20',
    status: 'shipped',
    total: 199.99,
    items: [
      { name: '4K Monitor 27"', qty: 1, price: 199.99 },
    ],
  },
  {
    id: 'ORD-2024-003',
    date: '2024-01-25',
    status: 'processing',
    total: 79.98,
    items: [
      { name: 'USB-C Hub 7-in-1', qty: 2, price: 39.99 },
    ],
  },
]

function OrderCard({ order }: { order: typeof MOCK_ORDERS[0] }) {
  return (
    <div className="card p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div>
          <h3 className="font-semibold text-gray-900">{order.id}</h3>
          <p className="text-sm text-gray-500 mt-1">
            Placed on {new Date(order.date).toLocaleDateString('en-US', {
              year: 'numeric', month: 'long', day: 'numeric'
            })}
          </p>
        </div>
        <div className="text-right">
          <span className={STATUS_STYLES[order.status] || 'badge bg-gray-100 text-gray-800'}>
            {STATUS_ICONS[order.status]} {order.status.charAt(0).toUpperCase() + order.status.slice(1)}
          </span>
          <p className="text-lg font-bold text-gray-900 mt-2">${order.total.toFixed(2)}</p>
        </div>
      </div>

      <div className="border-t border-gray-100 pt-4">
        <div className="space-y-2">
          {order.items.map((item, i) => (
            <div key={i} className="flex justify-between text-sm">
              <span className="text-gray-600">{item.name} × {item.qty}</span>
              <span className="text-gray-900">${(item.price * item.qty).toFixed(2)}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-4 flex gap-3">
        <Link
          href={`/orders/${order.id}`}
          className="btn-secondary text-sm flex-1 text-center"
        >
          View Details
        </Link>
        {order.status === 'delivered' && (
          <button className="btn-secondary text-sm flex-1">
            Reorder
          </button>
        )}
        {order.status === 'shipped' && (
          <button className="btn-primary text-sm flex-1">
            Track Package
          </button>
        )}
      </div>
    </div>
  )
}

export default function OrdersPage() {
  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">My Orders</h1>
          <p className="text-gray-500 mt-1">{MOCK_ORDERS.length} orders total</p>
        </div>
        <Link href="/products" className="btn-secondary text-sm">
          Continue Shopping
        </Link>
      </div>

      {/* Filter tabs */}
      <div className="flex gap-2 mb-6 border-b border-gray-200">
        {['All', 'Active', 'Delivered', 'Cancelled'].map((tab) => (
          <button
            key={tab}
            className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors
              ${tab === 'All'
                ? 'border-brand-600 text-brand-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Orders list */}
      {MOCK_ORDERS.length === 0 ? (
        <div className="text-center py-16">
          <div className="text-6xl mb-4">📦</div>
          <h2 className="text-xl font-semibold text-gray-900 mb-2">No orders yet</h2>
          <p className="text-gray-500 mb-8">Start shopping to see your orders here</p>
          <Link href="/products" className="btn-primary">Shop Now</Link>
        </div>
      ) : (
        <div className="space-y-4">
          {MOCK_ORDERS.map((order) => (
            <OrderCard key={order.id} order={order} />
          ))}
        </div>
      )}
    </div>
  )
}
