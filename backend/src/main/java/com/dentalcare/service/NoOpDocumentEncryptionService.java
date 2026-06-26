package com.dentalcare.service;

import org.springframework.stereotype.Service;

@Service
public class NoOpDocumentEncryptionService implements DocumentEncryptionService {

    @Override
    public byte[] encrypt(byte[] data) {
        return data;
    }

    @Override
    public byte[] decrypt(byte[] data) {
        return data;
    }
}
