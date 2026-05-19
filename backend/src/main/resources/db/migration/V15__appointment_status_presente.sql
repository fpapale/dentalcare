-- Add 'presente' status: patient has arrived, waiting to be called
ALTER TYPE dentalcare.appointment_status ADD VALUE IF NOT EXISTS 'presente' AFTER 'confirmed';
