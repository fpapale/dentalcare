package com.dentalcare.service;

public interface DocumentEncryptionService {
    byte[] encrypt(byte[] data);
    byte[] decrypt(byte[] data);
}
