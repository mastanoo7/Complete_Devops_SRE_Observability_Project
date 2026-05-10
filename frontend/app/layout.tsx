// ============================================================
// NexaCommerce Frontend — Next.js 14 App
// Root layout and main page
// ============================================================

import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'NexaCommerce — Enterprise Ecommerce Platform',
  description: 'Shop millions of products with fast delivery',
  keywords: ['ecommerce', 'shopping', 'nexacommerce'],
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000'),
  openGraph: {
    title: 'NexaCommerce',
    description: 'Enterprise Ecommerce Platform',
    url: 'https://nexacommerce.com',
    siteName: 'NexaCommerce',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <main>{children}</main>
      </body>
    </html>
  )
}
