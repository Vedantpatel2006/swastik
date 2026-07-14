-- Create temples table
CREATE TABLE IF NOT EXISTS public.temples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  image_url TEXT,
  rating NUMERIC(2,1) DEFAULT 0.0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for location-based queries
CREATE INDEX IF NOT EXISTS idx_temples_location ON public.temples(latitude, longitude);

-- Enable Row Level Security
ALTER TABLE public.temples ENABLE ROW LEVEL SECURITY;

-- Create policy to allow public read access
CREATE POLICY "Allow public read access" ON public.temples
  FOR SELECT
  USING (true);;
