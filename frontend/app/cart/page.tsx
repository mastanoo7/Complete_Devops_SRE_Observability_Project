'use client'

// ============================================================
// Cart Page — Client Component
// ============================================================

import Link from 'next/link'
import { useState } from 'react'

interface CartItemData {
  id: string
  name: string
  price: number
  quantity: number
  image: string
}

function CartItemRow({
  item,
  onUpdate,
  onRemove,
}: {
  item: CartItemData
  onUpdate: (id: string, qty: number) => void
  onRemove: (id: string) => void
}) {
  return (
    <div className="flex items-center gap-4 py-4 border-b border-gray-200">
      <img
        src={item.image}
        alt={item.name}
        className="h-20 w-20 rounded-lg object-cover bg-gray-100"
      />
      <div className="flex-1">
        <h3 className="text-sm font-medium text-gray-900">{item.name}</h3>
        <p className="text-sm text-gray-500 mt-1">${item.price.toFixed(2)} each</p>
      </div>
      <div className="flex items-center gap-2">
        <button
          onClick={() => onUpdate(item.id, Math.max(1, item.quantity - 1))}
          className="h-8 w-8 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
        >
          −
        </button>
        <span className="w-8 text-center text-sm font-medium">{item.quantity}</span>
        <button
          onClick={() => onUpdate(item.id, item.quantity + 1)}
          className="h-8 w-8 rounded-full border border-gray-300 flex items-center justify-center hover:bg-gray-50"
        >
          +
        </button>
      </div>
      <div className="text-right">
        <p className="text-sm font-semibold text-gray-900">
          ${(item.price * item.quantity).toFixed(2)}
        </p>
        <button
          onClick={() => onRemove(item.id)}
          className="text-xs text-red-500 hover:text-red-700 mt-1"
        >
          Remove
        </button>
      </div>
    </div>
  )
}

export default function CartPage() {
  const [items, setItems] = useState<CartItemData[]>([
    { id: '1', name: 'Wireless Headphones Pro', price: 89.99, quantity: 1, image: 'https://via.placeholder.com/80' },
    { id: '2', name: 'Mechanical Keyboard RGB', price: 149.99, quantity: 2, image: 'https://via.placeholder.com/80' },
    { id: '3', name: 'USB-C Hub 7-in-1', price: 39.99, quantity: 1, image: 'https://via.placeholder.com/80' },
  ])

  const updateItem = (id: string, qty: number) => {
    setItems(items.map(item => item.id === id ? { ...item, quantity: qty } : item))
  }

  const removeItem = (id: string) => {
    setItems(items.filter(item => item.id !== id))
  }

  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const shipping = subtotal > 50 ? 0 : 9.99
  const tax = subtotal * 0.08
  const total = subtotal + shipping + tax

  if (items.length === 0) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-16 text-center">
        <div className="text-6xl mb-4">🛒</div>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Your cart is empty</h1>
        <p className="text-gray-500 mb-8">Add some products to get started</p>
        <Link href="/products" className="btn-primary">
          Continue Shopping
        </Link>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-8">
        Shopping Cart ({items.length} items)
      </h1>

      <div className="lg:grid lg:grid-cols-12 lg:gap-8">
        {/* Cart items */}
        <div className="lg:col-span-8">
          <div className="card p-6">
            {items.map(item => (
              <CartItemRow
                key={item.id}
                item={item}
                onUpdate={updateItem}
                onRemove={removeItem}
              />
            ))}
          </div>

          <div className="mt-4 flex justify-between">
            <Link href="/products" className="btn-secondary">
              ← Continue Shopping
            </Link>
            <button
              onClick={() => setItems([])}
              className="text-sm text-red-500 hover:text-red-700"
            >
              Clear Cart
            </button>
          </div>
        </div>

        {/* Order summary */}
        <div className="lg:col-span-4 mt-8 lg:mt-0">
          <div className="card p-6 sticky top-4">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">Order Summary</h2>

            <div className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-gray-600">Subtotal</span>
                <span className="font-medium">${subtotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Shipping</span>
                <span className="font-medium">
                  {shipping === 0 ? (
                    <span className="text-green-600">Free</span>
                  ) : (
                    `$${shipping.toFixed(2)}`
                  )}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">Tax (8%)</span>
                <span className="font-medium">${tax.toFixed(2)}</span>
              </div>
              <div className="border-t border-gray-200 pt-3 flex justify-between">
                <span className="font-semibold text-gray-900">Total</span>
                <span className="font-bold text-lg text-gray-900">${total.toFixed(2)}</span>
              </div>
            </div>

            {subtotal < 50 && (
              <p className="text-xs text-gray-500 mt-3">
                Add ${(50 - subtotal).toFixed(2)} more for free shipping
              </p>
            )}

            <Link href="/checkout" className="btn-primary w-full mt-6 text-center block">
              Proceed to Checkout →
            </Link>

            <div className="mt-4 flex items-center justify-center gap-2 text-xs text-gray-500">
              <span>🔒</span>
              <span>Secure SSL checkout</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
