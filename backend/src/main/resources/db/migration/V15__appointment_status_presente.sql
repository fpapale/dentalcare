-- Add 'presente' status: patient has arrived, waiting to be called
-- Create enum in dentalcare schema if it doesn't exist yet (old DB: was in default schema, not dentalcare)
DO $$ BEGIN
    CREATE TYPE dentalcare.appointment_status AS ENUM (
        'scheduled', 'confirmed', 'presente', 'in_progress', 'completed', 'no_show', 'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add 'presente' if enum already existed but was missing the value
DO $$ BEGIN
    ALTER TYPE dentalcare.appointment_status ADD VALUE IF NOT EXISTS 'presente' AFTER 'confirmed';
EXCEPTION WHEN others THEN NULL;
END $$;
