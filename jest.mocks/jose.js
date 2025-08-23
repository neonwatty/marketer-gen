// Mock for jose package
module.exports = {
  jwtVerify: jest.fn(),
  SignJWT: jest.fn().mockImplementation(() => ({
    setProtectedHeader: jest.fn().mockReturnThis(),
    setIssuedAt: jest.fn().mockReturnThis(),
    setExpirationTime: jest.fn().mockReturnThis(),
    sign: jest.fn().mockResolvedValue('mock-jwt-token'),
  })),
  importSPKI: jest.fn(),
  importPKCS8: jest.fn(),
  importJWK: jest.fn(),
  createRemoteJWKSet: jest.fn(),
  jwtDecrypt: jest.fn(),
  EncryptJWT: jest.fn(),
  compactDecrypt: jest.fn(),
  compactEncrypt: jest.fn(),
  FlattenedSign: jest.fn(),
  FlattenedVerify: jest.fn(),
  GeneralSign: jest.fn(),
  GeneralVerify: jest.fn(),
  UnsecuredJWT: jest.fn(),
}