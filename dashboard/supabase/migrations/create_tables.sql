-- Create drivers table
CREATE TABLE IF NOT EXISTS public.drivers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  phone TEXT NOT NULL,
  license_number TEXT NOT NULL,
  vehicle_details JSONB NOT NULL,
  is_available BOOLEAN DEFAULT TRUE,
  rating NUMERIC DEFAULT 0,
  total_rides INTEGER DEFAULT 0,
  current_location JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create rides table
CREATE TABLE IF NOT EXISTS public.rides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL, -- Changed from UUID with foreign key reference
  driver_id UUID REFERENCES public.drivers(id),
  pickup JSONB NOT NULL,
  destination JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested',
  fare NUMERIC,
  payment_method TEXT DEFAULT 'cash',
  request_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  pickup_time TIMESTAMP WITH TIME ZONE,
  completion_time TIMESTAMP WITH TIME ZONE,
  rating NUMERIC,
  feedback TEXT
);

-- Add RLS policies for drivers
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- Allow public read/write access for development
CREATE POLICY "Allow public access to drivers" ON public.drivers
  USING (true)
  WITH CHECK (true);

-- Add RLS policies for rides
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

-- Allow public read/write access for development
CREATE POLICY "Allow public access to rides" ON public.rides
  USING (true)
  WITH CHECK (true);

-- Create function to get available rides
CREATE OR REPLACE FUNCTION get_available_rides()
RETURNS SETOF public.rides
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT * FROM public.rides WHERE status = 'requested' ORDER BY request_time DESC;
$$; 