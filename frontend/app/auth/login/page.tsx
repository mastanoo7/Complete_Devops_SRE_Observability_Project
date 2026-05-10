'use client'

// ============================================================
// Auth Page — Login / Register
// ============================================================

import { useState } from 'react'
import Link from 'next/link'

type Mode = 'login' | 'register'

function LoginForm({ onSwitch }: { onSwitch: () => void }) {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Welcome back</h2>
      <p className="text-gray-500 mb-6">Sign in to your account</p>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input type="email" className="input" placeholder="john@example.com" />
        </div>
        <div>
          <div className="flex justify-between mb-1">
            <label className="block text-sm font-medium text-gray-700">Password</label>
            <Link href="/auth/forgot-password" className="text-sm text-brand-600 hover:text-brand-700">
              Forgot password?
            </Link>
          </div>
          <input type="password" className="input" placeholder="••••••••" />
        </div>
        <div className="flex items-center gap-2">
          <input type="checkbox" id="remember" className="rounded border-gray-300 text-brand-600" />
          <label htmlFor="remember" className="text-sm text-gray-600">Remember me</label>
        </div>
      </div>

      <button className="btn-primary w-full mt-6">Sign In</button>

      <div className="mt-4 relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-200" />
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="bg-white px-4 text-gray-500">Or continue with</span>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-3">
        <button className="btn-secondary flex items-center justify-center gap-2">
          <span>🔵</span> Google
        </button>
        <button className="btn-secondary flex items-center justify-center gap-2">
          <span>⬛</span> GitHub
        </button>
      </div>

      <p className="mt-6 text-center text-sm text-gray-500">
        Don&apos;t have an account?{' '}
        <button onClick={onSwitch} className="text-brand-600 hover:text-brand-700 font-medium">
          Sign up
        </button>
      </p>
    </div>
  )
}

function RegisterForm({ onSwitch }: { onSwitch: () => void }) {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Create account</h2>
      <p className="text-gray-500 mb-6">Join millions of shoppers</p>

      <div className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">First Name</label>
            <input type="text" className="input" placeholder="John" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Last Name</label>
            <input type="text" className="input" placeholder="Doe" />
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input type="email" className="input" placeholder="john@example.com" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
          <input type="password" className="input" placeholder="Min 8 characters" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
          <input type="password" className="input" placeholder="Repeat password" />
        </div>
        <div className="flex items-start gap-2">
          <input type="checkbox" id="terms" className="mt-0.5 rounded border-gray-300 text-brand-600" />
          <label htmlFor="terms" className="text-sm text-gray-600">
            I agree to the{' '}
            <Link href="/terms" className="text-brand-600 hover:text-brand-700">Terms of Service</Link>
            {' '}and{' '}
            <Link href="/privacy" className="text-brand-600 hover:text-brand-700">Privacy Policy</Link>
          </label>
        </div>
      </div>

      <button className="btn-primary w-full mt-6">Create Account</button>

      <p className="mt-6 text-center text-sm text-gray-500">
        Already have an account?{' '}
        <button onClick={onSwitch} className="text-brand-600 hover:text-brand-700 font-medium">
          Sign in
        </button>
      </p>
    </div>
  )
}

export default function AuthPage() {
  const [mode, setMode] = useState<Mode>('login')

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <Link href="/" className="text-2xl font-bold text-brand-600">
            🛒 NexaCommerce
          </Link>
        </div>

        {/* Auth card */}
        <div className="card p-8">
          {mode === 'login' ? (
            <LoginForm onSwitch={() => setMode('register')} />
          ) : (
            <RegisterForm onSwitch={() => setMode('login')} />
          )}
        </div>

        {/* Back to home */}
        <p className="text-center mt-6 text-sm text-gray-500">
          <Link href="/" className="text-brand-600 hover:text-brand-700">
            ← Back to home
          </Link>
        </p>
      </div>
    </div>
  )
}
