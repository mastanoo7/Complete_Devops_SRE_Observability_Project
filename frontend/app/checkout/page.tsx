'use client'

// ============================================================
// Checkout Page — Multi-step checkout flow
// ============================================================

import { useState } from 'react'
import Link from 'next/link'

type Step = 'shipping' | 'payment' | 'review'

function StepIndicator({ current }: { current: Step }) {
  const steps: { id: Step; label: string }[] = [
    { id: 'shipping', label: 'Shipping' },
    { id: 'payment', label: 'Payment' },
    { id: 'review', label: 'Review' },
  ]
  const currentIndex = steps.findIndex(s => s.id === current)

  return (
    <div className="flex items-center justify-center mb-8">
      {steps.map((step, i) => (
        <div key={step.id} className="flex items-center">
          <div className={`flex items-center justify-center w-8 h-8 rounded-full text-sm font-medium
            ${i <= currentIndex ? 'bg-brand-600 text-white' : 'bg-gray-200 text-gray-500'}`}>
            {i < currentIndex ? '✓' : i + 1}
          </div>
          <span className={`ml-2 text-sm font-medium ${i <= currentIndex ? 'text-brand-600' : 'text-gray-500'}`}>
            {step.label}
          </span>
          {i < steps.length - 1 && (
            <div className={`mx-4 h-0.5 w-16 ${i < currentIndex ? 'bg-brand-600' : 'bg-gray-200'}`} />
          )}
        </div>
      ))}
    </div>
  )
}

function ShippingForm({ onNext }: { onNext: () => void }) {
  return (
    <div className="card p-6">
      <h2 className="text-lg font-semibold text-gray-900 mb-6">Shipping Address</h2>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">First Name</label>
          <input type="text" className="input" placeholder="John" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Last Name</label>
          <input type="text" className="input" placeholder="Doe" />
        </div>
        <div className="col-span-2">
          <label className="block text-sm font-medium text-gray-700 mb-1">Street Address</label>
          <input type="text" className="input" placeholder="123 Main St" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">City</label>
          <input type="text" className="input" placeholder="San Francisco" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">State</label>
          <input type="text" className="input" placeholder="CA" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">ZIP Code</label>
          <input type="text" className="input" placeholder="94105" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Country</label>
          <select className="input">
            <option>United States</option>
            <option>Canada</option>
            <option>United Kingdom</option>
          </select>
        </div>
      </div>
      <div className="mt-6 flex justify-between">
        <Link href="/cart" className="btn-secondary">← Back to Cart</Link>
        <button onClick={onNext} className="btn-primary">Continue to Payment →</button>
      </div>
    </div>
  )
}

function PaymentForm({ onNext, onBack }: { onNext: () => void; onBack: () => void }) {
  return (
    <div className="card p-6">
      <h2 className="text-lg font-semibold text-gray-900 mb-6">Payment Method</h2>
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Card Number</label>
          <input type="text" className="input" placeholder="4242 4242 4242 4242" maxLength={19} />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Expiry Date</label>
            <input type="text" className="input" placeholder="MM/YY" maxLength={5} />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">CVV</label>
            <input type="text" className="input" placeholder="123" maxLength={4} />
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Name on Card</label>
          <input type="text" className="input" placeholder="John Doe" />
        </div>
      </div>
      <div className="mt-4 flex items-center gap-2 text-xs text-gray-500">
        <span>🔒</span>
        <span>Your payment info is encrypted and secure</span>
      </div>
      <div className="mt-6 flex justify-between">
        <button onClick={onBack} className="btn-secondary">← Back</button>
        <button onClick={onNext} className="btn-primary">Review Order →</button>
      </div>
    </div>
  )
}

function OrderReview({ onPlace, onBack }: { onPlace: () => void; onBack: () => void }) {
  return (
    <div className="card p-6">
      <h2 className="text-lg font-semibold text-gray-900 mb-6">Review Your Order</h2>
      <div className="space-y-4 mb-6">
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Wireless Headphones Pro × 1</span>
          <span className="font-medium">$89.99</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-gray-600">Mechanical Keyboard RGB × 2</span>
          <span className="font-medium">$299.98</span>
        </div>
        <div className="border-t pt-4 space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-gray-600">Subtotal</span>
            <span>$389.97</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-600">Shipping</span>
            <span className="text-green-600">Free</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-gray-600">Tax</span>
            <span>$31.20</span>
          </div>
          <div className="flex justify-between font-bold">
            <span>Total</span>
            <span>$421.17</span>
          </div>
        </div>
      </div>
      <div className="flex justify-between">
        <button onClick={onBack} className="btn-secondary">← Back</button>
        <button onClick={onPlace} className="btn-primary px-8">
          Place Order — $421.17
        </button>
      </div>
    </div>
  )
}

export default function CheckoutPage() {
  const [step, setStep] = useState<Step>('shipping')
  const [ordered, setOrdered] = useState(false)

  if (ordered) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <div className="text-6xl mb-4">🎉</div>
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Order Confirmed!</h1>
        <p className="text-gray-500 mb-2">Order #ORD-{Math.random().toString(36).substr(2, 9).toUpperCase()}</p>
        <p className="text-gray-500 mb-8">You&apos;ll receive a confirmation email shortly.</p>
        <div className="flex gap-4 justify-center">
          <Link href="/orders" className="btn-primary">View Orders</Link>
          <Link href="/products" className="btn-secondary">Continue Shopping</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-bold text-gray-900 mb-6 text-center">Checkout</h1>
      <StepIndicator current={step} />

      {step === 'shipping' && <ShippingForm onNext={() => setStep('payment')} />}
      {step === 'payment' && <PaymentForm onNext={() => setStep('review')} onBack={() => setStep('shipping')} />}
      {step === 'review' && <OrderReview onPlace={() => setOrdered(true)} onBack={() => setStep('payment')} />}
    </div>
  )
}
