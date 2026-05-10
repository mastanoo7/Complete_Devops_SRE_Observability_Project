// ============================================================
// Products Page — Server Component with search/filter
// ============================================================

import type { Metadata } from 'next'
import Image from 'next/image'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Products — NexaCommerce',
  description: 'Browse our full catalog of products',
}

interface ProductsPageProps {
  searchParams: {
    q?: string
    category?: string
    page?: string
    sort?: string
    minPrice?: string
    maxPrice?: string
  }
}

// Product card component
function ProductCard({ product }: { product: {
  id: string; name: string; price: number; image: string; rating: number; slug: string
}}) {
  return (
    <div className="card group hover:shadow-lg transition-shadow">
      <div className="aspect-square overflow-hidden rounded-t-lg bg-gray-100">
        <Image
          src={product.image}
          alt={product.name}
          width={400}
          height={400}
          className="h-full w-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
      </div>
      <div className="p-4">
        <h3 className="text-sm font-medium text-gray-900 line-clamp-2 mb-1">
          {product.name}
        </h3>
        <div className="flex items-center gap-1 mb-2">
          <span className="text-yellow-400">★</span>
          <span className="text-xs text-gray-500">{product.rating}</span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-lg font-bold text-gray-900">
            ${product.price.toFixed(2)}
          </span>
          <button className="btn-primary text-xs px-3 py-1.5">
            Add to Cart
          </button>
        </div>
      </div>
    </div>
  )
}

// Filters sidebar
function FiltersSidebar() {
  const categories = [
    'Electronics', 'Fashion', 'Home & Garden',
    'Sports', 'Books', 'Toys', 'Beauty', 'Automotive'
  ]

  return (
    <aside className="w-64 shrink-0">
      <div className="card p-4 sticky top-4">
        <h3 className="font-semibold text-gray-900 mb-4">Filters</h3>

        {/* Categories */}
        <div className="mb-6">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Category</h4>
          <div className="space-y-2">
            {categories.map((cat) => (
              <label key={cat} className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" className="rounded border-gray-300 text-brand-600" />
                <span className="text-sm text-gray-600">{cat}</span>
              </label>
            ))}
          </div>
        </div>

        {/* Price Range */}
        <div className="mb-6">
          <h4 className="text-sm font-medium text-gray-700 mb-2">Price Range</h4>
          <div className="flex gap-2">
            <input
              type="number"
              placeholder="Min"
              className="input w-full text-sm"
            />
            <input
              type="number"
              placeholder="Max"
              className="input w-full text-sm"
            />
          </div>
        </div>

        {/* Rating */}
        <div>
          <h4 className="text-sm font-medium text-gray-700 mb-2">Rating</h4>
          {[4, 3, 2, 1].map((rating) => (
            <label key={rating} className="flex items-center gap-2 cursor-pointer mb-1">
              <input type="radio" name="rating" className="text-brand-600" />
              <span className="text-yellow-400">{'★'.repeat(rating)}{'☆'.repeat(5 - rating)}</span>
              <span className="text-sm text-gray-500">& up</span>
            </label>
          ))}
        </div>
      </div>
    </aside>
  )
}

export default function ProductsPage({ searchParams }: ProductsPageProps) {
  const query = searchParams.q || ''
  const page = parseInt(searchParams.page || '1')

  // Mock products for demonstration
  const mockProducts = Array.from({ length: 12 }, (_, i) => ({
    id: `prod-${i + 1}`,
    name: `Product ${i + 1} — Premium Quality Item with Long Name`,
    price: Math.floor(Math.random() * 200) + 9.99,
    image: `https://via.placeholder.com/400x400?text=Product+${i + 1}`,
    rating: (Math.random() * 2 + 3).toFixed(1),
    slug: `product-${i + 1}`,
  }))

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Breadcrumb */}
      <nav className="flex items-center gap-2 text-sm text-gray-500 mb-6">
        <Link href="/" className="hover:text-brand-600">Home</Link>
        <span>/</span>
        <span className="text-gray-900">Products</span>
        {query && (
          <>
            <span>/</span>
            <span className="text-gray-900">Search: &quot;{query}&quot;</span>
          </>
        )}
      </nav>

      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          {query ? `Results for "${query}"` : 'All Products'}
        </h1>
        <div className="flex items-center gap-3">
          <span className="text-sm text-gray-500">1,234 products</span>
          <select className="input text-sm w-auto">
            <option>Sort: Featured</option>
            <option>Price: Low to High</option>
            <option>Price: High to Low</option>
            <option>Newest First</option>
            <option>Best Rating</option>
          </select>
        </div>
      </div>

      {/* Main content */}
      <div className="flex gap-8">
        <FiltersSidebar />

        <div className="flex-1">
          {/* Product grid */}
          <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {mockProducts.map((product) => (
              <Link key={product.id} href={`/products/${product.slug}`}>
                <ProductCard product={product as any} />
              </Link>
            ))}
          </div>

          {/* Pagination */}
          <div className="mt-8 flex items-center justify-center gap-2">
            <button className="btn-secondary px-3 py-2" disabled={page === 1}>
              ← Previous
            </button>
            {[1, 2, 3, 4, 5].map((p) => (
              <button
                key={p}
                className={p === page ? 'btn-primary px-3 py-2' : 'btn-secondary px-3 py-2'}
              >
                {p}
              </button>
            ))}
            <button className="btn-secondary px-3 py-2">
              Next →
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
