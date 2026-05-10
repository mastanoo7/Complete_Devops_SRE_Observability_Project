// ============================================================
// NexaCommerce — Home Page
// SSR landing page with featured products and categories
// ============================================================

import { Suspense } from 'react'
import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'NexaCommerce — Shop Millions of Products',
  description: 'Discover amazing deals on electronics, fashion, home goods and more.',
}

// Hero section component
function HeroSection() {
  return (
    <section className="relative bg-gradient-to-r from-brand-700 to-brand-900 text-white">
      <div className="mx-auto max-w-7xl px-4 py-24 sm:px-6 lg:px-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight sm:text-6xl">
            Shop Everything,{' '}
            <span className="text-brand-200">Everywhere</span>
          </h1>
          <p className="mt-6 text-xl text-brand-100 max-w-2xl mx-auto">
            Millions of products. Fast delivery. Unbeatable prices.
            Your one-stop shop for everything you need.
          </p>
          <div className="mt-10 flex items-center justify-center gap-4">
            <Link
              href="/products"
              className="rounded-lg bg-white px-8 py-3 text-base font-semibold text-brand-700 shadow-sm hover:bg-brand-50 transition-colors"
            >
              Shop Now
            </Link>
            <Link
              href="/products?sale=true"
              className="rounded-lg border border-white px-8 py-3 text-base font-semibold text-white hover:bg-brand-800 transition-colors"
            >
              View Deals
            </Link>
          </div>
        </div>
      </div>
    </section>
  )
}

// Category grid component
function CategoryGrid() {
  const categories = [
    { name: 'Electronics', slug: 'electronics', emoji: '💻', color: 'bg-blue-50' },
    { name: 'Fashion', slug: 'fashion', emoji: '👗', color: 'bg-pink-50' },
    { name: 'Home & Garden', slug: 'home-garden', emoji: '🏠', color: 'bg-green-50' },
    { name: 'Sports', slug: 'sports', emoji: '⚽', color: 'bg-orange-50' },
    { name: 'Books', slug: 'books', emoji: '📚', color: 'bg-yellow-50' },
    { name: 'Toys', slug: 'toys', emoji: '🎮', color: 'bg-purple-50' },
  ]

  return (
    <section className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
      <h2 className="text-2xl font-bold text-gray-900 mb-8">Shop by Category</h2>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
        {categories.map((cat) => (
          <Link
            key={cat.slug}
            href={`/products?category=${cat.slug}`}
            className={`${cat.color} rounded-xl p-6 text-center hover:shadow-md transition-shadow group`}
          >
            <div className="text-4xl mb-3">{cat.emoji}</div>
            <div className="text-sm font-medium text-gray-900 group-hover:text-brand-600">
              {cat.name}
            </div>
          </Link>
        ))}
      </div>
    </section>
  )
}

// Featured products skeleton
function FeaturedProductsSkeleton() {
  return (
    <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="card p-4">
          <div className="skeleton h-48 w-full rounded-lg mb-4" />
          <div className="skeleton h-4 w-3/4 rounded mb-2" />
          <div className="skeleton h-4 w-1/2 rounded mb-4" />
          <div className="skeleton h-8 w-full rounded" />
        </div>
      ))}
    </div>
  )
}

// Features section
function FeaturesSection() {
  const features = [
    { icon: '🚚', title: 'Free Shipping', desc: 'On orders over $50' },
    { icon: '🔄', title: 'Easy Returns', desc: '30-day return policy' },
    { icon: '🔒', title: 'Secure Payment', desc: 'SSL encrypted checkout' },
    { icon: '💬', title: '24/7 Support', desc: 'Always here to help' },
  ]

  return (
    <section className="bg-gray-50 py-16">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 gap-8 lg:grid-cols-4">
          {features.map((f) => (
            <div key={f.title} className="text-center">
              <div className="text-4xl mb-3">{f.icon}</div>
              <h3 className="font-semibold text-gray-900">{f.title}</h3>
              <p className="text-sm text-gray-500 mt-1">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default function HomePage() {
  return (
    <div className="min-h-screen">
      <HeroSection />
      <CategoryGrid />

      {/* Featured Products */}
      <section className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between mb-8">
          <h2 className="text-2xl font-bold text-gray-900">Featured Products</h2>
          <Link href="/products" className="text-brand-600 hover:text-brand-700 font-medium">
            View all →
          </Link>
        </div>
        <Suspense fallback={<FeaturedProductsSkeleton />}>
          {/* FeaturedProducts component would fetch and render here */}
          <FeaturedProductsSkeleton />
        </Suspense>
      </section>

      <FeaturesSection />
    </div>
  )
}
