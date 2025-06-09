# SFTV - Real-time Salesforce Dashboards for TV

> Transform Salesforce Lightning dashboards into beautiful, real-time TV displays

## 🎯 Overview

SFTV delivers real-time, TV-friendly visibility into Salesforce dashboards for RevOps and Sales teams — all within 5 minutes of freshness, no data warehousing required.

### Key Features

- **5-minute setup**: Connect Salesforce → Display on TV
- **Real-time updates**: Sub-30-second data freshness  
- **Zero maintenance**: Auto-rotating, always-on dashboards
- **Professional branding**: Custom colors and logos
- **Enterprise-ready**: Secure, scalable, observable

## 🏗️ Architecture

This is a monorepo containing:

- **`apps/web`** - Next.js 14 web application with App Router
- **`apps/tv-client`** - React TV client optimized for 1080p displays
- **`packages/supabase-edge`** - Supabase Edge Functions (Deno runtime)

### Tech Stack

- **Frontend**: Next.js 14, React 18, TypeScript 5.0, Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Edge Functions)
- **UI Components**: Based on Vision UI Dashboard React
- **Charts**: Recharts
- **State Management**: Zustand
- **Build System**: Turborepo
- **Deployment**: Vercel (frontend) + Supabase Cloud (backend)
- **Monitoring**: Sentry + Supabase Analytics

## 🚀 Quick Start

### Prerequisites

- Node.js 20+
- npm 10+
- Git

### Installation

1. **Clone and install dependencies**
   ```bash
   git clone <repository-url>
   cd sftv
   npm install
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Fill in your Supabase and other API keys
   ```

3. **Start development servers**
   ```bash
   npm run dev
   ```

This will start:
- Web app: http://localhost:3000
- TV client: http://localhost:3001

## 📦 Project Structure

```
sftv/
├── apps/
│   ├── web/              # Next.js web application
│   └── tv-client/        # React TV client
├── packages/
│   └── supabase-edge/    # Edge Functions
├── docs/                 # Documentation
├── migrations/           # Database migrations
├── playwright/           # E2E tests
└── .taskmaster/         # Task management
```

## 🔧 Available Scripts

- `npm run dev` - Start all development servers
- `npm run build` - Build all packages
- `npm run lint` - Run linting across all packages
- `npm run test` - Run tests
- `npm run type-check` - TypeScript type checking

## 🌟 Getting Started

1. **Initialize your Salesforce connection**
2. **Pair your TV using the PIN system**
3. **Select dashboards for your slideshow**
4. **Customize branding and rotation settings**

## 📚 Documentation

- [Product Requirements Document](./docs/prd.md)
- [Development Workflow](./.taskmaster/docs/)
- [API Documentation](./packages/supabase-edge/README.md)

## 🤝 Contributing

Please see our [development workflow guidelines](./.taskmaster/docs/) for contribution instructions.

## 📄 License

MIT License - see [LICENSE](./LICENSE) for details.

---

**SFTV** - Making Salesforce data beautiful on every screen 📺✨ 