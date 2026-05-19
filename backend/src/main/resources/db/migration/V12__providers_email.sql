-- V12: add email column to providers in demo tenant schema

SET search_path TO t_9d754153, dentalcare, public;

ALTER TABLE providers
    ADD COLUMN IF NOT EXISTS email text;
