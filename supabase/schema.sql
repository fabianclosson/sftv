-- SFTV Database Schema
-- This file contains the initial database structure for the SFTV application

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  organization_id UUID,
  role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'viewer')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Organizations table
CREATE TABLE public.organizations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  primary_color TEXT DEFAULT '#3B82F6',
  secondary_color TEXT DEFAULT '#1E40AF',
  salesforce_instance_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Salesforce connections table
CREATE TABLE public.salesforce_connections (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  instance_url TEXT NOT NULL,
  user_info JSONB,
  expires_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Dashboards table
CREATE TABLE public.dashboards (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  salesforce_dashboard_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  refresh_interval INTEGER DEFAULT 300, -- seconds
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(organization_id, salesforce_dashboard_id)
);

-- TV clients table
CREATE TABLE public.tv_clients (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  pin_code TEXT UNIQUE NOT NULL,
  is_active BOOLEAN DEFAULT true,
  last_seen TIMESTAMP WITH TIME ZONE,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- TV client dashboard assignments
CREATE TABLE public.tv_dashboard_assignments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  tv_client_id UUID REFERENCES public.tv_clients(id) ON DELETE CASCADE,
  dashboard_id UUID REFERENCES public.dashboards(id) ON DELETE CASCADE,
  display_duration INTEGER DEFAULT 30, -- seconds
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(tv_client_id, dashboard_id)
);

-- Dashboard cache table for storing rendered dashboard data
CREATE TABLE public.dashboard_cache (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  dashboard_id UUID REFERENCES public.dashboards(id) ON DELETE CASCADE,
  data JSONB NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(dashboard_id)
);

-- Add foreign key constraint for users->organizations
ALTER TABLE public.users 
ADD CONSTRAINT fk_users_organization 
FOREIGN KEY (organization_id) REFERENCES public.organizations(id);

-- Row Level Security (RLS) policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salesforce_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tv_dashboard_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_cache ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Users can read/update their own data
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Organization members can view organization data
CREATE POLICY "Organization members can view organization" ON public.organizations
  FOR SELECT USING (
    id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid()
    )
  );

-- Only org admins can update organization
CREATE POLICY "Organization admins can update organization" ON public.organizations
  FOR UPDATE USING (
    id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Salesforce connections: users can manage their own connections
CREATE POLICY "Users can manage own Salesforce connections" ON public.salesforce_connections
  FOR ALL USING (user_id = auth.uid());

-- Dashboards: organization members can view, admins can manage
CREATE POLICY "Organization members can view dashboards" ON public.dashboards
  FOR SELECT USING (
    organization_id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage dashboards" ON public.dashboards
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin')
    )
  );

-- TV clients: organization members can view, admins can manage
CREATE POLICY "Organization members can view TV clients" ON public.tv_clients
  FOR SELECT USING (
    organization_id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage TV clients" ON public.tv_clients
  FOR ALL USING (
    organization_id IN (
      SELECT organization_id FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin')
    )
  );

-- TV dashboard assignments: follow TV client permissions
CREATE POLICY "Organization members can view TV dashboard assignments" ON public.tv_dashboard_assignments
  FOR SELECT USING (
    tv_client_id IN (
      SELECT id FROM public.tv_clients 
      WHERE organization_id IN (
        SELECT organization_id FROM public.users 
        WHERE id = auth.uid()
      )
    )
  );

CREATE POLICY "Organization admins can manage TV dashboard assignments" ON public.tv_dashboard_assignments
  FOR ALL USING (
    tv_client_id IN (
      SELECT id FROM public.tv_clients 
      WHERE organization_id IN (
        SELECT organization_id FROM public.users 
        WHERE id = auth.uid() AND role IN ('admin')
      )
    )
  );

-- Dashboard cache: follow dashboard permissions
CREATE POLICY "Organization members can view dashboard cache" ON public.dashboard_cache
  FOR SELECT USING (
    dashboard_id IN (
      SELECT id FROM public.dashboards 
      WHERE organization_id IN (
        SELECT organization_id FROM public.users 
        WHERE id = auth.uid()
      )
    )
  );

-- Functions and triggers for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER handle_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_organizations_updated_at
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_salesforce_connections_updated_at
  BEFORE UPDATE ON public.salesforce_connections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_dashboards_updated_at
  BEFORE UPDATE ON public.dashboards
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_tv_clients_updated_at
  BEFORE UPDATE ON public.tv_clients
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create indexes for performance
CREATE INDEX idx_users_organization_id ON public.users(organization_id);
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_salesforce_connections_user_id ON public.salesforce_connections(user_id);
CREATE INDEX idx_salesforce_connections_organization_id ON public.salesforce_connections(organization_id);
CREATE INDEX idx_dashboards_organization_id ON public.dashboards(organization_id);
CREATE INDEX idx_dashboards_is_active ON public.dashboards(is_active);
CREATE INDEX idx_tv_clients_organization_id ON public.tv_clients(organization_id);
CREATE INDEX idx_tv_clients_pin_code ON public.tv_clients(pin_code);
CREATE INDEX idx_tv_dashboard_assignments_tv_client_id ON public.tv_dashboard_assignments(tv_client_id);
CREATE INDEX idx_tv_dashboard_assignments_dashboard_id ON public.tv_dashboard_assignments(dashboard_id);
CREATE INDEX idx_dashboard_cache_dashboard_id ON public.dashboard_cache(dashboard_id);
CREATE INDEX idx_dashboard_cache_expires_at ON public.dashboard_cache(expires_at); 